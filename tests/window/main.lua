KaptanWindow.open("Kaptan", 1024, 768)
KaptanWindow.setVsync(false)
KaptanWindow.setMaxFPS(120)

KaptanRenderer.setClearColor(32, 32, 32, 255)

local layer = KaptanLayer.new()
KaptanRenderer.add(layer)

local frame = 0
KaptanWindow.setLoopCallback(function()
    print('KaptanWindow loop callback with delta:', KaptanWindow.getDeltaTime(), 'and FPS:', KaptanWindow.getFPS())
    frame = frame + 1
    if frame == 10 then
        KaptanWindow.clearLoopCallback()
    end
end)
