package physics

import "core:log"
import "core:strings"
import b2 "vendor:box2d"
import lua "vendor:lua/5.4"

import "../core"

PhysicsShapeHandle :: struct {
    shape: ^PhysicsShape,
    owns:  bool,
}

PhysicsShape :: struct {
    unique_id: u64,
    id:      b2.ShapeId,
    body:    ^PhysicsBody,
    tag:     cstring,
    refs:    int,
    is_gone: bool,
}

@(private="file") next_shape_unique_id: u64 = 1

InitPhysicsShape :: proc(shape: ^PhysicsShape, id: b2.ShapeId, body: ^PhysicsBody) {
    log.debugf("KaptanPhysicsShape: Init")

    shape.unique_id = next_shape_unique_id
    next_shape_unique_id += 1
    shape.id = id
    shape.body = body
    shape.tag = nil
    shape.refs = 0
    shape.is_gone = false

    b2.Shape_SetUserData(shape.id, shape)
}

DestroyPhysicsShape :: proc(shape: ^PhysicsShape) {
    if shape == nil {
        return
    }

    if ! shape.is_gone && b2.Shape_IsValid(shape.id) {
        log.debugf("KaptanPhysicsShape: Destroy")
        b2.Shape_SetUserData(shape.id, nil)
        b2.DestroyShape(shape.id, true)
    }

    shape.is_gone = true
    shape.id = {}

    if shape.body != nil {
        PhysicsBodyUnregisterShape(shape.body, shape)
        shape.body = nil
    }
}

FreePhysicsShape :: proc(shape: ^PhysicsShape) {
    if shape == nil {
        return
    }

    DestroyPhysicsShape(shape)
    release_shape_ref(shape)
}

PhysicsShapeInvalidate :: proc(shape: ^PhysicsShape) {
    if shape == nil {
        return
    }

    if ! shape.is_gone && b2.Shape_IsValid(shape.id) {
        b2.Shape_SetUserData(shape.id, nil)
    }

    shape.is_gone = true
    shape.id = {}
    shape.body = nil
}

PhysicsShapeIsValid :: proc "contextless" (shape: ^PhysicsShape) -> bool {
    return shape != nil && ! shape.is_gone && b2.Shape_IsValid(shape.id)
}

PhysicsShapeAddRef :: proc(shape: ^PhysicsShape) {
    if shape != nil {
        shape.refs += 1
    }
}

PhysicsShapeReleaseRef :: proc(shape: ^PhysicsShape) {
    release_shape_ref(shape)
}

PhysicsShapeFromLua :: proc "contextless" (L: ^lua.State, idx: i32) -> ^PhysicsShape {
    handle := (^PhysicsShapeHandle)(lua.L_checkudata(L, idx, "KaptanPhysicsShapeMT"))
    return handle.shape
}

PhysicsShapeFromId :: proc "contextless" (id: b2.ShapeId) -> ^PhysicsShape {
    if ! b2.Shape_IsValid(id) {
        return nil
    }

    return (^PhysicsShape)(b2.Shape_GetUserData(id))
}

PhysicsShapeLuaBind :: proc(L: ^lua.State) {
    @static static_reg_table: []lua.L_Reg = {
        { nil, nil },
    }

    @static instance_reg_table: []lua.L_Reg = {
        { "destroy",              _destroy },
        { "getCategory",          _get_category },
        { "getDensity",           _get_density },
        { "getFriction",          _get_friction },
        { "getGroup",             _get_group },
        { "getId",                _get_id },
        { "getMask",              _get_mask },
        { "getRestitution",       _get_restitution },
        { "getTag",               _get_tag },
        { "isContactEvents",      _is_contact_events },
        { "isHitEvents",          _is_hit_events },
        { "isSensor",             _is_sensor },
        { "isSensorEvents",       _is_sensor_events },
        { "isValid",              _is_valid },
        { "setCategory",          _set_category },
        { "setContactEvents",     _set_contact_events },
        { "setDensity",           _set_density },
        { "setFriction",          _set_friction },
        { "setGroup",             _set_group },
        { "setHitEvents",         _set_hit_events },
        { "setMask",              _set_mask },
        { "setRestitution",       _set_restitution },
        { "setSensorEvents",      _set_sensor_events },
        { "setTag",               _set_tag },
        { nil, nil },
    }

    core.LuaBindClass(L, "KaptanPhysicsShape", &static_reg_table, &instance_reg_table, __gc)
}

PhysicsShapeLuaUnbind :: proc(L: ^lua.State) {
    // nothing to do
}

PhysicsShapePushLua :: proc(L: ^lua.State, shape: ^PhysicsShape) {
    physics_shape_push_lua(L, shape, true)
}

PhysicsShapePushLuaRef :: proc(L: ^lua.State, shape: ^PhysicsShape) {
    physics_shape_push_lua(L, shape, false)
}

