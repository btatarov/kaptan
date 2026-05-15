package graphics

import "core:log"

import lua "vendor:lua/jit"
import rl "vendor:raylib"

import "../audio"
import "../core"
import "../physics"

Window :: struct {
    title:  cstring,
    frames: i64,
    time:   f64,
    close:  bool,
}

@(private="file") window: Window
@(private="file") loop_callback_ref: i32 = lua.REFNIL

InitWindow :: proc(title : cstring, width, height : i32) {
    log.debugf("KaptanWindow: Open")

    window.title = title

    rl.InitWindow(width, height, window.title)
}

DestroyWindow :: proc() {
    if ! rl.IsWindowReady() {
        return
    }

    log.debugf("KaptanWindow: Close")

    rl.CloseWindow()
}

// TODO:
// - handle window resize with [get/set]ResizeCallback
WindowLuaBind :: proc(L: ^lua.State) {
    @static reg_table: []lua.L_Reg = {
        { "open",                _open },
        { "clearLoopCallback",   _clearLoopCallback },
        { "getDeltaTime",        _getDeltaTime },
        { "getFPS",              _getFPS },
        { "getHeight",           _getHeight },
        { "getWidth",            _getWidth },
        { "setLoopCallback",     _setLoopCallback },
        { "setMaxFPS",           _setMaxFPS },
        { "setVsync",            _setVsync },
        { "quit",                _quit },
        { nil, nil },
    }
    core.LuaBindSingleton(L, "KaptanWindow", &reg_table)
}

WindowLuaUnbind :: proc(L: ^lua.State) {
    DestroyWindow()
}

WindowMainLoop :: proc() {
    if ! rl.IsWindowReady() {
        return
    }

    log.debugf("KaptanWindow: MainLoop")

    for ! window.close && ! rl.WindowShouldClose() {
        profile_enabled := core.FrameProfilerIsEnabled()
        profile_frame_start: core.FrameProfilerTick
        if profile_enabled {
            profile_frame_start = core.FrameProfilerBeginFrame()
        }

        // physics
        profile_physics_start: core.FrameProfilerTick
        if profile_enabled {
            profile_physics_start = core.FrameProfilerNow()
        }
        physics.PhysicsSystemUpdate(rl.GetFrameTime())
        if profile_enabled {
            core.FrameProfilerAddPhysics(profile_physics_start)
        }

        // logic
        profile_lua_start: core.FrameProfilerTick
        if profile_enabled {
            profile_lua_start = core.FrameProfilerNow()
        }
        if loop_callback_ref != lua.REFNIL {
            L := core.GetLuaState()

            lua.rawgeti(L, lua.REGISTRYINDEX, lua.Integer(loop_callback_ref))

            status := lua.pcall(L, 0, 0, 0)
            if ! core.LuaCheckOK(L, lua.Status(status)) {
                lua.pop(L, 1)
                _clearLoopCallback(L)
            }
        }
        if profile_enabled {
            core.FrameProfilerAddLua(profile_lua_start)
        }

        // audio
        profile_audio_start: core.FrameProfilerTick
        if profile_enabled {
            profile_audio_start = core.FrameProfilerNow()
        }
        audio.AudioSystemUpdate()
        if profile_enabled {
            core.FrameProfilerAddAudio(profile_audio_start)
        }

        // rendering
        RendererDraw()

        window.frames += 1
        window.time += f64(rl.GetFrameTime())

        profile_temp_free_start: core.FrameProfilerTick
        if profile_enabled {
            profile_temp_free_start = core.FrameProfilerNow()
        }
        free_all(context.temp_allocator)
        if profile_enabled {
            core.FrameProfilerAddTempFree(profile_temp_free_start)
            core.FrameProfilerEndFrame(profile_frame_start)
        }
    }
}

@(private="file")
_open :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    title := lua.L_checkstring(L, 1)
    width := lua.L_checkinteger(L, 2)
    height := lua.L_checkinteger(L, 3)

    InitWindow(title, i32(width), i32(height))

    return 0
}

@(private="file")
_clearLoopCallback :: proc "c" (L: ^lua.State) -> i32 {
    if loop_callback_ref != lua.REFNIL {
        lua.L_unref(L, lua.REGISTRYINDEX, loop_callback_ref)
        loop_callback_ref = lua.REFNIL
    }

    return 0
}

@(private="file")
_getDeltaTime :: proc "c" (L: ^lua.State) -> i32 {
    delta_time := rl.GetFrameTime()

    lua.pushnumber(L, lua.Number(delta_time))

    return 1
}

@(private="file")
_getFPS :: proc "c" (L: ^lua.State) -> i32 {
    fps := rl.GetFPS()

    lua.pushinteger(L, lua.Integer(fps))

    return 1
}

@(private="file")
_getWidth :: proc "c" (L: ^lua.State) -> i32 {
    width := rl.GetScreenWidth()

    lua.pushinteger(L, lua.Integer(width))

    return 1
}

@(private="file")
_getHeight :: proc "c" (L: ^lua.State) -> i32 {
    height := rl.GetScreenHeight()

    lua.pushinteger(L, lua.Integer(height))

    return 1
}

@(private="file")
_setLoopCallback :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    if ! lua.isfunction(L, 1) {
        lua.L_error(L, "bad argument #1 (function expected)")
        return 0
    }

    _clearLoopCallback(L)
    loop_callback_ref = lua.L_ref(L, lua.REGISTRYINDEX)

    return 0
}

@(private="file")
_setMaxFPS :: proc "c" (L: ^lua.State) -> i32 {
    fps := lua.L_checkinteger(L, 1)

    rl.SetTargetFPS(i32(fps))

    return 0
}

@(private="file")
_setVsync :: proc "c" (L: ^lua.State) -> i32 {
    enabled := lua.toboolean(L, 1)

    if enabled {
        rl.SetWindowState({.VSYNC_HINT})
    } else {
        rl.ClearWindowState({.VSYNC_HINT})
    }

    return 0
}

@(private="file")
_quit :: proc "c" (L: ^lua.State) -> i32 {
    window.close = true

    return 0
}
