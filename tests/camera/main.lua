KaptanWindow.open("Kaptan", 1024, 768)
KaptanWindow.setVsync(false)
KaptanWindow.setMaxFPS(640)

KaptanRenderer.setClearColor(32, 32, 32, 255)

local layer = KaptanLayer.new()
KaptanRenderer.add(layer)

local sprite = KaptanSprite.new('tests/sprites/kaptan1.png')
sprite:setPos(512 - 150 / 2, 384 - 100 / 2)
layer:add(sprite)

KaptanCamera.setPiv(512, 384)
KaptanCamera.setPos(512, 384)
KaptanCamera.setZoom(1.5)
KaptanCamera.setRot(30)
