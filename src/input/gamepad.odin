package input

import "core:c"
import "core:fmt"

import lua "vendor:lua/5.4"
import rl "vendor:raylib"

import core "../core"

GamepadLuaBind :: proc(L: ^lua.State) {
    @static reg_table: []lua.L_Reg = {
        { "getAxis",          _get_axis },
        { "getAxisCount",     _get_axis_count },
        { "getButtonPressed", _get_button_pressed },
        { "getLeftStick",     _get_left_stick },
        { "getName",          _get_name },
        { "getRightStick",    _get_right_stick },
        { "getTriggers",      _get_triggers },
        { "isAvailable",      _is_available },
        { "isDown",           _is_down },
        { "isPressed",        _is_pressed },
        { "isReleased",       _is_released },
        { "isUp",             _is_up },
        { nil, nil },
    }

    constants := make(map[cstring]u32, allocator = context.temp_allocator)
    for name, _ in rl.GamepadButton {
        if name == .UNKNOWN {
            continue
        }

        constants[fmt.ctprintf("BUTTON_%s", name)] = u32(rl.GamepadButton(name))
    }

    for name, _ in rl.GamepadAxis {
        constants[fmt.ctprintf("AXIS_%s", name)] = u32(rl.GamepadAxis(name))
    }

    core.LuaBindSingletonWithConstants(L, "KaptanGamepad", &reg_table, &constants)
}

GamepadLuaUnbind :: proc(L: ^lua.State) {
    // EMPTY
}

@(private="file")
gamepad_from_lua :: proc "contextless" (L: ^lua.State, idx: i32) -> c.int {
    return c.int(lua.L_checkinteger(L, idx) - 1)
}

@(private="file")
button_from_lua :: proc "contextless" (L: ^lua.State, idx: i32) -> rl.GamepadButton {
    return rl.GamepadButton(lua.L_checkinteger(L, idx))
}

@(private="file")
axis_from_lua :: proc "contextless" (L: ^lua.State, idx: i32) -> rl.GamepadAxis {
    return rl.GamepadAxis(lua.L_checkinteger(L, idx))
}

@(private="file")
_get_axis :: proc "c" (L: ^lua.State) -> i32 {
    gamepad := gamepad_from_lua(L, 1)
    axis := axis_from_lua(L, 2)

    lua.pushnumber(L, lua.Number(rl.GetGamepadAxisMovement(gamepad, axis)))

    return 1
}

@(private="file")
_get_axis_count :: proc "c" (L: ^lua.State) -> i32 {
    gamepad := gamepad_from_lua(L, 1)

    lua.pushinteger(L, lua.Integer(rl.GetGamepadAxisCount(gamepad)))

    return 1
}

@(private="file")
_get_button_pressed :: proc "c" (L: ^lua.State) -> i32 {
    lua.pushinteger(L, lua.Integer(rl.GetGamepadButtonPressed()))

    return 1
}

@(private="file")
_get_left_stick :: proc "c" (L: ^lua.State) -> i32 {
    gamepad := gamepad_from_lua(L, 1)

    lua.pushnumber(L, lua.Number(rl.GetGamepadAxisMovement(gamepad, .LEFT_X)))
    lua.pushnumber(L, lua.Number(rl.GetGamepadAxisMovement(gamepad, .LEFT_Y)))

    return 2
}

@(private="file")
_get_name :: proc "c" (L: ^lua.State) -> i32 {
    gamepad := gamepad_from_lua(L, 1)
    name := rl.GetGamepadName(gamepad)

    if name == nil {
        lua.pushstring(L, "")
    } else {
        lua.pushstring(L, name)
    }

    return 1
}

@(private="file")
_get_right_stick :: proc "c" (L: ^lua.State) -> i32 {
    gamepad := gamepad_from_lua(L, 1)

    lua.pushnumber(L, lua.Number(rl.GetGamepadAxisMovement(gamepad, .RIGHT_X)))
    lua.pushnumber(L, lua.Number(rl.GetGamepadAxisMovement(gamepad, .RIGHT_Y)))

    return 2
}

@(private="file")
_get_triggers :: proc "c" (L: ^lua.State) -> i32 {
    gamepad := gamepad_from_lua(L, 1)

    lua.pushnumber(L, lua.Number(rl.GetGamepadAxisMovement(gamepad, .LEFT_TRIGGER)))
    lua.pushnumber(L, lua.Number(rl.GetGamepadAxisMovement(gamepad, .RIGHT_TRIGGER)))

    return 2
}

@(private="file")
_is_available :: proc "c" (L: ^lua.State) -> i32 {
    gamepad := gamepad_from_lua(L, 1)

    lua.pushboolean(L, b32(rl.IsGamepadAvailable(gamepad)))

    return 1
}

@(private="file")
_is_down :: proc "c" (L: ^lua.State) -> i32 {
    gamepad := gamepad_from_lua(L, 1)
    button := button_from_lua(L, 2)

    lua.pushboolean(L, b32(rl.IsGamepadButtonDown(gamepad, button)))

    return 1
}

@(private="file")
_is_pressed :: proc "c" (L: ^lua.State) -> i32 {
    gamepad := gamepad_from_lua(L, 1)
    button := button_from_lua(L, 2)

    lua.pushboolean(L, b32(rl.IsGamepadButtonPressed(gamepad, button)))

    return 1
}

@(private="file")
_is_released :: proc "c" (L: ^lua.State) -> i32 {
    gamepad := gamepad_from_lua(L, 1)
    button := button_from_lua(L, 2)

    lua.pushboolean(L, b32(rl.IsGamepadButtonReleased(gamepad, button)))

    return 1
}

@(private="file")
_is_up :: proc "c" (L: ^lua.State) -> i32 {
    gamepad := gamepad_from_lua(L, 1)
    button := button_from_lua(L, 2)

    lua.pushboolean(L, b32(rl.IsGamepadButtonUp(gamepad, button)))

    return 1
}
