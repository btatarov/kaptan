package audio

import "core:log"
import "core:strings"

import lua "vendor:lua/5.4"
import rl "vendor:raylib"

import "../core"

AudioChannelKind :: enum u32 {
    Sound,
    Music,
}

AudioSound :: struct {
    name:  string,
    sound: rl.Sound,
}

AudioMusic :: struct {
    name:  string,
    music: rl.Music,
}

AudioChannel :: struct {
    kind:     AudioChannelKind,
    sounds:   map[string]^AudioSound,
    music:    map[string]^AudioMusic,
    active:   string,
    refs:     int,
    volume:   f32,
    pan:      f32,
    pitch:    f32,
    looping:  bool,
    is_gone:  bool,

    update:   proc(channel: ^AudioChannel),
}

InitAudioChannel :: proc(channel: ^AudioChannel, kind: AudioChannelKind) {
    log.debugf("KaptanAudioChannel: Init")

    channel.kind    = kind
    channel.sounds  = make(map[string]^AudioSound)
    channel.music   = make(map[string]^AudioMusic)
    channel.refs    = 0
    channel.volume  = 1
    channel.pan     = 0.5
    channel.pitch   = 1
    channel.looping = false
    channel.is_gone = false
    channel.update  = audio_channel_update
}

DestroyAudioChannel :: proc(channel: ^AudioChannel) {
    if channel == nil {
        return
    }

    log.debugf("KaptanAudioChannel: Destroy")

    channel_clear(channel)
    delete(channel.sounds)
    delete(channel.music)
    channel.is_gone = true
    free(channel)
}

AudioChannelAddRef :: proc(channel: ^AudioChannel) {
    channel.refs += 1
}

AudioChannelReleaseRef :: proc(channel: ^AudioChannel) {
    channel.refs -= 1

    if channel.is_gone && channel.refs == 0 {
        DestroyAudioChannel(channel)
    }
}

AudioChannelFromLua :: proc "contextless" (L: ^lua.State, idx: i32) -> ^AudioChannel {
    return (^AudioChannel)(core.LuaUserdataHandle(L, idx, "KaptanAudioChannelMT"))
}

AudioChannelLuaBind :: proc(L: ^lua.State) {
    @static static_reg_table: []lua.L_Reg = {
        { "new", _new },
        { nil, nil },
    }

    @static instance_reg_table: []lua.L_Reg = {
        { "add",       _add },
        { "clear",     _clear },
        { "isPlaying", _is_playing },
        { "pause",     _pause },
        { "play",      _play },
        { "resume",    _resume },
        { "setLoop",   _set_loop },
        { "setPan",    _set_pan },
        { "setPitch",  _set_pitch },
        { "setVolume", _set_volume },
        { "stop",      _stop },
        { nil, nil },
    }

    constants := make(map[string]u32, allocator = context.temp_allocator)
    constants["SOUND"] = u32(AudioChannelKind.Sound)
    constants["MUSIC"] = u32(AudioChannelKind.Music)

    core.LuaBindClass(L, "KaptanAudioChannel", &static_reg_table, &instance_reg_table, &constants, __gc)
}

AudioChannelLuaUnbind :: proc(L: ^lua.State) {
    // nothing to do
}

@(private="file")
audio_channel_update :: proc(channel: ^AudioChannel) {
    if channel.is_gone || channel.kind != .Music || len(channel.active) == 0 {
        return
    }

    if channel.active not_in channel.music {
        return
    }

    item := channel.music[channel.active]
    if rl.IsMusicStreamPlaying(item.music) {
        rl.UpdateMusicStream(item.music)
    }
}

@(private="file")
channel_clear :: proc(channel: ^AudioChannel) {
    for _, item in channel.sounds {
        rl.StopSound(item.sound)
        rl.UnloadSound(item.sound)
        delete(item.name)
        free(item)
    }

    for _, item in channel.music {
        rl.StopMusicStream(item.music)
        rl.UnloadMusicStream(item.music)
        delete(item.name)
        free(item)
    }

    clear(&channel.sounds)
    clear(&channel.music)

    if len(channel.active) > 0 {
        delete(channel.active)
        channel.active = ""
    }
}

