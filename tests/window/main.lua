KaptanWindow.open("Kaptan", 1024, 768)
KaptanWindow.setVsync(false)
KaptanWindow.setMaxFPS(120)

local frame = 0
KaptanWindow.setLoopCallback(function()
    print('KaptanWindow loop callback with delta:', KaptanWindow.getDeltaTime(), 'and FPS:', KaptanWindow.getFPS())
    frame = frame + 1
    if frame == 10 then
        KaptanWindow.clearLoopCallback()
    end
end)
