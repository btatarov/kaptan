KaptanWindow.open("Kaptan", 1024, 768)
KaptanWindow.setVsync(false)
KaptanWindow.setMaxFPS(120)

KaptanRenderer.setClearColor(76, 76, 76, 255)

layer = KaptanLayer.new()
KaptanRenderer.add(layer)

text = KaptanText.new('tests/text/unitblock.ttf', 'Hello, World!', 72)
text:setPos(0, -768 / 2 + 100)
layer:add(text)
