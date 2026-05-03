package physics

import "core:c"
import "core:log"
import "core:math"

import b2 "vendor:box2d"
import lua "vendor:lua/5.4"

import "../core"

PhysicsBody :: struct {
    id:      b2.BodyId,
    is_gone: bool,
}

PhysicsBodyKind :: enum u32 {
    Static,
    Kinematic,
    Dynamic,
}

InitPhysicsBody :: proc(body: ^PhysicsBody, id: b2.BodyId) {
    log.debugf("KaptanBody: Init")

    body.id = id
    body.is_gone = false
}

DestroyPhysicsBody :: proc(body: ^PhysicsBody) {
    if body == nil {
        return
    }

    if ! body.is_gone && b2.Body_IsValid(body.id) {
        log.debugf("KaptanBody: Destroy")
        b2.DestroyBody(body.id)
    }

    body.is_gone = true
    body.id = {}
    PhysicsSystemUnregisterBody(body)
}

FreePhysicsBody :: proc(body: ^PhysicsBody) {
    if body == nil {
        return
    }

    DestroyPhysicsBody(body)
    free(body)
}

PhysicsBodyInvalidate :: proc(body: ^PhysicsBody) {
    if body == nil {
        return
    }

    body.is_gone = true
    body.id = {}
}

PhysicsBodyIsValid :: proc "contextless" (body: ^PhysicsBody) -> bool {
    return body != nil && ! body.is_gone && b2.Body_IsValid(body.id)
}

PhysicsBodyFromLua :: proc "contextless" (L: ^lua.State, idx: i32) -> ^PhysicsBody {
    return (^PhysicsBody)(core.LuaUserdataHandle(L, idx, "KaptanBodyMT"))
}

PhysicsBodyLuaBind :: proc(L: ^lua.State) {
    @static static_reg_table: []lua.L_Reg = {
        { "new", _new },
        { nil, nil },
    }

    @static instance_reg_table: []lua.L_Reg = {
        { "destroy",               _destroy },
        { "getAngularDamping",     _get_angular_damping },
        { "getAngularVelocity",    _get_angular_velocity },
        { "getLinearDamping",      _get_linear_damping },
        { "getPos",                _get_pos },
        { "getRot",                _get_rot },
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
        { "setType",               _set_type },
        { "setVelocity",           _set_velocity },
        { nil, nil },
    }

    constants := make(map[string]u32, allocator = context.temp_allocator)
    constants["STATIC"] = u32(PhysicsBodyKind.Static)
    constants["KINEMATIC"] = u32(PhysicsBodyKind.Kinematic)
    constants["DYNAMIC"] = u32(PhysicsBodyKind.Dynamic)

    core.LuaBindClass(L, "KaptanBody", &static_reg_table, &instance_reg_table, &constants, __gc)
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
        lua.L_argerror(L, c.int(idx), "KaptanBody.STATIC, KaptanBody.KINEMATIC, or KaptanBody.DYNAMIC expected")
    }

    return kind
}

@(private="file")
check_body_valid :: proc "contextless" (L: ^lua.State, body: ^PhysicsBody) {
    if ! PhysicsBodyIsValid(body) {
        lua.L_error(L, "KaptanBody is no longer valid")
    }
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
    core.LuaBindClassMetatable(L, "KaptanBody")

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
