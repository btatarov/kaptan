KaptanWindow.open("Kaptan", 1024, 768)
KaptanWindow.setVsync(true)
KaptanWindow.setMaxFPS(60)

KaptanRenderer.setClearColor(32, 32, 32, 255)

local layer = KaptanLayer.new()
KaptanRenderer.add(layer)

local sprite = KaptanSprite.new('tests/sprites/kaptan1.png')
sprite:setPos(-437, -334)
layer:add(sprite)

KaptanCamera.setPiv(0, 0)
KaptanCamera.setPos(-437, -334)
KaptanCamera.setZoom(1.1)

local rot = 0
local frame = 0
KaptanWindow.setLoopCallback(function()
    frame = frame + 1
    if frame % 10 == 0 then
        rot = rot + 5
        KaptanCamera.setRot(rot)
    end
end)
