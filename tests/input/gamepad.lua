KaptanWindow.open('Kaptan', 1024, 768)
KaptanWindow.setVsync(true)

local pad = 1

KaptanWindow.setLoopCallback(function()
    if KaptanGamepad.isAvailable(pad) then
        local lx, ly = KaptanGamepad.getLeftStick(pad)

        if KaptanGamepad.isPressed(pad, KaptanGamepad.BUTTON_RIGHT_FACE_DOWN) then
            print('face down pressed', KaptanGamepad.getName(pad))
        end

        if math.abs(lx) > 0.2 or math.abs(ly) > 0.2 then
            print('left stick', lx, ly)
        end
    end

    if KaptanKeyboard.isDown(KaptanKeyboard.KEY_Q) then
        KaptanWindow.quit()
    end
end)
