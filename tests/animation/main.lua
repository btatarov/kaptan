local WINDOW_WIDTH = 1024
local WINDOW_HEIGHT = 768
local DURATION = 3.0

KaptanWindow.open('Kaptan', WINDOW_WIDTH, WINDOW_HEIGHT)
KaptanWindow.setVsync(true)
KaptanRenderer.setClearColor(77, 77, 77, 255)

local layer = KaptanLayer.new()
KaptanRenderer.add(layer)

local sprite = KaptanSprite.new('tests/sprites/kaptan1.png')
local sprite_width, sprite_height = sprite:getSize()
local y = -WINDOW_HEIGHT / 2 + sprite_height / 2 + 100
local left = -WINDOW_WIDTH / 2 + sprite_width / 2 + 10
local right = WINDOW_WIDTH / 2 - sprite_width / 2 - 10

sprite:setPos(left, y)
layer:add(sprite)

local x_curve = KaptanAnimationCurve.new()
x_curve:addKey(0, left, KaptanEase.OUT_BACK)
x_curve:addKey(DURATION, right)

local time = 0

KaptanWindow.setLoopCallback(function()
    time = time + KaptanWindow.getDeltaTime()
    if time > DURATION then
        time = time - DURATION
    end

    sprite:setPos(x_curve:sample(time), y)
end)
