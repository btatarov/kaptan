package physics

import "core:c"
import "core:log"
import "core:math"
import "core:strings"

import b2 "vendor:box2d"
import lua "vendor:lua/jit"

import "../core"

PhysicsBody :: struct {
    unique_id: u64,
    id:      b2.BodyId,
    shapes:  [dynamic]^PhysicsShape,
    tag:     cstring,
    is_gone: bool,
}

@(private="file") next_body_unique_id: u64 = 1

PhysicsBodyKind :: enum u32 {
    Static,
    Kinematic,
    Dynamic,
}

InitPhysicsBody :: proc(body: ^PhysicsBody, id: b2.BodyId) {
    log.debugf("KaptanPhysicsBody: Init")

    body.unique_id = next_body_unique_id
    next_body_unique_id += 1
    body.id = id
    body.shapes = make([dynamic]^PhysicsShape)
    body.tag = nil
    body.is_gone = false
}

DestroyPhysicsBody :: proc(body: ^PhysicsBody) {
    if body == nil {
        return
    }

    if ! body.is_gone && b2.Body_IsValid(body.id) {
        log.debugf("KaptanPhysicsBody: Destroy")
        invalidate_body_shapes(body)
        b2.DestroyBody(body.id)
    }

    body.is_gone = true
    body.id = {}
    clear(&body.shapes)
    PhysicsSystemUnregisterBody(body)
}

FreePhysicsBody :: proc(body: ^PhysicsBody) {
    if body == nil {
        return
    }

    DestroyPhysicsBody(body)
    if body.tag != nil {
        delete(body.tag)
    }
    delete(body.shapes)
    free(body)
}

PhysicsBodyInvalidate :: proc(body: ^PhysicsBody) {
    if body == nil {
        return
    }

    body.is_gone = true
    body.id = {}
    invalidate_body_shapes(body)
    clear(&body.shapes)
}

PhysicsBodyIsValid :: proc "contextless" (body: ^PhysicsBody) -> bool {
    return body != nil && ! body.is_gone && b2.Body_IsValid(body.id)
}

PhysicsBodyFromLua :: proc "contextless" (L: ^lua.State, idx: i32) -> ^PhysicsBody {
    return (^PhysicsBody)(core.LuaUserdataHandle(L, idx, "KaptanPhysicsBodyMT"))
}

PhysicsBodyLuaBind :: proc(L: ^lua.State) {
    @static static_reg_table: []lua.L_Reg = {
        { "new", _new },
        { nil, nil },
    }

    @static instance_reg_table: []lua.L_Reg = {
        { "destroy",               _destroy },
        { "addBox",                _add_box },
        { "addCapsule",            _add_capsule },
        { "addCircle",             _add_circle },
        { "addPolygon",            _add_polygon },
        { "applyAngularImpulse",   _apply_angular_impulse },
        { "applyForce",            _apply_force },
        { "applyImpulse",          _apply_impulse },
        { "applyTorque",           _apply_torque },
        { "getAngularDamping",     _get_angular_damping },
        { "getAngularVelocity",    _get_angular_velocity },
        { "getId",                 _get_id },
        { "getLinearDamping",      _get_linear_damping },
        { "getPos",                _get_pos },
        { "getRot",                _get_rot },
        { "getTag",                _get_tag },
        { "getType",               _get_type },
        { "getVelocity",           _get_velocity },
        { "isBullet",              _is_bullet },
        { "isEnabled",             _is_enabled },
        { "isFixedRotation",       _is_fixed_rotation },
        { "isValid",               _is_valid },
        { "setAngularDamping",     _set_angular_damping },
        { "setAngularVelocity",    _set_angular_velocity },
        { "setBullet",             _set_bullet },
        { "setEnabled",            _set_enabled },
        { "setFixedRotation",      _set_fixed_rotation },
        { "setLinearDamping",      _set_linear_damping },
        { "setPos",                _set_pos },
        { "setRot",                _set_rot },
        { "setTag",                _set_tag },
        { "setType",               _set_type },
        { "setVelocity",           _set_velocity },
        { nil, nil },
    }

    constants := make(map[string]u32, allocator = context.temp_allocator)
    constants["STATIC"] = u32(PhysicsBodyKind.Static)
    constants["KINEMATIC"] = u32(PhysicsBodyKind.Kinematic)
    constants["DYNAMIC"] = u32(PhysicsBodyKind.Dynamic)

    core.LuaBindClass(L, "KaptanPhysicsBody", &static_reg_table, &instance_reg_table, &constants, __gc)
}

