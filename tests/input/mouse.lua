KaptanWindow.open('Kaptan', 1024, 768)
KaptanWindow.setVsync(true)

KaptanWindow.setLoopCallback(function()
    if KaptanMouse.isDown(KaptanMouse.BUTTON_LEFT) then
        local sx, sy = KaptanMouse.getScreenPos()
        local x, y = KaptanMouse.getPos()
        local wx, wy = KaptanMouse.getWorldPos()

        print('screen', sx, sy)
        print('gui', x, y)
        print('world', wx, wy)
    end
end)