PhysicsShapeDefaultDef :: proc "contextless" (L: ^lua.State, options_idx: i32) -> b2.ShapeDef {
    shape_def := b2.DefaultShapeDef()

    if options_idx == 0 || lua.isnoneornil(L, options_idx) {
        return shape_def
    }

    if ! lua.istable(L, options_idx) {
        lua.L_typeerror(L, options_idx, "table")
    }

    abs_idx := core.LuaGetAbsIndex(L, options_idx)

    lua.getfield(L, abs_idx, "sensor")
    if ! lua.isnil(L, -1) {
        shape_def.isSensor = bool(lua.toboolean(L, -1))
    }
    lua.pop(L, 1)

    lua.getfield(L, abs_idx, "sensorEvents")
    if ! lua.isnil(L, -1) {
        shape_def.enableSensorEvents = bool(lua.toboolean(L, -1))
    }
    lua.pop(L, 1)

    lua.getfield(L, abs_idx, "contactEvents")
    if ! lua.isnil(L, -1) {
        shape_def.enableContactEvents = bool(lua.toboolean(L, -1))
    }
    lua.pop(L, 1)

    lua.getfield(L, abs_idx, "hitEvents")
    if ! lua.isnil(L, -1) {
        shape_def.enableHitEvents = bool(lua.toboolean(L, -1))
    }
    lua.pop(L, 1)

    return shape_def
}

@(private="file")
physics_shape_push_lua :: proc(L: ^lua.State, shape: ^PhysicsShape, owns: bool) {
    PhysicsShapeAddRef(shape)

    handle := (^PhysicsShapeHandle)(lua.newuserdata(L, size_of(PhysicsShapeHandle)))
    handle.shape = shape
    handle.owns = owns
    core.LuaSetClassMetatable(L, "KaptanPhysicsShape")
}

@(private="file")
release_shape_ref :: proc(shape: ^PhysicsShape) {
    if shape == nil {
        return
    }

    shape.refs -= 1
    if shape.refs <= 0 && shape.is_gone {
        if shape.tag != nil {
            delete(shape.tag)
        }
        free(shape)
    }
}

@(private="file")
check_shape_valid :: proc "contextless" (L: ^lua.State, shape: ^PhysicsShape) {
    if ! PhysicsShapeIsValid(shape) {
        lua.L_error(L, "KaptanPhysicsShape is no longer valid")
    }
}

@(private="file")
_destroy :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    shape := PhysicsShapeFromLua(L, 1)
    DestroyPhysicsShape(shape)

    return 0
}

@(private="file")
_get_category :: proc "c" (L: ^lua.State) -> i32 {
    shape := PhysicsShapeFromLua(L, 1)
    check_shape_valid(L, shape)

    filter := b2.Shape_GetFilter(shape.id)
    lua.pushinteger(L, lua.Integer(filter.categoryBits))

    return 1
}

@(private="file")
_get_density :: proc "c" (L: ^lua.State) -> i32 {
    shape := PhysicsShapeFromLua(L, 1)
    check_shape_valid(L, shape)

    lua.pushnumber(L, lua.Number(b2.Shape_GetDensity(shape.id)))

    return 1
}

@(private="file")
_get_friction :: proc "c" (L: ^lua.State) -> i32 {
    shape := PhysicsShapeFromLua(L, 1)
    check_shape_valid(L, shape)

    lua.pushnumber(L, lua.Number(b2.Shape_GetFriction(shape.id)))

    return 1
}

@(private="file")
_get_group :: proc "c" (L: ^lua.State) -> i32 {
    shape := PhysicsShapeFromLua(L, 1)
    check_shape_valid(L, shape)

    filter := b2.Shape_GetFilter(shape.id)
    lua.pushinteger(L, lua.Integer(filter.groupIndex))

    return 1
}

@(private="file")
_get_id :: proc "c" (L: ^lua.State) -> i32 {
    shape := PhysicsShapeFromLua(L, 1)
    lua.pushinteger(L, lua.Integer(shape.unique_id))

    return 1
}

@(private="file")
_get_mask :: proc "c" (L: ^lua.State) -> i32 {
    shape := PhysicsShapeFromLua(L, 1)
    check_shape_valid(L, shape)

    filter := b2.Shape_GetFilter(shape.id)
    lua.pushinteger(L, lua.Integer(filter.maskBits))

    return 1
}

@(private="file")
_get_restitution :: proc "c" (L: ^lua.State) -> i32 {
    shape := PhysicsShapeFromLua(L, 1)
    check_shape_valid(L, shape)

    lua.pushnumber(L, lua.Number(b2.Shape_GetRestitution(shape.id)))

    return 1
}

@(private="file")
_get_tag :: proc "c" (L: ^lua.State) -> i32 {
    shape := PhysicsShapeFromLua(L, 1)
    check_shape_valid(L, shape)

    if shape.tag == nil {
        lua.pushstring(L, "")
    } else {
        lua.pushstring(L, shape.tag)
    }

    return 1
}

@(private="file")
_is_contact_events :: proc "c" (L: ^lua.State) -> i32 {
    shape := PhysicsShapeFromLua(L, 1)
    check_shape_valid(L, shape)

    lua.pushboolean(L, b32(b2.Shape_AreContactEventsEnabled(shape.id)))

    return 1
}

