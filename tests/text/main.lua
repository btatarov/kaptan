KaptanWindow.open("Kaptan", 1024, 768)
KaptanWindow.setVsync(false)
KaptanWindow.setMaxFPS(120)

KaptanRenderer.setClearColor(76, 76, 76, 255)

local layer = KaptanLayer.new()
KaptanRenderer.add(layer)

local text = KaptanText.new('tests/text/unitblock.ttf', 'Hello, World!', 72)
local w, h = text:getSize()
text:setPos(0, -768 / 2 + 100)
text:setColor(200, 200, 200, 200)
text:setPiv(-w / 2, -h / 2)
text:setRot(30)
text:setScl(1.5)
layer:add(text)
