package core

import "core:log"

import lua "vendor:lua/5.4"

EnvironmentState :: struct {
    gc_logging:          bool,
    fps_counter_enabled: bool,
    sentinel_enabled:    bool,
    destroying:          bool,
    collectgarbage_ref:  i32,
}

@(private="file") environment: EnvironmentState
@(private="file") GC_SENTINEL_METATABLE :: "KaptanEnvironmentGCSentinelMT"

EnvironmentLuaBind :: proc(L: ^lua.State) {
    @static reg_table: []lua.L_Reg = {
        { "isDebugBuild",         _is_debug_build },
        { "isFPSCounterEnabled",  _is_fps_counter_enabled },
        { "isLuaGCLogging",       _is_lua_gc_logging },
        { "setFPSCounterEnabled", _set_fps_counter_enabled },
        { "setLuaGCLogging",      _set_lua_gc_logging },
        { nil, nil },
    }

    environment.gc_logging          = false
    environment.fps_counter_enabled = false
    environment.sentinel_enabled    = false
    environment.destroying          = false
    environment.collectgarbage_ref  = lua.REFNIL

    lua.getglobal(L, "collectgarbage")
    environment.collectgarbage_ref = lua.L_ref(L, lua.REGISTRYINDEX)
    lua.pushcfunction(L, lua.CFunction(environment_collectgarbage))
    lua.setglobal(L, "collectgarbage")

    lua.L_newmetatable(L, GC_SENTINEL_METATABLE)
    lua.pushcfunction(L, lua.CFunction(environment_gc_sentinel))
    lua.setfield(L, -2, "__gc")
    lua.pop(L, 1)

    LuaBindSingleton(L, "KaptanEnvironment", &reg_table)
}

EnvironmentLuaUnbind :: proc(L: ^lua.State) {
    environment.destroying       = true
    environment.gc_logging       = false
    environment.sentinel_enabled = false

    if environment.collectgarbage_ref != lua.REFNIL {
        lua.rawgeti(L, lua.REGISTRYINDEX, lua.Integer(environment.collectgarbage_ref))
        lua.setglobal(L, "collectgarbage")
        lua.L_unref(L, lua.REGISTRYINDEX, environment.collectgarbage_ref)
        environment.collectgarbage_ref = lua.REFNIL
    }
}

EnvironmentIsFPSCounterEnabled :: proc "contextless" () -> bool {
    return environment.fps_counter_enabled
}

@(private="file")
environment_arm_gc_sentinel :: proc "contextless" (L: ^lua.State) {
    _ = lua.newuserdata(L, 0)
    lua.L_setmetatable(L, GC_SENTINEL_METATABLE)
    lua.pop(L, 1)
}

@(private="file")
environment_collectgarbage :: proc "c" (L: ^lua.State) -> i32 {
    context = GetDefaultContext()

    arg_count := lua.gettop(L)

    if environment.gc_logging {
        option := lua.L_optstring(L, 1, "collect")
        log.debugf("KaptanEnvironment: Lua GC requested: %s", option)
    }

    if environment.collectgarbage_ref == lua.REFNIL {
        return i32(lua.L_error(L, "original collectgarbage function is not available"))
    }

    lua.rawgeti(L, lua.REGISTRYINDEX, lua.Integer(environment.collectgarbage_ref))
    lua.insert(L, 1)

    status := lua.pcall(L, arg_count, lua.MULTRET, 0)
    if status != 0 {
        return i32(lua.L_error(L, "%s", lua.tostring(L, -1)))
    }

    return lua.gettop(L)
}

@(private="file")
environment_gc_sentinel :: proc "c" (L: ^lua.State) -> i32 {
    context = GetDefaultContext()

    if environment.gc_logging {
        log.debugf("KaptanEnvironment: Lua GC finalizer cycle observed")
    }

    if environment.sentinel_enabled && ! environment.destroying {
        environment_arm_gc_sentinel(L)
    }

    return 0
}

@(private="file")
_is_debug_build :: proc "c" (L: ^lua.State) -> i32 {
    when ODIN_DEBUG {
        lua.pushboolean(L, b32(true))
    } else {
        lua.pushboolean(L, b32(false))
    }

    return 1
}

@(private="file")
_is_fps_counter_enabled :: proc "c" (L: ^lua.State) -> i32 {
    lua.pushboolean(L, b32(environment.fps_counter_enabled))

    return 1
}

@(private="file")
_is_lua_gc_logging :: proc "c" (L: ^lua.State) -> i32 {
    lua.pushboolean(L, b32(environment.gc_logging))

    return 1
}

@(private="file")
_set_fps_counter_enabled :: proc "c" (L: ^lua.State) -> i32 {
    environment.fps_counter_enabled = bool(lua.toboolean(L, 1))

    return 0
}

@(private="file")
_set_lua_gc_logging :: proc "c" (L: ^lua.State) -> i32 {
    enabled := bool(lua.toboolean(L, 1))
    environment.gc_logging = enabled
    environment.sentinel_enabled = enabled

    if enabled {
        environment_arm_gc_sentinel(L)
    }

    return 0
}
