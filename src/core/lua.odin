package core

import "core:fmt"
import "core:log"
import "core:strings"

import lua "vendor:lua/5.4"

KAPTAN_METHODS_FIELD :: "__kaptan_methods"

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
    L: ^lua.State,
    name: cstring,
    static_reg_table: ^[]lua.L_Reg,
    instance_reg_table: ^[]lua.L_Reg,
    destructor: proc "c" (L: ^lua.State) -> i32,
) {
    lua.newtable(L)
    lua.L_setfuncs(L, raw_data(static_reg_table[:]), 0)

    lua.pushvalue(L, lua.gettop(L))
    lua.setglobal(L, name)

    lua_setup_class_metatable(L, name, instance_reg_table, destructor)

    lua.pop(L, 2)
}

LuaBindClassWithConstants :: proc(
    L: ^lua.State,
    name: cstring,
    static_reg_table: ^[]lua.L_Reg,
    instance_reg_table: ^[]lua.L_Reg,
    constants: ^map[string]u32,
    destructor: proc "c" (L: ^lua.State) -> i32,
) {
    lua.newtable(L)
    lua.L_setfuncs(L, raw_data(static_reg_table[:]), 0)

    lua.pushvalue(L, lua.gettop(L))
    lua.setglobal(L, name)

    for name, _ in constants {
        lua.pushinteger(L, lua.Integer(constants[name]))
        lua.setfield(L, -2, fmt.ctprintf("%s", name))
    }

    lua_setup_class_metatable(L, name, instance_reg_table, destructor)

    lua.pop(L, 2)
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

    lua.pop(L, 1)
}

LuaBindSingletonWithConstants :: proc(
    L: ^lua.State,
    name: cstring,
    reg_table: ^[]lua.L_Reg,
    constants: ^map[cstring]u32,
) {
    lua.newtable(L)
    lua.pushvalue(L, lua.gettop(L))
    lua.setglobal(L, name)
    lua.L_setfuncs(L, raw_data(reg_table[:]), 0)

    for const_name, _ in constants {
        lua.pushinteger(L, lua.Integer(constants[const_name]))
        lua.setfield(L, -2, const_name)
    }

    lua.pop(L, 1)
}

LuaIsUserdataType :: proc "contextless" (L: ^lua.State, idx: i32, metatable_name: cstring) -> bool {
    if ! lua.isuserdata(L, idx) {
        return false
    }

    abs_idx := LuaGetAbsIndex(L, idx)
    if lua.getmetatable(L, abs_idx) == 0 {
        return false
    }

    lua.L_getmetatable(L, metatable_name)

    result := lua.rawequal(L, -1, -2)
    lua.pop(L, 2)

    return bool(result)
}

LuaUserdataHandle :: proc "contextless" (L: ^lua.State, idx: i32, metatable_name: cstring) -> rawptr {
    handle := (^rawptr)(lua.L_checkudata(L, idx, metatable_name))
    return handle^
}

LuaGetField :: proc "contextless" (L: ^lua.State, idx, key: i32) {
    abs_idx := LuaGetAbsIndex(L, idx)
	lua.pushinteger(L, lua.Integer(key))
	lua.gettable(L, abs_idx)
}

LuaGetAbsIndex :: proc "contextless" (L: ^lua.State, idx: i32) -> i32 {
    if idx < 0 {
        return lua.gettop(L) + idx + 1
    }
    return idx
}

LuaPushTableItr :: proc "contextless" (L: ^lua.State, idx: i32) -> i32 {
    itr := LuaGetAbsIndex(L, idx)
	lua.pushnil(L)
	lua.pushnil(L)
	lua.pushnil(L)
	return itr
}

LuaTableItrNext :: proc "contextless" (L: ^lua.State, itr: i32) -> bool {
    lua.pop(L, 2)  // pop the prev key/value; leave the key
    if lua.next(L, itr) != 0 {
		LuaCopyToTop(L, -2)
		LuaMoveToTop(L, -2)
		return true
	}
	return false
}