PhysicsBodyLuaUnbind :: proc(L: ^lua.State) {
    // nothing to do
}

@(private="file")
body_kind_to_box2d :: proc "contextless" (kind: PhysicsBodyKind) -> b2.BodyType {
    switch kind {
    case .Static:
        return .staticBody
    case .Kinematic:
        return .kinematicBody
    case .Dynamic:
        return .dynamicBody
    }

    return .staticBody
}

@(private="file")
body_kind_from_box2d :: proc "contextless" (kind: b2.BodyType) -> PhysicsBodyKind {
    switch kind {
    case .staticBody:
        return .Static
    case .kinematicBody:
        return .Kinematic
    case .dynamicBody:
        return .Dynamic
    }

    return .Static
}

@(private="file")
body_kind_from_lua :: proc "contextless" (L: ^lua.State, idx: i32) -> PhysicsBodyKind {
    kind := PhysicsBodyKind(lua.L_checkinteger(L, idx))
    if kind != .Static && kind != .Kinematic && kind != .Dynamic {
        lua.L_argerror(L, c.int(idx), "KaptanPhysicsBody.STATIC, KaptanPhysicsBody.KINEMATIC, or KaptanPhysicsBody.DYNAMIC expected")
    }

    return kind
}

@(private="file")
check_body_valid :: proc "contextless" (L: ^lua.State, body: ^PhysicsBody) {
    if ! PhysicsBodyIsValid(body) {
        lua.L_error(L, "KaptanPhysicsBody is no longer valid")
    }
}

PhysicsBodyRegisterShape :: proc(body: ^PhysicsBody, shape: ^PhysicsShape) {
    append(&body.shapes, shape)
}

PhysicsBodyUnregisterShape :: proc(body: ^PhysicsBody, shape: ^PhysicsShape) {
    for existing, index in body.shapes {
        if existing == shape {
            ordered_remove(&body.shapes, index)
            return
        }
    }
}

@(private="file")
invalidate_body_shapes :: proc(body: ^PhysicsBody) {
    for shape in body.shapes {
        PhysicsShapeInvalidate(shape)
    }
}

@(private="file")
push_shape :: proc(L: ^lua.State, body: ^PhysicsBody, id: b2.ShapeId) -> i32 {
    shape := new(PhysicsShape)
    InitPhysicsShape(shape, id, body)
    PhysicsBodyRegisterShape(body, shape)
    PhysicsShapePushLua(L, shape)

    return 1
}

@(private="file")
body_get_rotation_degrees :: proc "contextless" (body: ^PhysicsBody) -> f32 {
    return math.to_degrees(b2.Rot_GetAngle(b2.Body_GetRotation(body.id)))
}

@(private="file")
body_set_transform :: proc "contextless" (body: ^PhysicsBody, position: b2.Vec2, rotation_degrees: f32) {
    b2.Body_SetTransform(body.id, position, b2.MakeRot(math.to_radians(rotation_degrees)))
}

@(private="file")
_new :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    PhysicsSystemRequireReady(L)

    kind := body_kind_from_lua(L, 1)
    body_def := b2.DefaultBodyDef()
    body_def.type = body_kind_to_box2d(kind)

    id := b2.CreateBody(PhysicsSystemGetWorld(), body_def)
    body := new(PhysicsBody)
    InitPhysicsBody(body, id)
    PhysicsSystemRegisterBody(body)

    handle := (^^PhysicsBody)(lua.newuserdata(L, size_of(^PhysicsBody)))
    handle^ = body
    core.LuaSetClassMetatable(L, "KaptanPhysicsBody")

    return 1
}

@(private="file")
_destroy :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    body := PhysicsBodyFromLua(L, 1)
    DestroyPhysicsBody(body)

    return 0
}

@(private="file")
_add_box :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)

    width := f32(lua.L_checknumber(L, 2))
    height := f32(lua.L_checknumber(L, 3))
    if width <= 0 {
        return i32(lua.L_argerror(L, 2, "box width must be > 0"))
    }
    if height <= 0 {
        return i32(lua.L_argerror(L, 3, "box height must be > 0"))
    }

    radius: f32
    options_idx := i32(4)
    if bool(lua.isnumber(L, 4)) {
        radius = f32(lua.L_checknumber(L, 4))
        if radius < 0 {
            return i32(lua.L_argerror(L, 4, "box radius must be >= 0"))
        }
        if radius > min(width, height) * 0.5 {
            return i32(lua.L_argerror(L, 4, "box radius must be <= half the smaller side"))
        }
        options_idx = 5
    }

    shape_def := PhysicsShapeDefaultDef(L, options_idx)
    polygon: b2.Polygon
    if radius > 0 {
        polygon = b2.MakeRoundedBox(width * 0.5, height * 0.5, radius)
    } else {
        polygon = b2.MakeBox(width * 0.5, height * 0.5)
    }
    id := b2.CreatePolygonShape(body.id, shape_def, polygon)

    return push_shape(L, body, id)
}

