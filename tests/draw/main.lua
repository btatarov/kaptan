KaptanWindow.open("Kaptan Draw", 1024, 768)
KaptanWindow.setVsync(false)
KaptanWindow.setMaxFPS(120)

KaptanRenderer.setClearColor(128, 128, 128, 255)

local layer = KaptanLayer.new()
KaptanRenderer.add(layer)

local point = KaptanDraw.newPoint(0, 0)
point:setPos(-380, -220)

local line = KaptanDraw.newLine(-80, 0, 80, 0)
line:setPos(-220, -220)
line:setRot(20)

local rect = KaptanDraw.newRect(-60, -40, 120, 80)
rect:setPos(-250, 0)
rect:setPiv(0, 0)
rect:setRot(20)
rect:setScl(1.25, 1.25)

local circle = KaptanDraw.newCircle(0, 0, 50)
circle:setPos(0, 0)

local ellipse = KaptanDraw.newEllipse(0, 0, 80, 40)
ellipse:setPos(250, 0)
ellipse:setRot(-25)

local polygon = KaptanDraw.newPolygon({-50, 50, 0, -50, 50, 50})
polygon:setPos(0, 180)
polygon:setRot(20)
polygon:setScl(1.5, 1.5)

local corner_pivot_rect = KaptanDraw.newRect(0, 0, 120, 80)
corner_pivot_rect:setPos(250, 200)
corner_pivot_rect:setPiv(0, 0)
corner_pivot_rect:setRot(30)
corner_pivot_rect:setScl(1.5, 1.5)

layer:add(point)
layer:add(line)
layer:add(rect)
layer:add(circle)
layer:add(ellipse)
layer:add(polygon)
layer:add(corner_pivot_rect)
