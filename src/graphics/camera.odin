package graphics

import "core:log"

import lua "vendor:lua/5.4"
import rl "vendor:raylib"

import "../core"

Camera :: struct {
    using transform: Transform,
    zoom:            f32,
    raw:             rl.Camera2D,
}

@(private="file") camera: Camera
@(private="file") screen_camera: rl.Camera2D

InitCamera :: proc() {
    log.debugf("KaptanCamera: Init")

    InitTransform(&camera.transform)
    camera.zoom = 1.0
}

DestroyCamera :: proc() {
    log.debugf("KaptanCamera: Destroy")

    // nothing to do
}

GetCamera :: proc() -> ^rl.Camera2D {
    screen_center := rl.Vector2{
        f32(rl.GetScreenWidth()) * 0.5,
        f32(rl.GetScreenHeight()) * 0.5,
    }

    camera.raw.offset = rl.Vector2{screen_center.x + camera.pivot.x, screen_center.y + camera.pivot.y}
    camera.raw.target = rl.Vector2{camera.position.x, camera.position.y}
    camera.raw.rotation = camera.rotation
    camera.raw.zoom = camera.zoom

    return &camera.raw
}

GetScreenCamera :: proc() -> ^rl.Camera2D {
    screen_center := rl.Vector2{
        f32(rl.GetScreenWidth()) * 0.5,
        f32(rl.GetScreenHeight()) * 0.5,
    }

    screen_camera.offset = screen_center
    screen_camera.target = rl.Vector2{0, 0}
    screen_camera.rotation = 0
    screen_camera.zoom = 1

    return &screen_camera
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
    lua.pushnumber(L, lua.Number(camera.pivot.x))
    lua.pushnumber(L, lua.Number(camera.pivot.y))

    return 2
}

@(private="file")
_get_pos :: proc "c" (L: ^lua.State) -> i32 {
    lua.pushnumber(L, lua.Number(camera.position.x))
    lua.pushnumber(L, lua.Number(camera.position.y))

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
    camera.pivot.x = f32(lua.tonumber(L, 1))
    camera.pivot.y = f32(lua.tonumber(L, 2))

    return 0
}

@(private="file")
_set_pos :: proc "c" (L: ^lua.State) -> i32 {
    camera.position.x = f32(lua.tonumber(L, 1))
    camera.position.y = f32(lua.tonumber(L, 2))

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
