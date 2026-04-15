package main

import "core:fmt"
import "core:mem"
import "core:os"

main :: proc() {
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
    } else {
        // HACK: avoid compile warnings
        m: mem.Allocator_Error; _ = m
        n: fmt.Info; _ = n
    }

    fmt.println("Running", os.args[1])
}