@(private="file")
channel_set_active :: proc(channel: ^AudioChannel, name: cstring) {
    if len(channel.active) > 0 {
        delete(channel.active)
    }

    channel.active = strings.clone(string(name))
}

@(private="file")
channel_unload_sound :: proc(channel: ^AudioChannel, name: string) {
    if name not_in channel.sounds {
        return
    }

    item := channel.sounds[name]
    rl.StopSound(item.sound)
    rl.UnloadSound(item.sound)
    delete_key(&channel.sounds, name)
    delete(item.name)
    free(item)
}

@(private="file")
channel_unload_music :: proc(channel: ^AudioChannel, name: string) {
    if name not_in channel.music {
        return
    }

    item := channel.music[name]
    rl.StopMusicStream(item.music)
    rl.UnloadMusicStream(item.music)
    delete_key(&channel.music, name)
    delete(item.name)
    free(item)
}

@(private="file")
channel_apply_sound_settings :: proc(channel: ^AudioChannel, sound: rl.Sound) {
    rl.SetSoundVolume(sound, channel.volume)
    rl.SetSoundPan(sound, channel.pan)
    rl.SetSoundPitch(sound, channel.pitch)
}

@(private="file")
channel_apply_music_settings :: proc(channel: ^AudioChannel, music: ^rl.Music) {
    music.looping = channel.looping
    rl.SetMusicVolume(music^, channel.volume)
    rl.SetMusicPan(music^, channel.pan)
    rl.SetMusicPitch(music^, channel.pitch)
}

@(private="file")
_new :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    kind := AudioChannelKind(lua.L_checkinteger(L, 1))
    if kind != .Sound && kind != .Music {
        return i32(lua.L_argerror(L, 1, "KaptanAudioChannel.SOUND or KaptanAudioChannel.MUSIC expected"))
    }

    handle := (^^AudioChannel)(lua.newuserdata(L, size_of(^AudioChannel)))
    channel := new(AudioChannel)
    InitAudioChannel(channel, kind)
    handle^ = channel

    core.LuaBindClassMetatable(L, "KaptanAudioChannel")

    return 1
}

@(private="file")
_add :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    AudioSystemRequireReady(L)

    channel := AudioChannelFromLua(L, 1)
    name := lua.L_checkstring(L, 2)
    path := lua.L_checkstring(L, 3)
    name_string := string(name)

    switch channel.kind {
    case .Sound:
        channel_unload_sound(channel, name_string)
        item := new(AudioSound)
        item.name = strings.clone(name_string)
        item.sound = rl.LoadSound(path)
        channel_apply_sound_settings(channel, item.sound)
        channel.sounds[item.name] = item
    case .Music:
        channel_unload_music(channel, name_string)
        item := new(AudioMusic)
        item.name = strings.clone(name_string)
        item.music = rl.LoadMusicStream(path)
        channel_apply_music_settings(channel, &item.music)
        channel.music[item.name] = item
    }

    return 0
}

@(private="file")
_clear :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    channel := AudioChannelFromLua(L, 1)
    channel_clear(channel)

    return 0
}

@(private="file")
_is_playing :: proc "c" (L: ^lua.State) -> i32 {
    channel := AudioChannelFromLua(L, 1)

    if len(channel.active) == 0 {
        lua.pushboolean(L, false)
        return 1
    }

    switch channel.kind {
    case .Sound:
        if channel.active in channel.sounds {
            lua.pushboolean(L, b32(rl.IsSoundPlaying(channel.sounds[channel.active].sound)))
            return 1
        }
    case .Music:
        if channel.active in channel.music {
            lua.pushboolean(L, b32(rl.IsMusicStreamPlaying(channel.music[channel.active].music)))
            return 1
        }
    }

    lua.pushboolean(L, false)
    return 1
}

