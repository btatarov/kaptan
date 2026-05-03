package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"

import "audio"
import "core"
import "graphics"
import "input"
import "physics"

main :: proc() {
    core.InitContext()
    defer core.DestroyContext()

    context = core.GetDefaultContext()

    when ODIN_DEBUG {
        tracking_allocator: mem.Tracking_Allocator
        mem.tracking_allocator_init(&tracking_allocator, context.allocator)
        context.allocator = mem.tracking_allocator(&tracking_allocator)
        core.SetDefaultContext(context)
        defer if len(tracking_allocator.allocation_map) > 0 || len(tracking_allocator.bad_free_array) > 0 {
            fmt.println()
            for _, leak in tracking_allocator.allocation_map {
                fmt.printf("%v leaked %v bytes\n", leak.location, leak.size)
            }
            for bad_free in tracking_allocator.bad_free_array {
                fmt.printf("%v allocation %p was freed badly\n", bad_free.location, bad_free.memory)
            }
        }
    }

    L := core.InitLuaState()

    graphics.WindowLuaBind(L)
    graphics.RendererLuaBind(L)
    graphics.LayerLuaBind(L)
    graphics.SpriteLuaBind(L)
    graphics.DrawLuaBind(L)
    graphics.TextLuaBind(L)
    graphics.CameraLuaBind(L)
    defer {
        graphics.CameraLuaUnbind(L)
        graphics.TextLuaUnbind(L)
        graphics.DrawLuaUnbind(L)
        graphics.SpriteLuaUnbind(L)
        graphics.LayerLuaUnbind(L)
        graphics.RendererLuaUnbind(L)
        graphics.WindowLuaUnbind(L)
    }

    input.KeyboardLuaBind(L)
    input.MouseLuaBind(L)
    input.GamepadLuaBind(L)
    defer {
        input.GamepadLuaUnbind(L)
        input.MouseLuaUnbind(L)
        input.KeyboardLuaUnbind(L)
    }

    audio.AudioSystemLuaBind(L)
    audio.AudioChannelLuaBind(L)
    defer {
        audio.AudioChannelLuaUnbind(L)
        audio.AudioSystemLuaUnbind(L)
    }

    physics.PhysicsLuaBind(L)
    physics.PhysicsBodyLuaBind(L)
    defer {
        physics.PhysicsBodyLuaUnbind(L)
        physics.PhysicsLuaUnbind(L)
    }

    // registered last so Lua __gc runs before subsystem resources are torn down
    defer core.DestroyLuaState(L)

    if len(os.args) > 1 {
        log.debug("Running lua with argument:", os.args[1])
        core.LuaRun(L, os.args[1:])
    } else {
        log.debug("Running lua without arguments, defaulting to main.lua")
        core.LuaRun(L, []string{})
    }

    graphics.WindowMainLoop()
}
