package graphics

import "core:c"

import lua "vendor:lua/5.4"

import "../core"

AnimationLoopMode :: enum u32 {
    Once,
    Loop,
    Ping_Pong,
}

AnimationPlayback :: struct {
    time:      f32,
    duration:  f32,
    speed:     f32,
    direction: f32,
    playing:   bool,
    finished:  bool,
    loop_mode: AnimationLoopMode,
}

AnimationLuaBind :: proc(L: ^lua.State) {
    @static reg_table: []lua.L_Reg = {
        { nil, nil },
    }

    constants := make(map[cstring]u32, allocator = context.temp_allocator)
    constants["ONCE"] = u32(AnimationLoopMode.Once)
    constants["LOOP"] = u32(AnimationLoopMode.Loop)
    constants["PING_PONG"] = u32(AnimationLoopMode.Ping_Pong)

    core.LuaBindSingleton(L, "KaptanAnimation", &reg_table, &constants)
}

AnimationLuaUnbind :: proc(L: ^lua.State) {
    // nothing to do
}

AnimationLoopModeFromLua :: proc "contextless" (L: ^lua.State, idx: i32) -> AnimationLoopMode {
    mode := AnimationLoopMode(lua.L_checkinteger(L, idx))
    if mode < .Once || mode > .Ping_Pong {
        lua.L_argerror(L, c.int(idx), "KaptanAnimation.ONCE, KaptanAnimation.LOOP, or KaptanAnimation.PING_PONG expected")
    }

    return mode
}

AnimationPlaybackInit :: proc "contextless" (playback: ^AnimationPlayback) {
    playback.time = 0
    playback.duration = 0
    playback.speed = 1
    playback.direction = 1
    playback.playing = false
    playback.finished = false
    playback.loop_mode = .Once
}

AnimationPlaybackSetDuration :: proc "contextless" (playback: ^AnimationPlayback, duration: f32) {
    playback.duration = max(duration, 0)
    playback.time = clamp(playback.time, 0, playback.duration)
}

AnimationPlaybackPlay :: proc "contextless" (playback: ^AnimationPlayback) {
    if playback.duration <= 0 {
        return
    }

    if playback.finished {
        AnimationPlaybackRestart(playback)
        return
    }

    playback.playing = true
}

AnimationPlaybackPause :: proc "contextless" (playback: ^AnimationPlayback) {
    playback.playing = false
}

AnimationPlaybackStop :: proc "contextless" (playback: ^AnimationPlayback) {
    playback.time = 0
    playback.direction = 1
    playback.playing = false
    playback.finished = false
}

AnimationPlaybackRestart :: proc "contextless" (playback: ^AnimationPlayback) {
    playback.time = 0
    playback.direction = 1
    playback.playing = playback.duration > 0
    playback.finished = false
}

AnimationPlaybackSeek :: proc "contextless" (playback: ^AnimationPlayback, time: f32) {
    playback.time = clamp(time, 0, playback.duration)
    playback.finished = playback.loop_mode == .Once && playback.duration > 0 && playback.time >= playback.duration
}

AnimationPlaybackUpdate :: proc "contextless" (playback: ^AnimationPlayback, dt: f32) {
    if ! playback.playing || playback.finished || playback.duration <= 0 || playback.speed <= 0 || dt <= 0 {
        return
    }

    delta := dt * playback.speed
    switch playback.loop_mode {
    case .Once:
        playback.time += delta
        if playback.time >= playback.duration {
            playback.time = playback.duration
            playback.playing = false
            playback.finished = true
        }
    case .Loop:
        playback.time += delta
        for playback.time >= playback.duration {
            playback.time -= playback.duration
        }
    case .Ping_Pong:
        playback.time += delta * playback.direction
        for playback.time > playback.duration || playback.time < 0 {
            if playback.time > playback.duration {
                playback.time = playback.duration - (playback.time - playback.duration)
                playback.direction = -1
            } else if playback.time < 0 {
                playback.time = -playback.time
                playback.direction = 1
            }
        }
    }
}
