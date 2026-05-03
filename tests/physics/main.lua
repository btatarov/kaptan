math.randomseed(os.time())

local WINDOW_WIDTH = 1024
local WINDOW_HEIGHT = 768
local FLOOR_WIDTH = 1400
local FLOOR_HEIGHT = 70
local CRATE_SIZE = 30
local BALL_RADIUS = 15
local KICK_FRAME = 60 * 3

KaptanWindow.open('Kaptan', WINDOW_WIDTH, WINDOW_HEIGHT)
KaptanWindow.setVsync(true)
KaptanRenderer.setClearColor(77, 77, 77, 255)

local layer = KaptanLayer.new()
KaptanRenderer.add(layer)

KaptanPhysics.setUnitsPerMeter(100)
KaptanPhysics.setSubsteps(8)
KaptanPhysics.setTickRate(60)
KaptanPhysics.init()
KaptanPhysics.setGravity(0, 980.665)
KaptanPhysics.setDebugDraw(false)

local entities = {}
local dynamic_entities = {}
local scene = {
    layer = layer,
    entities = entities,
    dynamic_entities = dynamic_entities,
}

local function add_entity(body, shape, sprite, dynamic)
    local entity = {
        body = body,
        shape = shape,
        sprite = sprite,
    }

    entities[#entities + 1] = entity
    if dynamic then
        dynamic_entities[#dynamic_entities + 1] = entity
    end

    return entity
end

local floor_body = KaptanPhysicsBody.new(KaptanPhysicsBody.STATIC)
floor_body:setPos(0, WINDOW_HEIGHT / 2 - FLOOR_HEIGHT / 2)
local floor_shape = floor_body:addBox(FLOOR_WIDTH, FLOOR_HEIGHT)
floor_shape:setFriction(0.8)
floor_shape:setTag('floor')

local floor_sprite = KaptanSprite.new('tests/physics/floor.png')
floor_sprite:setPos(floor_body:getPos())
layer:add(floor_sprite)
add_entity(floor_body, floor_shape, floor_sprite, false)

for i = 1, 15 do
    for j = 1, 12 do
        local x = -WINDOW_WIDTH / 2 + 50 + 65 * (i - 1)
        local y = -WINDOW_HEIGHT / 2 + 50 + 55 * (j - 1)
        local pick = math.random(1, 2)

        local body = KaptanPhysicsBody.new(KaptanPhysicsBody.DYNAMIC)
        body:setPos(x, y)
        body:setRot(math.random() * 360)
        body:setLinearDamping(0.01)
        body:setAngularDamping(0.01)

        local sprite
        local shape
        if pick == 1 then
            shape = body:addBox(CRATE_SIZE, CRATE_SIZE)
            shape:setTag('crate')
            sprite = KaptanSprite.new('tests/physics/crate.png')
        else
            shape = body:addCircle(BALL_RADIUS)
            shape:setTag('ball')
            sprite = KaptanSprite.new('tests/physics/ball.png')
        end

        shape:setFriction(0.6)
        shape:setRestitution(0.5)

        sprite:setPos(body:getPos())
        sprite:setRot(body:getRot())
        layer:add(sprite)
        add_entity(body, shape, sprite, true)
    end
end

local frames = 0
KaptanWindow.setLoopCallback(function()
    if KaptanKeyboard.isPressed(KaptanKeyboard.KEY_ESCAPE) then
        KaptanWindow.quit()
        return
    end

    if KaptanKeyboard.isPressed(KaptanKeyboard.KEY_F1) then
        KaptanPhysics.setDebugDraw(not KaptanPhysics.isDebugDraw())
    end

    for _, entity in ipairs(scene.entities) do
        entity.sprite:setPos(entity.body:getPos())
        entity.sprite:setRot(entity.body:getRot())
    end

    frames = frames + 1
    if frames == KICK_FRAME then
        for _ = 1, 10 do
            local entity = scene.dynamic_entities[math.random(1, #scene.dynamic_entities)]
            entity.body:setVelocity(math.random(-10, 10) * 1000, math.random(-10, 10) * 1000)
            entity.body:setAngularVelocity(math.random(-10, 10) * 10)
        end
    end

    KaptanPhysics.getContactEvents()
    KaptanPhysics.getSensorEvents()
end)
