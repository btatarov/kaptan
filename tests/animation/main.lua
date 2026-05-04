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

local sprite2 = KaptanSprite.new('tests/sprites/kaptan1.png')
local sprite2_width, sprite2_height = sprite2:getSize()
local top_right_x = WINDOW_WIDTH / 2 - sprite2_width / 2 - 10
local top_right_y = -WINDOW_HEIGHT / 2 + sprite2_height / 2 + 250
local bottom_left_x = -WINDOW_WIDTH / 2 + sprite2_width / 2 + 10
local bottom_left_y = WINDOW_HEIGHT / 2 - sprite2_height / 2 - 10

sprite2:setPos(top_right_x, top_right_y)
layer:add(sprite2)

local pos_curve = KaptanVec2Curve.new()
pos_curve:addKey(0, top_right_x, top_right_y, KaptanEase.OUT_BACK)
pos_curve:addKey(DURATION, bottom_left_x, bottom_left_y)

local sprite3 = KaptanSprite.new('tests/sprites/kaptan1.png')
sprite3:setPos(0, 0)
layer:add(sprite3)

local rot_curve = KaptanAngleCurve.new()
rot_curve:setShortestPath(false)
rot_curve:addKey(0, 0, KaptanEase.OUT_BACK)
rot_curve:addKey(DURATION, 360)

local color_curve = KaptanColorCurve.new()
color_curve:addKey(0, 255, 255, 255, 255, KaptanEase.OUT_QUAD)
color_curve:addKey(DURATION * 0.33, 255, 80, 80, 210, KaptanEase.IN_OUT_SINE)
color_curve:addKey(DURATION * 0.66, 80, 180, 255, 180, KaptanEase.OUT_BACK)
color_curve:addKey(DURATION, 255, 255, 255, 255)

local sheet = dofile('tests/animation/crate-sheet.lua')
local sprite4 = KaptanSprite.new('tests/animation/' .. sheet.texture)
sprite4:setPos(WINDOW_WIDTH / 2 - 70, WINDOW_HEIGHT / 2 - 70)
layer:add(sprite4)

local sprite_anim = KaptanSpriteAnimation.new(sprite4)
sprite_anim:addFrame(sheet.sprites.crate1, 0.25)
sprite_anim:addFrame(sheet.sprites.crate2, 0.25)
sprite_anim:addFrame(sheet.sprites.crate3, 0.25)
sprite_anim:addFrame(sheet.sprites.crate4, 0.25)
sprite_anim:setLoopMode(KaptanAnimation.PING_PONG)
sprite_anim:play()

local time = 0

KaptanWindow.setLoopCallback(function()
    local dt = KaptanWindow.getDeltaTime()
    time = math.min(time + dt, DURATION)

    sprite:setPos(x_curve:sample(time), y)
    sprite2:setPos(pos_curve:sample(time))
    sprite3:setRot(rot_curve:sample(time))
    sprite3:setColor(color_curve:sample(time))
    sprite_anim:update(dt)
end)
