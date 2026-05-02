KaptanWindow.open('Kaptan', 1024, 768)
KaptanWindow.setVsync(true)

KaptanAudioSystem.init()

local channels = {}
channels['music'] = KaptanAudioChannel.new(KaptanAudioChannel.MUSIC)
channels['voice'] = KaptanAudioChannel.new(KaptanAudioChannel.SOUND)
channels['sound'] = KaptanAudioChannel.new(KaptanAudioChannel.SOUND)

KaptanAudioSystem.add(channels['music'])
KaptanAudioSystem.add(channels['voice'])
KaptanAudioSystem.add(channels['sound'])

channels['music']:setVolume(0.6)
channels['voice']:setPan(-1.0)
channels['sound']:setPan(1.0)

channels['music']:add('music', 'tests/audio/music.ogg')
channels['voice']:add('voice', 'tests/audio/voice.wav')
channels['sound']:add('sound', 'tests/audio/sound.wav')

channels['voice']:play('voice')

frames = 0
KaptanWindow.setLoopCallback(function(delta)
    frames = frames + 1

    if frames == 30 then
        channels['music']:play('music')
        channels['music']:setLoop(true)
    end

    if frames % (60 * 4) == 0 then
        channels['sound']:play('sound')
    end
end)
