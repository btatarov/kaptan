KaptanWindow.open("Kaptan", 1024, 768)
KaptanWindow.setVsync(false)
KaptanWindow.setMaxFPS(640)

KaptanRenderer.setClearColor(32, 32, 32, 255)

local layer = KaptanLayer.new()
KaptanRenderer.add(layer)

local sprites = {}
for i = 1, 3000 do
    if i % 2 == 0 then
        sprites[i] = KaptanSprite.new('tests/sprites/kaptan1.png')
    else
        sprites[i] = KaptanSprite.new('tests/sprites/kaptan2.png')
    end
    sprites[i]:setPos(math.random() * 1024 - 1024 / 2, math.random() * 768 - 768 / 2)
    sprites[i]:setRot(math.random() * 360 - 180)
    scl = math.random() * 0.9 + 0.1
    sprites[i]:setScl(scl, scl)
    layer:add(sprites[i])

    if i % 3 == 0 then
        sprites[i]:setVisible(false)
    end
end
