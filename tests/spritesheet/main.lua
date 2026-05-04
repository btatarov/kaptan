local sprite_cache = {}

local function createSprite(path, name)
    local dir = path:match('(.*[/\\])')

    if not sprite_cache[path] then
        sprite_cache[path] = dofile(path)
    end

    local data = sprite_cache[path].sprites[name]

    local sprite = KaptanSprite.new(dir ..  sprite_cache[path].texture)
    sprite:setFrame(data)

    return sprite
end

KaptanWindow.open('Kaptan', 1024, 768)
KaptanWindow.setVsync(false)
KaptanWindow.setMaxFPS(120)

layer = KaptanLayer.new()
KaptanRenderer.add(layer)

local sprite1 = createSprite('tests/spritesheet/sheet.lua', 'kaptan1')
local w, h = sprite1:getSize()
sprite1:setPos(-1024 / 2 + w / 2 + 50, -768 / 2 + h / 2 + 50)
sprite1:setRot(30)
sprite1:setScl(1.5, 1.5)
layer:add(sprite1)

local sprite2 = createSprite('tests/spritesheet/sheet.lua', 'kaptan2')
local w, h = sprite2:getSize()
sprite2:setPiv(-w / 2, -h / 2)
sprite2:setRot(60)
sprite2:setScl(1.5, 1.5)
layer:add(sprite2)