LuaCopyToTop :: proc "contextless" (L: ^lua.State, idx: i32) {
    lua.pushvalue(L, idx)
}

LuaMoveToTop :: proc "contextless" (L: ^lua.State, idx: i32) {
    abs_idx := LuaGetAbsIndex(L, idx)
    lua.pushvalue(L, abs_idx)
	lua.remove(L, abs_idx)
}

@(private="file")
lua_ensure_uservalue_table :: proc "contextless" (L: ^lua.State, idx: i32) -> i32 {
    abs_idx := LuaGetAbsIndex(L, idx)

    lua.getuservalue(L, abs_idx)
    if lua.istable(L, -1) {
        return lua.gettop(L)
    }
    lua.pop(L, 1)

    lua.newtable(L)
    lua.pushvalue(L, -1)
    lua.setuservalue(L, abs_idx)

    return lua.gettop(L)
}

@(private="file")
lua_setup_class_metatable :: proc(
    L: ^lua.State,
    name: cstring,
    instance_reg_table: ^[]lua.L_Reg,
    destructor: proc "c" (L: ^lua.State) -> i32,
) {
    lua.L_newmetatable(L, fmt.ctprintf("%sMT", name))

    lua.pushstring(L, "__gc")
    lua.pushcfunction(L, lua.CFunction(destructor))
    lua.settable(L, -3)

    lua.pushstring(L, KAPTAN_METHODS_FIELD)
    lua.newtable(L)
    lua.L_setfuncs(L, raw_data(instance_reg_table[:]), 0)
    lua.pushcfunction(L, lua.CFunction(lua_userdata_set_interface))
    lua.setfield(L, -2, "setInterface")
    lua.settable(L, -3)

    lua.pushstring(L, "__index")
    lua.pushcfunction(L, lua.CFunction(lua_userdata_index))
    lua.settable(L, -3)

    lua.pushstring(L, "__newindex")
    lua.pushcfunction(L, lua.CFunction(lua_userdata_newindex))
    lua.settable(L, -3)
}

@(private="file")
lua_userdata_set_interface :: proc "c" (L: ^lua.State) -> i32 {
    if ! lua.isuserdata(L, 1) {
        return i32(lua.L_typeerror(L, 1, "userdata"))
    }
    if ! lua.istable(L, 2) {
        return i32(lua.L_typeerror(L, 2, "table"))
    }

    member_idx := lua_ensure_uservalue_table(L, 1)
    lua.pushvalue(L, 2)
    lua.setmetatable(L, member_idx)
    lua.pop(L, 1)

    return 0
}

@(private="file")
lua_userdata_index :: proc "c" (L: ^lua.State) -> i32 {
    lua.getuservalue(L, 1)
    if lua.istable(L, -1) {
        lua.pushvalue(L, 2)
        lua.gettable(L, -2)
        if ! lua.isnil(L, -1) {
            return 1
        }
        lua.pop(L, 1)
    }
    lua.pop(L, 1)

    if lua.getmetatable(L, 1) != 0 {
        lua.getfield(L, -1, KAPTAN_METHODS_FIELD)
        if lua.istable(L, -1) {
            lua.pushvalue(L, 2)
            lua.gettable(L, -2)
            return 1
        }
        lua.pop(L, 1)
    }

    lua.pushnil(L)
    return 1
}

@(private="file")
lua_userdata_newindex :: proc "c" (L: ^lua.State) -> i32 {
    if ! lua.isuserdata(L, 1) {
        return i32(lua.L_typeerror(L, 1, "userdata"))
    }

    member_idx := lua_ensure_uservalue_table(L, 1)
    lua.pushvalue(L, 2)
    lua.pushvalue(L, 3)
    lua.settable(L, member_idx)
    lua.pop(L, 1)

    return 0
}
