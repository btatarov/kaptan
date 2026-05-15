KaptanWindow.open("Kaptan Text Input", 1024, 768)
KaptanWindow.setVsync(false)
KaptanWindow.setMaxFPS(120)

KaptanRenderer.setClearColor(32, 34, 40, 255)

local layer = KaptanLayer.new()
layer:setCamAttached(false)
KaptanRenderer.add(layer)

local text = ''
local label = KaptanTextBox.new('tests/text/unitblock.ttf', 'Type text...', 32, 800, 300)
label:setPos(0, -100)
label:setAlignment(KaptanTextBox.ALIGN_CENTER)
layer:add(label)

KaptanWindow.setLoopCallback(function()
    local typed = KaptanKeyboard.getTextInput()
    if typed ~= '' then
        text = text .. typed
        label:setText(text)
    end

    if KaptanKeyboard.isPressed(KaptanKeyboard.KEY_BACKSPACE) and #text > 0 then
        text = text:sub(1, -2)
        if text == '' then
            label:setText('Type text...')
        else
            label:setText(text)
        end
    end
end)
