package graphics

import "core:log"

import lua "vendor:lua/5.4"

import "../core"

SpriteAnimationFrame :: struct {
    frame:    SpriteFrame,
    duration: f32,
}

SpriteAnimation :: struct {
    sprite:   ^Sprite,
    frames:   [dynamic]SpriteAnimationFrame,
    playback: AnimationPlayback,
}

SpriteAnimationLuaBind :: proc(L: ^lua.State) {
    @static static_reg_table: []lua.L_Reg = {
        { "new", _new },
        { nil, nil },
    }

    @static instance_reg_table: []lua.L_Reg = {
        { "addFrame",      _add_frame },
        { "clear",         _clear },
        { "getDuration",   _get_duration },
        { "getFrameIndex", _get_frame_index },
        { "getLoopMode",   _get_loop_mode },
        { "getSpeed",      _get_speed },
        { "getTime",       _get_time },
        { "isFinished",    _is_finished },
        { "isPlaying",     _is_playing },
        { "pause",         _pause },
        { "play",          _play },
        { "restart",       _restart },
        { "seek",          _seek },
        { "setFrameIndex", _set_frame_index },
        { "setLoopMode",   _set_loop_mode },
        { "setSpeed",      _set_speed },
        { "stop",          _stop },
        { "update",        _update },
        { nil, nil },
    }

    core.LuaBindClass(L, "KaptanSpriteAnimation", &static_reg_table, &instance_reg_table, __gc)
}

SpriteAnimationLuaUnbind :: proc(L: ^lua.State) {
    // nothing to do
}

SpriteAnimationFromLua :: proc "contextless" (L: ^lua.State, idx: i32) -> ^SpriteAnimation {
    return (^SpriteAnimation)(core.LuaUserdataHandle(L, idx, "KaptanSpriteAnimationMT"))
}

@(private="file")
init_sprite_animation :: proc(animation: ^SpriteAnimation, sprite: ^Sprite) {
    log.debugf("KaptanSpriteAnimation: Init")
    animation.sprite = sprite
    animation.frames = make([dynamic]SpriteAnimationFrame)
    AnimationPlaybackInit(&animation.playback)
    SpriteAddRef(sprite)
}

@(private="file")
destroy_sprite_animation :: proc(animation: ^SpriteAnimation) {
    if animation == nil {
        return
    }

    log.debugf("KaptanSpriteAnimation: Destroy")
    delete(animation.frames)
    if animation.sprite != nil {
        SpriteReleaseRef(animation.sprite)
        animation.sprite = nil
    }
    free(animation)
}

@(private="file")
sprite_animation_duration :: proc "contextless" (animation: ^SpriteAnimation) -> f32 {
    duration: f32
    for frame in animation.frames {
        duration += frame.duration
    }

    return duration
}

@(private="file")
sprite_animation_frame_index_at_time :: proc "contextless" (animation: ^SpriteAnimation, time: f32) -> int {
    if len(animation.frames) == 0 {
        return -1
    }

    elapsed: f32
    for frame, index in animation.frames {
        elapsed += frame.duration
        if time < elapsed || index == len(animation.frames) - 1 {
            return index
        }
    }

    return len(animation.frames) - 1
}

@(private="file")
sprite_animation_apply_frame :: proc "contextless" (animation: ^SpriteAnimation, index: int) {
    if animation.sprite == nil || animation.sprite.is_gone || index < 0 || index >= len(animation.frames) {
        return
    }

    SpriteSetFrame(animation.sprite, animation.frames[index].frame)
}

@(private="file")
sprite_animation_apply_time :: proc "contextless" (animation: ^SpriteAnimation) {
    sprite_animation_apply_frame(animation, sprite_animation_frame_index_at_time(animation, animation.playback.time))
}

@(private="file")
sprite_animation_recalculate_duration :: proc "contextless" (animation: ^SpriteAnimation) {
    AnimationPlaybackSetDuration(&animation.playback, sprite_animation_duration(animation))
}

@(private="file")
sprite_animation_set_frame_index :: proc "contextless" (animation: ^SpriteAnimation, index: int) {
    elapsed: f32
    for frame, frame_index in animation.frames {
        if frame_index == index {
            animation.playback.time = elapsed
            animation.playback.finished = false
            sprite_animation_apply_frame(animation, index)
            return
        }
        elapsed += frame.duration
    }
}

@(private="file")
_new :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    sprite := SpriteFromLua(L, 1)
    animation := new(SpriteAnimation)
    init_sprite_animation(animation, sprite)

    handle := (^^SpriteAnimation)(lua.newuserdata(L, size_of(^SpriteAnimation)))
    handle^ = animation
    core.LuaSetClassMetatable(L, "KaptanSpriteAnimation")

    return 1
}

@(private="file")
_add_frame :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    animation := SpriteAnimationFromLua(L, 1)
    frame := SpriteFrameFromLua(L, 2)
    duration := f32(lua.L_checknumber(L, 3))
    if duration <= 0 {
        return i32(lua.L_argerror(L, 3, "frame duration must be > 0"))
    }

    append(&animation.frames, SpriteAnimationFrame{frame = frame, duration = duration})
    sprite_animation_recalculate_duration(animation)
    if len(animation.frames) == 1 {
        sprite_animation_apply_frame(animation, 0)
    }

    return 0
}

