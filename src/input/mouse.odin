package input

import "core:fmt"

import lua "vendor:lua/5.4"
import rl "vendor:raylib"

import core "../core"
import graphics "../graphics"

MouseLuaBind :: proc(L: ^lua.State) {
    @static reg_table: []lua.L_Reg = {
        { "getDelta",     _get_delta },
        { "getPos",       _get_pos },
        { "getScreenPos", _get_screen_pos },
        { "getWheel",     _get_wheel },
        { "getWheelV",    _get_wheel_v },
        { "getWorldPos",  _get_world_pos },
        { "isDown",       _is_down },
        { "isPressed",    _is_pressed },
        { "isReleased",   _is_released },
        { "isUp",         _is_up },
        { nil, nil },
    }

    constants := make(map[cstring]u32, allocator = context.temp_allocator)
    for name, _ in rl.MouseButton {
        constants[fmt.ctprintf("BUTTON_%s", name)] = u32(rl.MouseButton(name))
    }

    core.LuaBindSingleton(L, "KaptanMouse", &reg_table, &constants)
}

MouseLuaUnbind :: proc(L: ^lua.State) {
    // EMPTY
}

@(private="file")
_get_delta :: proc "c" (L: ^lua.State) -> i32 {
    delta := rl.GetMouseDelta()

    lua.pushnumber(L, lua.Number(delta.x))
    lua.pushnumber(L, lua.Number(delta.y))

    return 2
}

@(private="file")
_get_pos :: proc "c" (L: ^lua.State) -> i32 {
    position := rl.GetMousePosition()

    lua.pushnumber(L, lua.Number(position.x - f32(rl.GetScreenWidth()) * 0.5))
    lua.pushnumber(L, lua.Number(position.y - f32(rl.GetScreenHeight()) * 0.5))

    return 2
}

@(private="file")
_get_screen_pos :: proc "c" (L: ^lua.State) -> i32 {
    position := rl.GetMousePosition()

    lua.pushnumber(L, lua.Number(position.x))
    lua.pushnumber(L, lua.Number(position.y))

    return 2
}

@(private="file")
_get_wheel :: proc "c" (L: ^lua.State) -> i32 {
    lua.pushnumber(L, lua.Number(rl.GetMouseWheelMove()))

    return 1
}

@(private="file")
_get_wheel_v :: proc "c" (L: ^lua.State) -> i32 {
    wheel := rl.GetMouseWheelMoveV()

    lua.pushnumber(L, lua.Number(wheel.x))
    lua.pushnumber(L, lua.Number(wheel.y))

    return 2
}

@(private="file")
_get_world_pos :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    position := rl.GetScreenToWorld2D(rl.GetMousePosition(), graphics.GetCamera()^)

    lua.pushnumber(L, lua.Number(position.x))
    lua.pushnumber(L, lua.Number(position.y))

    return 2
}

@(private="file")
_is_down :: proc "c" (L: ^lua.State) -> i32 {
    button := rl.MouseButton(lua.L_checkinteger(L, 1))

    lua.pushboolean(L, b32(rl.IsMouseButtonDown(button)))

    return 1
}

@(private="file")
_is_pressed :: proc "c" (L: ^lua.State) -> i32 {
    button := rl.MouseButton(lua.L_checkinteger(L, 1))

    lua.pushboolean(L, b32(rl.IsMouseButtonPressed(button)))

    return 1
}

@(private="file")
_is_released :: proc "c" (L: ^lua.State) -> i32 {
    button := rl.MouseButton(lua.L_checkinteger(L, 1))

    lua.pushboolean(L, b32(rl.IsMouseButtonReleased(button)))

    return 1
}

@(private="file")
_is_up :: proc "c" (L: ^lua.State) -> i32 {
    button := rl.MouseButton(lua.L_checkinteger(L, 1))

    lua.pushboolean(L, b32(rl.IsMouseButtonUp(button)))

    return 1
}
