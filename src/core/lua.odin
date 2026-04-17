package core

import "core:fmt"
import "core:log"
import "core:strings"

import lua "vendor:lua/5.4"

@private LuaState: ^lua.State

InitLuaState :: proc() -> ^lua.State {
    LuaState = lua.L_newstate()
    lua.L_openlibs(LuaState)
    return LuaState
}

DestroyLuaState :: proc(L: ^lua.State) {
    lua.close(L)
}

GetLuaState :: proc() -> ^lua.State {
    return LuaState
}

LuaCheckOK :: proc(L: ^lua.State, status: lua.Status) -> bool {
    if status != lua.OK {
        log.errorf("%s", lua.tostring(L, -1))
        return false
    }
    return true
}

LuaRun :: proc(L: ^lua.State, args: []string) -> bool {
    if len(args) < 1 {
        LuaCheckOK(L, lua.L_loadfile(L, "main.lua")) or_return
    } else {
        c_file := strings.clone_to_cstring(args[0], context.temp_allocator)
        LuaCheckOK(L, lua.L_loadfile(L, c_file)) or_return
    }

    status := lua.pcall(L, 0, 0, 0)
    LuaCheckOK(L, lua.Status(status)) or_return

    return true
}

LuaBindClass :: proc { LuaBindClassSimple, LuaBindClassWithConstants }

LuaBindClassSimple :: proc(
    L: ^lua.State, name: cstring,
    reg_table: ^[]lua.L_Reg,
    destructor: proc "c" (L: ^lua.State) -> i32,
) {
    lua.newtable(L)
    index := lua.gettop(L)

    lua.pushvalue(L, index)
    lua.setglobal(L, name)
    lua.L_setfuncs(L, raw_data(reg_table[:]), 0)

    lua.L_newmetatable(L, fmt.ctprintf("%sMT", name))

    lua.pushstring(L, "__gc")
    lua.pushcfunction(L, lua.CFunction(destructor))
    lua.settable(L, -3)

    lua.pushstring(L, "__index")
    lua.pushvalue(L, index)
    lua.settable(L, -3)
}

LuaBindClassWithConstants :: proc(
    L: ^lua.State, name: cstring,
    reg_table: ^[]lua.L_Reg,
    constants: ^map[string]u32,
    destructor: proc "c" (L: ^lua.State) -> i32,
) {
    lua.newtable(L)
    index := lua.gettop(L)

    lua.pushvalue(L, index)
    lua.setglobal(L, name)
    lua.L_setfuncs(L, raw_data(reg_table[:]), 0)

    for name, _ in constants {
        lua.pushinteger(L, lua.Integer(constants[name]))
        lua.setfield(L, -2, fmt.ctprintf("%s", name))
    }

    lua.L_newmetatable(L, fmt.ctprintf("%sMT", name))

    lua.pushstring(L, "__gc")
    lua.pushcfunction(L, lua.CFunction(destructor))
    lua.settable(L, -3)

    lua.pushstring(L, "__index")
    lua.pushvalue(L, index)
    lua.settable(L, -3)
}

LuaBindClassMetatable :: proc(L: ^lua.State, name: cstring) {
    index := lua.gettop(L)
    lua.L_getmetatable(L, fmt.ctprintf("%sMT", name))
    assert(lua.istable(L, -1), fmt.tprintf("%sMT is not a table", name))
    lua.setmetatable(L, index)
}

LuaBindSingleton :: proc(L: ^lua.State, name: cstring, reg_table: ^[]lua.L_Reg) {
    lua.newtable(L)
    lua.pushvalue(L, lua.gettop(L))
    lua.setglobal(L, name)
    lua.L_setfuncs(L, raw_data(reg_table[:]), 0)
}

LuaGetField :: proc(L: ^lua.State, idx, key: i32) {
    abs_idx := LuaGetAbsIndex(L, idx)
	lua.pushinteger(L, lua.Integer(key))
	lua.gettable(L, abs_idx)
}

LuaGetAbsIndex :: proc(L: ^lua.State, idx: i32) -> i32 {
    if idx < 0 {
        return lua.gettop(L) + idx + 1
    }
    return idx
}

LuaPushTableItr :: proc(L: ^lua.State, idx: i32) -> i32 {
    itr := LuaGetAbsIndex(L, idx)
	lua.pushnil(L)
	lua.pushnil(L)
	lua.pushnil(L)
	return itr
}

LuaTableItrNext :: proc(L: ^lua.State, itr: i32) -> bool {
    lua.pop(L, 2)  // pop the prev key/value; leave the key
    if lua.next(L, itr) != 0 {
		LuaCopyToTop(L, -2)
		LuaMoveToTop(L, -2)
		return true
	}
	return false
}

LuaCopyToTop :: proc(L: ^lua.State, idx: i32) {
    lua.pushvalue(L, idx)
}

LuaMoveToTop :: proc(L: ^lua.State, idx: i32) {
    abs_idx := LuaGetAbsIndex(L, idx)
    lua.pushvalue(L, abs_idx)
	lua.remove(L, abs_idx)
}