@(private="file")
_clear :: proc "c" (L: ^lua.State) -> i32 {
    animation := SpriteAnimationFromLua(L, 1)
    clear(&animation.frames)
    AnimationPlaybackStop(&animation.playback)
    AnimationPlaybackSetDuration(&animation.playback, 0)

    return 0
}

@(private="file")
_get_duration :: proc "c" (L: ^lua.State) -> i32 {
    animation := SpriteAnimationFromLua(L, 1)
    lua.pushnumber(L, lua.Number(animation.playback.duration))

    return 1
}

@(private="file")
_get_frame_index :: proc "c" (L: ^lua.State) -> i32 {
    animation := SpriteAnimationFromLua(L, 1)
    index := sprite_animation_frame_index_at_time(animation, animation.playback.time)
    if index < 0 {
        lua.pushinteger(L, 0)
    } else {
        lua.pushinteger(L, lua.Integer(index + 1))
    }

    return 1
}

@(private="file")
_get_loop_mode :: proc "c" (L: ^lua.State) -> i32 {
    animation := SpriteAnimationFromLua(L, 1)
    lua.pushinteger(L, lua.Integer(animation.playback.loop_mode))

    return 1
}

@(private="file")
_get_speed :: proc "c" (L: ^lua.State) -> i32 {
    animation := SpriteAnimationFromLua(L, 1)
    lua.pushnumber(L, lua.Number(animation.playback.speed))

    return 1
}

@(private="file")
_get_time :: proc "c" (L: ^lua.State) -> i32 {
    animation := SpriteAnimationFromLua(L, 1)
    lua.pushnumber(L, lua.Number(animation.playback.time))

    return 1
}

@(private="file")
_is_finished :: proc "c" (L: ^lua.State) -> i32 {
    animation := SpriteAnimationFromLua(L, 1)
    lua.pushboolean(L, b32(animation.playback.finished))

    return 1
}

@(private="file")
_is_playing :: proc "c" (L: ^lua.State) -> i32 {
    animation := SpriteAnimationFromLua(L, 1)
    lua.pushboolean(L, b32(animation.playback.playing))

    return 1
}

@(private="file")
_pause :: proc "c" (L: ^lua.State) -> i32 {
    animation := SpriteAnimationFromLua(L, 1)
    AnimationPlaybackPause(&animation.playback)

    return 0
}

@(private="file")
_play :: proc "c" (L: ^lua.State) -> i32 {
    animation := SpriteAnimationFromLua(L, 1)
    AnimationPlaybackPlay(&animation.playback)

    return 0
}

@(private="file")
_restart :: proc "c" (L: ^lua.State) -> i32 {
    animation := SpriteAnimationFromLua(L, 1)
    AnimationPlaybackRestart(&animation.playback)
    sprite_animation_apply_time(animation)

    return 0
}

@(private="file")
_seek :: proc "c" (L: ^lua.State) -> i32 {
    animation := SpriteAnimationFromLua(L, 1)
    time := f32(lua.L_checknumber(L, 2))
    if time < 0 {
        return i32(lua.L_argerror(L, 2, "time must be >= 0"))
    }

    AnimationPlaybackSeek(&animation.playback, time)
    sprite_animation_apply_time(animation)

    return 0
}

@(private="file")
_set_frame_index :: proc "c" (L: ^lua.State) -> i32 {
    animation := SpriteAnimationFromLua(L, 1)
    index := int(lua.L_checkinteger(L, 2))
    if index < 1 || index > len(animation.frames) {
        return i32(lua.L_argerror(L, 2, "frame index out of range"))
    }

    sprite_animation_set_frame_index(animation, index - 1)

    return 0
}

@(private="file")
_set_loop_mode :: proc "c" (L: ^lua.State) -> i32 {
    animation := SpriteAnimationFromLua(L, 1)
    animation.playback.loop_mode = AnimationLoopModeFromLua(L, 2)
    animation.playback.finished = false

    return 0
}

@(private="file")
_set_speed :: proc "c" (L: ^lua.State) -> i32 {
    animation := SpriteAnimationFromLua(L, 1)
    speed := f32(lua.L_checknumber(L, 2))
    if speed < 0 {
        return i32(lua.L_argerror(L, 2, "speed must be >= 0"))
    }

    animation.playback.speed = speed

    return 0
}

@(private="file")
_stop :: proc "c" (L: ^lua.State) -> i32 {
    animation := SpriteAnimationFromLua(L, 1)
    AnimationPlaybackStop(&animation.playback)
    sprite_animation_apply_time(animation)

    return 0
}

@(private="file")
_update :: proc "c" (L: ^lua.State) -> i32 {
    animation := SpriteAnimationFromLua(L, 1)
    dt := f32(lua.L_checknumber(L, 2))
    if dt < 0 {
        return i32(lua.L_argerror(L, 2, "dt must be >= 0"))
    }

    AnimationPlaybackUpdate(&animation.playback, dt)
    sprite_animation_apply_time(animation)

    return 0
}

@(private="file")
__gc :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    animation := SpriteAnimationFromLua(L, 1)
    destroy_sprite_animation(animation)

    return 0
}
