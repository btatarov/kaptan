package core

import "core:log"

import lua "vendor:lua/jit"

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
        { "getFrameProfile",     _get_frame_profile },
        { "isDebugBuild",         _is_debug_build },
        { "isFrameProfiling",     _is_frame_profiling },
        { "isFPSCounterEnabled",  _is_fps_counter_enabled },
        { "isLuaGCLogging",       _is_lua_gc_logging },
        { "resetFrameProfile",   _reset_frame_profile },
        { "setFrameProfiling",   _set_frame_profiling },
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
    lua.L_getmetatable(L, GC_SENTINEL_METATABLE)
    lua.setmetatable(L, -2)
    lua.pop(L, 1)
}

@(private="file")
environment_collectgarbage :: proc "c" (L: ^lua.State) -> i32 {
    context = GetDefaultContext()

    arg_count := lua.gettop(L)

    if environment.gc_logging {
        option := lua.L_optstring(L, 1, "collect")
        log.infof("KaptanEnvironment: Lua GC requested: %s", option)
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
        log.infof("KaptanEnvironment: Lua GC finalizer cycle observed")
    }

    if environment.sentinel_enabled && ! environment.destroying {
        environment_arm_gc_sentinel(L)
    }

    return 0
}

@(private="file")
push_bucket_table :: proc "contextless" (L: ^lua.State, bucket: FrameProfileBucketSnapshot) {
    lua.createtable(L, 0, 5)

    lua.pushnumber(L, lua.Number(bucket.last_ms))
    lua.setfield(L, -2, "lastMs")

    lua.pushnumber(L, lua.Number(bucket.avg_ms))
    lua.setfield(L, -2, "avgMs")

    lua.pushnumber(L, lua.Number(bucket.max_ms))
    lua.setfield(L, -2, "maxMs")

    lua.pushnumber(L, lua.Number(bucket.p95_ms))
    lua.setfield(L, -2, "p95Ms")

    lua.pushnumber(L, lua.Number(bucket.p99_ms))
    lua.setfield(L, -2, "p99Ms")
}

@(private="file")
push_render_counters_table :: proc "contextless" (L: ^lua.State, counters: FrameProfilerRenderCounters) {
    lua.createtable(L, 0, 9)

    lua.pushinteger(L, lua.Integer(counters.layer_items_visited))
    lua.setfield(L, -2, "layerItemsVisited")

    lua.pushinteger(L, lua.Integer(counters.sprites_drawn))
    lua.setfield(L, -2, "spritesDrawn")

    lua.pushinteger(L, lua.Integer(counters.sprites_skipped))
    lua.setfield(L, -2, "spritesSkipped")

    lua.pushinteger(L, lua.Integer(counters.draw_shapes_drawn))
    lua.setfield(L, -2, "drawShapesDrawn")

    lua.pushinteger(L, lua.Integer(counters.draw_shapes_skipped))
    lua.setfield(L, -2, "drawShapesSkipped")

    lua.pushinteger(L, lua.Integer(counters.texts_drawn))
    lua.setfield(L, -2, "textsDrawn")

    lua.pushinteger(L, lua.Integer(counters.texts_skipped))
    lua.setfield(L, -2, "textsSkipped")

    lua.pushinteger(L, lua.Integer(counters.text_boxes_drawn))
    lua.setfield(L, -2, "textBoxesDrawn")

    lua.pushinteger(L, lua.Integer(counters.text_boxes_skipped))
    lua.setfield(L, -2, "textBoxesSkipped")
}

@(private="file")
set_bucket_field :: proc "contextless" (L: ^lua.State, name: cstring, bucket: FrameProfileBucketSnapshot) {
    push_bucket_table(L, bucket)
    lua.setfield(L, -2, name)
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
_get_frame_profile :: proc "c" (L: ^lua.State) -> i32 {
    context = GetDefaultContext()

    snapshot := FrameProfilerSnapshot()

    lua.createtable(L, 0, 13)

    lua.pushboolean(L, b32(snapshot.enabled))
    lua.setfield(L, -2, "enabled")

    lua.pushinteger(L, lua.Integer(snapshot.frames))
    lua.setfield(L, -2, "frames")

    set_bucket_field(L, "total", snapshot.total)
    set_bucket_field(L, "physics", snapshot.physics)
    set_bucket_field(L, "lua", snapshot.lua)
    set_bucket_field(L, "audio", snapshot.audio)
    set_bucket_field(L, "render", snapshot.render)
    set_bucket_field(L, "endDrawing", snapshot.end_drawing)
    set_bucket_field(L, "tempFree", snapshot.temp_free)

    push_render_counters_table(L, snapshot.last_render_counters)
    lua.setfield(L, -2, "lastRender")

    push_render_counters_table(L, snapshot.total_render_counters)
    lua.setfield(L, -2, "totalRender")

    return 1
}

@(private="file")
_is_frame_profiling :: proc "c" (L: ^lua.State) -> i32 {
    lua.pushboolean(L, b32(FrameProfilerIsEnabled()))

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
_reset_frame_profile :: proc "c" (L: ^lua.State) -> i32 {
    FrameProfilerReset()

    return 0
}

@(private="file")
_set_frame_profiling :: proc "c" (L: ^lua.State) -> i32 {
    FrameProfilerSetEnabled(bool(lua.toboolean(L, 1)))

    return 0
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
