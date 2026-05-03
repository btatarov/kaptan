package physics

import "core:log"

import b2 "vendor:box2d"
import lua "vendor:lua/5.4"

import "../core"

PhysicsShape :: struct {
    id:      b2.ShapeId,
    body:    ^PhysicsBody,
    is_gone: bool,
}

InitPhysicsShape :: proc(shape: ^PhysicsShape, id: b2.ShapeId, body: ^PhysicsBody) {
    log.debugf("KaptanShape: Init")

    shape.id = id
    shape.body = body
    shape.is_gone = false
}

DestroyPhysicsShape :: proc(shape: ^PhysicsShape) {
    if shape == nil {
        return
    }

    if ! shape.is_gone && b2.Shape_IsValid(shape.id) {
        log.debugf("KaptanShape: Destroy")
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
    free(shape)
}

PhysicsShapeInvalidate :: proc(shape: ^PhysicsShape) {
    if shape == nil {
        return
    }

    shape.is_gone = true
    shape.id = {}
    shape.body = nil
}

PhysicsShapeIsValid :: proc "contextless" (shape: ^PhysicsShape) -> bool {
    return shape != nil && ! shape.is_gone && b2.Shape_IsValid(shape.id)
}

PhysicsShapeFromLua :: proc "contextless" (L: ^lua.State, idx: i32) -> ^PhysicsShape {
    return (^PhysicsShape)(core.LuaUserdataHandle(L, idx, "KaptanShapeMT"))
}

PhysicsShapeLuaBind :: proc(L: ^lua.State) {
    @static static_reg_table: []lua.L_Reg = {
        { nil, nil },
    }

    @static instance_reg_table: []lua.L_Reg = {
        { "destroy", _destroy },
        { "isValid", _is_valid },
        { nil, nil },
    }

    core.LuaBindClass(L, "KaptanShape", &static_reg_table, &instance_reg_table, __gc)
}

PhysicsShapeLuaUnbind :: proc(L: ^lua.State) {
    // nothing to do
}

PhysicsShapePushLua :: proc(L: ^lua.State, shape: ^PhysicsShape) {
    handle := (^^PhysicsShape)(lua.newuserdata(L, size_of(^PhysicsShape)))
    handle^ = shape
    core.LuaBindClassMetatable(L, "KaptanShape")
}

@(private="file")
_destroy :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    shape := PhysicsShapeFromLua(L, 1)
    DestroyPhysicsShape(shape)

    return 0
}

@(private="file")
_is_valid :: proc "c" (L: ^lua.State) -> i32 {
    shape := PhysicsShapeFromLua(L, 1)
    lua.pushboolean(L, b32(PhysicsShapeIsValid(shape)))

    return 1
}

@(private="file")
__gc :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    shape := PhysicsShapeFromLua(L, 1)
    FreePhysicsShape(shape)

    return 0
}