@(private="file")
_pause :: proc "c" (L: ^lua.State) -> i32 {
    channel := AudioChannelFromLua(L, 1)

    if len(channel.active) == 0 {
        return 0
    }

    switch channel.kind {
    case .Sound:
        if channel.active in channel.sounds {
            rl.PauseSound(channel.sounds[channel.active].sound)
        }
    case .Music:
        if channel.active in channel.music {
            rl.PauseMusicStream(channel.music[channel.active].music)
        }
    }

    return 0
}

@(private="file")
_play :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    AudioSystemRequireReady(L)

    channel := AudioChannelFromLua(L, 1)
    name := lua.L_checkstring(L, 2)
    name_string := string(name)

    switch channel.kind {
    case .Sound:
        if name_string not_in channel.sounds {
            return i32(lua.L_argerror(L, 2, "unknown sound name"))
        }

        item := channel.sounds[name_string]
        channel_set_active(channel, name)
        channel_apply_sound_settings(channel, item.sound)
        rl.PlaySound(item.sound)
    case .Music:
        if name_string not_in channel.music {
            return i32(lua.L_argerror(L, 2, "unknown music name"))
        }

        item := channel.music[name_string]
        channel_set_active(channel, name)
        channel_apply_music_settings(channel, &item.music)
        rl.PlayMusicStream(item.music)
    }

    return 0
}

@(private="file")
_resume :: proc "c" (L: ^lua.State) -> i32 {
    channel := AudioChannelFromLua(L, 1)

    if len(channel.active) == 0 {
        return 0
    }

    switch channel.kind {
    case .Sound:
        if channel.active in channel.sounds {
            rl.ResumeSound(channel.sounds[channel.active].sound)
        }
    case .Music:
        if channel.active in channel.music {
            rl.ResumeMusicStream(channel.music[channel.active].music)
        }
    }

    return 0
}

@(private="file")
_set_loop :: proc "c" (L: ^lua.State) -> i32 {
    channel := AudioChannelFromLua(L, 1)

    if channel.kind != .Music {
        return i32(lua.L_error(L, "KaptanAudioChannel.setLoop is only supported for MUSIC channels"))
    }

    channel.looping = bool(lua.toboolean(L, 2))

    for _, item in channel.music {
        item.music.looping = channel.looping
    }

    return 0
}

@(private="file")
_set_pan :: proc "c" (L: ^lua.State) -> i32 {
    channel := AudioChannelFromLua(L, 1)
    channel.pan = f32(lua.L_checknumber(L, 2))

    for _, item in channel.sounds {
        rl.SetSoundPan(item.sound, channel.pan)
    }

    for _, item in channel.music {
        rl.SetMusicPan(item.music, channel.pan)
    }

    return 0
}

@(private="file")
_set_pitch :: proc "c" (L: ^lua.State) -> i32 {
    channel := AudioChannelFromLua(L, 1)
    channel.pitch = f32(lua.L_checknumber(L, 2))

    for _, item in channel.sounds {
        rl.SetSoundPitch(item.sound, channel.pitch)
    }

    for _, item in channel.music {
        rl.SetMusicPitch(item.music, channel.pitch)
    }

    return 0
}

@(private="file")
_set_volume :: proc "c" (L: ^lua.State) -> i32 {
    channel := AudioChannelFromLua(L, 1)
    channel.volume = f32(lua.L_checknumber(L, 2))

    for _, item in channel.sounds {
        rl.SetSoundVolume(item.sound, channel.volume)
    }

    for _, item in channel.music {
        rl.SetMusicVolume(item.music, channel.volume)
    }

    return 0
}

@(private="file")
_stop :: proc "c" (L: ^lua.State) -> i32 {
    channel := AudioChannelFromLua(L, 1)

    if len(channel.active) == 0 {
        return 0
    }

    switch channel.kind {
    case .Sound:
        if channel.active in channel.sounds {
            rl.StopSound(channel.sounds[channel.active].sound)
        }
    case .Music:
        if channel.active in channel.music {
            rl.StopMusicStream(channel.music[channel.active].music)
        }
    }

    return 0
}

@(private="file")
__gc :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    channel := AudioChannelFromLua(L, 1)

    if ! channel.is_gone {
        channel.is_gone = true

        if channel.refs == 0 {
            DestroyAudioChannel(channel)
        }
    }

    return 0
}