@(private="file")
_is_hit_events :: proc "c" (L: ^lua.State) -> i32 {
    shape := PhysicsShapeFromLua(L, 1)
    check_shape_valid(L, shape)

    lua.pushboolean(L, b32(b2.Shape_AreHitEventsEnabled(shape.id)))

    return 1
}

@(private="file")
_is_sensor :: proc "c" (L: ^lua.State) -> i32 {
    shape := PhysicsShapeFromLua(L, 1)
    check_shape_valid(L, shape)

    lua.pushboolean(L, b32(b2.Shape_IsSensor(shape.id)))

    return 1
}

@(private="file")
_is_sensor_events :: proc "c" (L: ^lua.State) -> i32 {
    shape := PhysicsShapeFromLua(L, 1)
    check_shape_valid(L, shape)

    lua.pushboolean(L, b32(b2.Shape_AreSensorEventsEnabled(shape.id)))
    return 1
}

@(private="file")
_is_valid :: proc "c" (L: ^lua.State) -> i32 {
    shape := PhysicsShapeFromLua(L, 1)
    lua.pushboolean(L, b32(PhysicsShapeIsValid(shape)))

    return 1
}

@(private="file")
_set_category :: proc "c" (L: ^lua.State) -> i32 {
    shape := PhysicsShapeFromLua(L, 1)
    check_shape_valid(L, shape)
    filter := b2.Shape_GetFilter(shape.id)
    filter.categoryBits = u64(lua.L_checkinteger(L, 2))
    b2.Shape_SetFilter(shape.id, filter)

    return 0
}

@(private="file")
_set_contact_events :: proc "c" (L: ^lua.State) -> i32 {
    shape := PhysicsShapeFromLua(L, 1)
    check_shape_valid(L, shape)
    b2.Shape_EnableContactEvents(shape.id, bool(lua.toboolean(L, 2)))

    return 0
}

@(private="file")
_set_density :: proc "c" (L: ^lua.State) -> i32 {
    shape := PhysicsShapeFromLua(L, 1)
    check_shape_valid(L, shape)
    density := f32(lua.L_checknumber(L, 2))
    if density < 0 {
        return i32(lua.L_argerror(L, 2, "density must be >= 0"))
    }

    b2.Shape_SetDensity(shape.id, density, true)

    return 0
}

@(private="file")
_set_friction :: proc "c" (L: ^lua.State) -> i32 {
    shape := PhysicsShapeFromLua(L, 1)
    check_shape_valid(L, shape)
    friction := f32(lua.L_checknumber(L, 2))
    if friction < 0 {
        return i32(lua.L_argerror(L, 2, "friction must be >= 0"))
    }

    b2.Shape_SetFriction(shape.id, friction)

    return 0
}

@(private="file")
_set_group :: proc "c" (L: ^lua.State) -> i32 {
    shape := PhysicsShapeFromLua(L, 1)
    check_shape_valid(L, shape)
    filter := b2.Shape_GetFilter(shape.id)
    filter.groupIndex = i32(lua.L_checkinteger(L, 2))
    b2.Shape_SetFilter(shape.id, filter)

    return 0
}

@(private="file")
_set_hit_events :: proc "c" (L: ^lua.State) -> i32 {
    shape := PhysicsShapeFromLua(L, 1)
    check_shape_valid(L, shape)
    b2.Shape_EnableHitEvents(shape.id, bool(lua.toboolean(L, 2)))

    return 0
}

@(private="file")
_set_mask :: proc "c" (L: ^lua.State) -> i32 {
    shape := PhysicsShapeFromLua(L, 1)
    check_shape_valid(L, shape)
    filter := b2.Shape_GetFilter(shape.id)
    filter.maskBits = u64(lua.L_checkinteger(L, 2))
    b2.Shape_SetFilter(shape.id, filter)

    return 0
}

@(private="file")
_set_restitution :: proc "c" (L: ^lua.State) -> i32 {
    shape := PhysicsShapeFromLua(L, 1)
    check_shape_valid(L, shape)
    restitution := f32(lua.L_checknumber(L, 2))
    if restitution < 0 {
        return i32(lua.L_argerror(L, 2, "restitution must be >= 0"))
    }

    b2.Shape_SetRestitution(shape.id, restitution)

    return 0
}

@(private="file")
_set_sensor_events :: proc "c" (L: ^lua.State) -> i32 {
    shape := PhysicsShapeFromLua(L, 1)
    check_shape_valid(L, shape)
    b2.Shape_EnableSensorEvents(shape.id, bool(lua.toboolean(L, 2)))

    return 0
}

@(private="file")
_set_tag :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    shape := PhysicsShapeFromLua(L, 1)
    check_shape_valid(L, shape)

    if shape.tag != nil {
        delete(shape.tag)
    }
    shape.tag = strings.clone_to_cstring(string(lua.L_checkstring(L, 2)))

    return 0
}

@(private="file")
__gc :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    handle := (^PhysicsShapeHandle)(lua.touserdata(L, 1))
    if handle.shape != nil {
        if handle.owns {
            DestroyPhysicsShape(handle.shape)
        }

        release_shape_ref(handle.shape)
        handle.shape = nil
        handle.owns = false
    }

    return 0
}
