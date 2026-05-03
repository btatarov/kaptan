package physics

import "core:c"
import "core:log"

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
        { "destroy", _destroy },
        { "getType", _get_type },
        { "isValid", _is_valid },
        { "setType", _set_type },
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
_get_type :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    check_body_valid(L, body)

    kind := body_kind_from_box2d(b2.Body_GetType(body.id))
    lua.pushinteger(L, lua.Integer(kind))

    return 1
}

@(private="file")
_is_valid :: proc "c" (L: ^lua.State) -> i32 {
    body := PhysicsBodyFromLua(L, 1)
    lua.pushboolean(L, b32(PhysicsBodyIsValid(body)))

    return 1
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
__gc :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    body := PhysicsBodyFromLua(L, 1)
    FreePhysicsBody(body)

    return 0
}