@(private="file")
_add_circle :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)

    radius := f32(lua.L_checknumber(L, 2))
    if radius <= 0 {
        return i32(lua.L_argerror(L, 2, "circle radius must be > 0"))
    }

    shape_def := PhysicsShapeDefaultDef(L, 3)
    circle := b2.Circle{center = b2.Vec2{0, 0}, radius = radius}
    id := b2.CreateCircleShape(body.id, shape_def, circle)

    return push_shape(L, body, id)
}

@(private="file")
_add_capsule :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)

    width := f32(lua.L_checknumber(L, 2))
    height := f32(lua.L_checknumber(L, 3))
    radius := f32(lua.L_checknumber(L, 4))
    if width <= 0 {
        return i32(lua.L_argerror(L, 2, "capsule width must be > 0"))
    }
    if height <= 0 {
        return i32(lua.L_argerror(L, 3, "capsule height must be > 0"))
    }
    if radius <= 0 {
        return i32(lua.L_argerror(L, 4, "capsule radius must be > 0"))
    }
    if radius > min(width, height) * 0.5 {
        return i32(lua.L_argerror(L, 4, "capsule radius must be <= half the smaller side"))
    }

    shape_def := PhysicsShapeDefaultDef(L, 5)
    half_width := width * 0.5
    half_height := height * 0.5
    capsule := b2.Capsule{}
    if height >= width {
        capsule.center1 = b2.Vec2{0, -half_height + radius}
        capsule.center2 = b2.Vec2{0, half_height - radius}
    } else {
        capsule.center1 = b2.Vec2{-half_width + radius, 0}
        capsule.center2 = b2.Vec2{half_width - radius, 0}
    }
    capsule.radius = radius
    id := b2.CreateCapsuleShape(body.id, shape_def, capsule)

    return push_shape(L, body, id)
}

@(private="file")
_add_polygon :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)

    if ! lua.istable(L, 2) {
        lua.L_error(L, "bad argument #2 (table expected)")
    }

    point_count := i32(lua.objlen(L, 2))
    if point_count < 6 || point_count % 2 != 0 {
        return i32(lua.L_argerror(L, 2, "polygon points must contain at least 3 x/y pairs"))
    }

    vertex_count := point_count / 2
    if vertex_count > b2.MAX_POLYGON_VERTICES {
        return i32(lua.L_argerror(L, 2, "polygon supports at most 8 points"))
    }

    points := make([]b2.Vec2, vertex_count, allocator = context.temp_allocator)
    for i := i32(0); i < vertex_count; i += 1 {
        lua.rawgeti(L, 2, lua.Integer(i * 2 + 1))
        x := f32(lua.L_checknumber(L, -1))
        lua.pop(L, 1)

        lua.rawgeti(L, 2, lua.Integer(i * 2 + 2))
        y := f32(lua.L_checknumber(L, -1))
        lua.pop(L, 1)

        points[i] = b2.Vec2{x, y}
    }

    hull := b2.ComputeHull(points)
    if ! b2.ValidateHull(hull) {
        return i32(lua.L_argerror(L, 2, "polygon points must form a valid convex hull"))
    }

    shape_def := PhysicsShapeDefaultDef(L, 3)
    polygon := b2.MakePolygon(hull, 0)
    id := b2.CreatePolygonShape(body.id, shape_def, polygon)

    return push_shape(L, body, id)
}

@(private="file")
_apply_angular_impulse :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)

    b2.Body_ApplyAngularImpulse(body.id, f32(lua.L_checknumber(L, 2)), true)

    return 0
}

@(private="file")
_apply_force :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)

    force := b2.Vec2{f32(lua.L_checknumber(L, 2)), f32(lua.L_checknumber(L, 3))}
    b2.Body_ApplyForceToCenter(body.id, force, true)

    return 0
}

@(private="file")
_apply_impulse :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)

    impulse := b2.Vec2{f32(lua.L_checknumber(L, 2)), f32(lua.L_checknumber(L, 3))}
    b2.Body_ApplyLinearImpulseToCenter(body.id, impulse, true)

    return 0
}

