package graphics

import "core:log"

import lua "vendor:lua/5.4"
import rl "vendor:raylib"

import "../core"

@(private="file") camera: rl.Camera2D

InitCamera :: proc() {
    log.debugf("KaptanCamera: Init")

    camera.zoom = 1.0
}

DestroyCamera :: proc() {
    log.debugf("KaptanCamera: Destroy")

    // nothing to do
}

GetCamera :: proc() -> ^rl.Camera2D {
    return &camera
}

CameraLuaBind :: proc(L: ^lua.State) {
    @static reg_table: []lua.L_Reg = {
        { "getPiv",  _get_piv },
        { "getPos",  _get_pos },
        { "getRot",  _get_rot },
        { "getZoom", _get_zoom },
        { "setPiv", _set_piv },
        { "setPos",  _set_pos },
        { "setRot",  _set_rot },
        { "setZoom", _set_zoom },
        { nil, nil },
    }
    core.LuaBindSingleton(L, "KaptanCamera", &reg_table)

    InitCamera()
}

CameraLuaUnbind :: proc(L: ^lua.State) {
    DestroyCamera()
}

@(private="file")
_get_piv :: proc "c" (L: ^lua.State) -> i32 {
    lua.pushnumber(L, lua.Number(camera.offset.x))
    lua.pushnumber(L, lua.Number(camera.offset.y))

    return 2
}

@(private="file")
_get_pos :: proc "c" (L: ^lua.State) -> i32 {
    lua.pushnumber(L, lua.Number(camera.target.x))
    lua.pushnumber(L, lua.Number(camera.target.y))

    return 2
}

@(private="file")
_get_rot :: proc "c" (L: ^lua.State) -> i32 {
    lua.pushnumber(L, lua.Number(camera.rotation))

    return 1
}

@(private="file")
_get_zoom :: proc "c" (L: ^lua.State) -> i32 {
    lua.pushnumber(L, lua.Number(camera.zoom))

    return 1
}

@(private="file")
_set_piv :: proc "c" (L: ^lua.State) -> i32 {
    camera.offset.x = f32(lua.tonumber(L, 1))
    camera.offset.y = f32(lua.tonumber(L, 2))

    return 0
}

@(private="file")
_set_pos :: proc "c" (L: ^lua.State) -> i32 {
    camera.target.x = f32(lua.tonumber(L, 1))
    camera.target.y = f32(lua.tonumber(L, 2))

    return 0
}

@(private="file")
_set_rot :: proc "c" (L: ^lua.State) -> i32 {
    camera.rotation = f32(lua.tonumber(L, 1))

    return 0
}

@(private="file")
_set_zoom :: proc "c" (L: ^lua.State) -> i32 {
    camera.zoom = f32(lua.tonumber(L, 1))

    return 0
}
