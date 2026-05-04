package graphics

import lua "vendor:lua/5.4"

import "../core"

AnimationLoopMode :: enum u32 {
    Once,
    Loop,
    Ping_Pong,
}

AnimationLuaBind :: proc(L: ^lua.State) {
    @static reg_table: []lua.L_Reg = {
        { nil, nil },
    }

    constants := make(map[cstring]u32, allocator = context.temp_allocator)
    constants["ONCE"] = u32(AnimationLoopMode.Once)
    constants["LOOP"] = u32(AnimationLoopMode.Loop)
    constants["PING_PONG"] = u32(AnimationLoopMode.Ping_Pong)

    core.LuaBindSingletonWithConstants(L, "KaptanAnimation", &reg_table, &constants)
}

AnimationLuaUnbind :: proc(L: ^lua.State) {
    // nothing to do
}
