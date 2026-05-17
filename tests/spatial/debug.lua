local space = KaptanSpatial.new()

local point = space:addPoint(0, 0)
local circle = space:addCircle(100, 0, 20)
local rect = space:addRect(0, 100, 40, 40)
local ellipse = space:addEllipse(-100, 0, 30, 10)

point:setTag('point')
circle:setTag('circle')
rect:setTag('rect')
ellipse:setTag('ellipse')

print('point valid', point:isValid())
print('point tag', point:getTag())

print('aabb hits center', #space:queryAABB(0, 0, 10, 10))
print('circle hits right', #space:queryCircle(100, 0, 10))
print('ellipse hits left', #space:queryEllipse(-100, 0, 40, 12))

local nearest = space:nearest(90, 0)
print('nearest tag', nearest.item:getTag(), nearest.x, nearest.y)

point:setPos(200, 0)
print('aabb hits after move', #space:queryAABB(0, 0, 10, 10))

rect:setCircle(10)
rect:setPos(0, 0)
print('changed rect to circle', #space:queryCircle(0, 0, 5))

print('remove circle', circle:remove(), circle:isValid())
print('circle hits after remove', #space:queryCircle(100, 0, 50))

local other = KaptanSpatial.new()
print('remove from wrong space', other:remove(point))

space:clear()
print('valid after clear', point:isValid(), rect:isValid(), ellipse:isValid())
print('hits after clear', #space:queryAABB(0, 0, 1000, 1000))

local invalidQueryOk = pcall(function()
    space:queryCircle(0, 0, -1)
end)
print('invalid query rejected', not invalidQueryOk)
