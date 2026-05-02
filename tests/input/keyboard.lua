KaptanWindow.open("Kaptan", 1024, 768)
KaptanWindow.setVsync(true)

KaptanWindow.setLoopCallback(function()
    if KaptanKeyboard.isDown(KaptanKeyboard.KEY_Q) then
        KaptanWindow.quit()
    end
end)
