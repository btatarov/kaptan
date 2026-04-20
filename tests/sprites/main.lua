KaptanWindow.open("Kaptan", 1024, 768)
KaptanWindow.setVsync(false)
KaptanWindow.setMaxFPS(640)

KaptanRenderer.setClearColor(32, 32, 32, 255)

local layer = KaptanLayer.new()
KaptanRenderer.add(layer)

local sprites = {}
for i = 1, 10 do
    if i % 2 == 0 then
        sprites[i] = KaptanSprite.new('tests/sprites/kaptan1.png')
    else
        sprites[i] = KaptanSprite.new('tests/sprites/kaptan2.png')
    end
    -- sprites[i]:setPos(math.random() * (1024 - 200), math.random() * (768 - 200))
    layer:add(sprites[i])

    -- if i % 3 == 0 then
    --     sprites[i]:setVisible(false)
    -- end
end
