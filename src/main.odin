package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"

import rl "vendor:raylib"

import "core"

main :: proc() {
    core.InitContext()
    defer core.DestroyContext()

    context = core.GetDefaultContext()

    when ODIN_DEBUG {
        tracking_allocator: mem.Tracking_Allocator
        mem.tracking_allocator_init(&tracking_allocator, context.allocator)
        context.allocator = mem.tracking_allocator(&tracking_allocator)
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
    defer core.DestroyLuaState(L)

    if len(os.args) > 1 {
        log.debug("Running lua with argument:", os.args[1])
        core.LuaRun(L, os.args[1:])
    } else {
        log.debug("Running lua without arguments, defaulting to main.lua")
        core.LuaRun(L, []string{})
    }

    rl.InitWindow(1024, 768, "Kaptan")
    defer rl.CloseWindow()

    default_text: cstring
    if len(os.args) > 1 {
        default_text = fmt.caprintf("Running %v", os.args[1])
    } else {
        default_text = fmt.caprintf("Running main.lua")
    }
    defer delete(default_text)

    for ! rl.WindowShouldClose() {
        rl.BeginDrawing()

        rl.ClearBackground(rl.RAYWHITE)
        rl.DrawText(default_text, 10, 10, 20, rl.MAROON)

        rl.EndDrawing()
    }
}
