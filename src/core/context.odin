package core

import "base:runtime"

import "core:log"

@private default_logger: log.Logger
@private default_context: runtime.Context

InitContext :: proc() {
    default_context = runtime.default_context()

    when ODIN_DEBUG {
        log_level := log.Level.Debug
    } else {
        log_level := log.Level.Info
    }
    default_logger = log.create_console_logger(log_level)
    default_context.logger = default_logger
    context.logger = default_logger
}

DestroyContext :: proc() {
    log.destroy_console_logger(default_logger)
}

GetDefaultContext :: proc "contextless" () -> runtime.Context {
    return default_context
}

SetDefaultContext :: proc(ctx: runtime.Context) {
    default_context = ctx
    default_context.logger = default_logger
}
