package input

import "core:fmt"

import lua "vendor:lua/5.4"
import rl "vendor:raylib"

import core "../core"

KeyboardLuaBind :: proc(L: ^lua.State) {
    @static reg_table: []lua.L_Reg = {
        { "getKeysDown", _get_keys_down },
        { "isDown",      _is_down },
        { "isPressed",   _is_pressed },
        { "isReleased",  _is_released },
        { "isUp",        _is_up },
        { nil, nil },
    }

    constants := make(map[cstring]u32, allocator=context.temp_allocator)
    for name, _ in rl.KeyboardKey {
        if name == .KEY_NULL {
            continue
        }
        constants[fmt.ctprintf("KEY_%s", name)] = u32(rl.KeyboardKey(name))
    }

    core.LuaBindSingletonWithConstants(L, "KaptanKeyboard", &reg_table, &constants)
}

KeyboardLuaUnbind :: proc(L: ^lua.State) {
    // EMPTY
}

@(private="file")
_get_keys_down :: proc "c" (L: ^lua.State) -> i32 {
    lua.createtable(L, 16, 0)

    idx := 1

    for key in rl.KeyboardKey {
        if key == .KEY_NULL {
            continue
        }

        if rl.IsKeyDown(key) {
            lua.pushinteger(L, lua.Integer(key))
            lua.rawseti(L, -2, lua.Integer(idx))
            idx += 1
        }
    }

    return 1
}

@(private="file")
_is_down :: proc "c" (L: ^lua.State) -> i32 {
    key := rl.KeyboardKey(lua.L_checkinteger(L, 1))

    lua.pushboolean(L, b32(rl.IsKeyDown(key)))

    return 1
}

@(private="file")
_is_pressed :: proc "c" (L: ^lua.State) -> i32 {
    key := rl.KeyboardKey(lua.L_checkinteger(L, 1))

    lua.pushboolean(L, b32(rl.IsKeyPressed(key)))

    return 1
}

@(private="file")
_is_released :: proc "c" (L: ^lua.State) -> i32 {
    key := rl.KeyboardKey(lua.L_checkinteger(L, 1))

    lua.pushboolean(L, b32(rl.IsKeyReleased(key)))

    return 1
}

@(private="file")
_is_up :: proc "c" (L: ^lua.State) -> i32 {
    key := rl.KeyboardKey(lua.L_checkinteger(L, 1))

    lua.pushboolean(L, b32(rl.IsKeyUp(key)))

    return 1
}
