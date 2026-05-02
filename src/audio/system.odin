package audio

import "core:log"

import lua "vendor:lua/5.4"
import rl "vendor:raylib"

import "../core"

AudioSystem :: struct {
    initialized: bool,
    channels:    [dynamic]^AudioChannel,
}

@(private="file") audio_system: AudioSystem

AudioSystemLuaBind :: proc(L: ^lua.State) {
    @static reg_table: []lua.L_Reg = {
        { "add",             _add },
        { "clear",           _clear },
        { "destroy",         _destroy },
        { "getMasterVolume", _get_master_volume },
        { "init",            _init },
        { "isReady",         _is_ready },
        { "setMasterVolume", _set_master_volume },
        { nil, nil },
    }

    audio_system.channels = make([dynamic]^AudioChannel)
    core.LuaBindSingleton(L, "KaptanAudioSystem", &reg_table)
}

AudioSystemLuaUnbind :: proc(L: ^lua.State) {
    AudioSystemDestroy()
    delete(audio_system.channels)
}

AudioSystemInit :: proc() {
    if audio_system.initialized {
        return
    }

    log.debugf("KaptanAudioSystem: Init")

    rl.InitAudioDevice()
    audio_system.initialized = rl.IsAudioDeviceReady()
}

AudioSystemDestroy :: proc() {
    if ! audio_system.initialized {
        return
    }

    log.debugf("KaptanAudioSystem: Destroy")

    AudioSystemClear()
    rl.CloseAudioDevice()
    audio_system.initialized = false
}

AudioSystemClear :: proc() {
    for channel in audio_system.channels {
        AudioChannelReleaseRef(channel)
    }

    clear(&audio_system.channels)
}

AudioSystemUpdate :: proc() {
    if ! audio_system.initialized {
        return
    }

    remove_gone_channels()

    for channel in audio_system.channels {
        channel->update()
    }
}

AudioSystemRequireReady :: proc(L: ^lua.State) {
    if ! audio_system.initialized || ! rl.IsAudioDeviceReady() {
        lua.L_error(L, "KaptanAudioSystem.init() must be called before using audio")
    }
}

@(private="file")
remove_gone_channels :: proc() {
    write := 0
    for channel in audio_system.channels {
        if channel.is_gone {
            AudioChannelReleaseRef(channel)
            continue
        }

        audio_system.channels[write] = channel
        write += 1
    }

    resize(&audio_system.channels, write)
}

@(private="file")
_add :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    AudioSystemRequireReady(L)

    channel := AudioChannelFromLua(L, 1)

    for existing in audio_system.channels {
        if existing == channel {
            return 0
        }
    }

    AudioChannelAddRef(channel)
    append(&audio_system.channels, channel)

    return 0
}

@(private="file")
_clear :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    AudioSystemClear()

    return 0
}

@(private="file")
_destroy :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    AudioSystemDestroy()
    return 0
}

@(private="file")
_get_master_volume :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    AudioSystemRequireReady(L)

    lua.pushnumber(L, lua.Number(rl.GetMasterVolume()))
    return 1
}

@(private="file")
_init :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    AudioSystemInit()

    return 0
}

@(private="file")
_is_ready :: proc "c" (L: ^lua.State) -> i32 {
    lua.pushboolean(L, b32(audio_system.initialized && rl.IsAudioDeviceReady()))

    return 1
}

@(private="file")
_set_master_volume :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    AudioSystemRequireReady(L)

    rl.SetMasterVolume(f32(lua.L_checknumber(L, 1)))

    return 0
}