@(private="file")
_apply_torque :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)

    b2.Body_ApplyTorque(body.id, f32(lua.L_checknumber(L, 2)), true)

    return 0
}

@(private="file")
_get_angular_damping :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)

    lua.pushnumber(L, lua.Number(b2.Body_GetAngularDamping(body.id)))

    return 1
}

@(private="file")
_get_angular_velocity :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)

    lua.pushnumber(L, lua.Number(math.to_degrees(b2.Body_GetAngularVelocity(body.id))))

    return 1
}

@(private="file")
_get_id :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    lua.pushinteger(L, lua.Integer(body.unique_id))

    return 1
}

@(private="file")
_get_linear_damping :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)

    lua.pushnumber(L, lua.Number(b2.Body_GetLinearDamping(body.id)))

    return 1
}

@(private="file")
_get_pos :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)

    position := b2.Body_GetPosition(body.id)
    lua.pushnumber(L, lua.Number(position.x))
    lua.pushnumber(L, lua.Number(position.y))

    return 2
}

@(private="file")
_get_rot :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)

    lua.pushnumber(L, lua.Number(body_get_rotation_degrees(body)))

    return 1
}

@(private="file")
_get_tag :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)

    if body.tag == nil {
        lua.pushstring(L, "")
    } else {
        lua.pushstring(L, body.tag)
    }

    return 1
}

@(private="file")
_get_type :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)

    kind := body_kind_from_box2d(b2.Body_GetType(body.id))
    lua.pushinteger(L, lua.Integer(kind))

    return 1
}

@(private="file")
_get_velocity :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)

    velocity := b2.Body_GetLinearVelocity(body.id)
    lua.pushnumber(L, lua.Number(velocity.x))
    lua.pushnumber(L, lua.Number(velocity.y))

    return 2
}

@(private="file")
_is_bullet :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)

    lua.pushboolean(L, b32(b2.Body_IsBullet(body.id)))

    return 1
}

@(private="file")
_is_enabled :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)

    lua.pushboolean(L, b32(b2.Body_IsEnabled(body.id)))

    return 1
}

@(private="file")
_is_fixed_rotation :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)

    lua.pushboolean(L, b32(b2.Body_IsFixedRotation(body.id)))

    return 1
}

@(private="file")
_is_valid :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    lua.pushboolean(L, b32(PhysicsBodyIsValid(body)))

    return 1
}

@(private="file")
_set_angular_damping :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)

    b2.Body_SetAngularDamping(body.id, f32(lua.L_checknumber(L, 2)))

    return 0
}

@(private="file")
_set_angular_velocity :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)
    b2.Body_SetAngularVelocity(body.id, math.to_radians(f32(lua.L_checknumber(L, 2))))

    return 0
}

@(private="file")
_set_bullet :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)
    b2.Body_SetBullet(body.id, bool(lua.toboolean(L, 2)))

    return 0
}

@(private="file")
_set_enabled :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)

    if lua.toboolean(L, 2) {
        b2.Body_Enable(body.id)
    } else {
        b2.Body_Disable(body.id)
    }

    return 0
}

@(private="file")
_set_fixed_rotation :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)
    b2.Body_SetFixedRotation(body.id, bool(lua.toboolean(L, 2)))

    return 0
}

@(private="file")
_set_linear_damping :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)
    b2.Body_SetLinearDamping(body.id, f32(lua.L_checknumber(L, 2)))

    return 0
}

@(private="file")
_set_pos :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)

    position := b2.Vec2{f32(lua.L_checknumber(L, 2)), f32(lua.L_checknumber(L, 3))}
    body_set_transform(body, position, body_get_rotation_degrees(body))

    return 0
}

@(private="file")
_set_rot :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)
    body_set_transform(body, b2.Body_GetPosition(body.id), f32(lua.L_checknumber(L, 2)))

    return 0
}

@(private="file")
_set_tag :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)

    if body.tag != nil {
        delete(body.tag)
    }
    body.tag = strings.clone_to_cstring(string(lua.L_checkstring(L, 2)))

    return 0
}

@(private="file")
_set_type :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)

    kind := body_kind_from_lua(L, 2)
    b2.Body_SetType(body.id, body_kind_to_box2d(kind))

    return 0
}

@(private="file")
_set_velocity :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)

    b2.Body_SetLinearVelocity(body.id, b2.Vec2{f32(lua.L_checknumber(L, 2)), f32(lua.L_checknumber(L, 3))})

    return 0
}

@(private="file")
__gc :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    body := PhysicsBodyFromLua(L, 1)
    FreePhysicsBody(body)

    return 0
}
