# Kaptan

Kaptan is a 2D game engine with Box2D physics and Lua scripting. Written in Odin using Raylib. Work in progress.

## Lua API

List of available functions:

### Window

* KaptanWindow.open(title, width, height)
* KaptanWindow.clearLoopCallback()
* KaptanWindow.getDeltaTime()
* KaptanWindow.getFPS()
* KaptanWindow.getHeight()
* KaptanWindow.getWidth()
* KaptanWindow.setLoopCallback(func)
* KaptanWindow.setMaxFPS(fps)
* KaptanWindow.setVsync(enabled)
* KaptanWindow.quit()

### Renderer

* KaptanRenderer.add(layer)
* KaptanRenderer.clear()
* KaptanRenderer.setClearColor(r, g, b, a)

### Camera

* KaptanCamera.getPiv()
* KaptanCamera.getPos()
* KaptanCamera.getRot()
* KaptanCamera.getZoom()
* KaptanCamera.setPiv(x, y)
* KaptanCamera.setPos(x, y)
* KaptanCamera.setRot(angle)
* KaptanCamera.setZoom(zoom)

### Layer

* layer = KaptanLayer.new()
* layer:isCamAttached()
* layer:isVisible()
* layer:setCamAttached(attached)
* layer:setVisible(visible)
* layer:add(sprite_or_shape_or_text)

### Sprite

* sprite = KaptanSprite.new(path)
* sprite:getPiv()
* sprite:getPos()
* sprite:getRot()
* sprite:getScl()
* sprite:getSize()
* sprite:isVisible()
* sprite:setColor(r, g, b, a)
* sprite:setPiv(x, y)
* sprite:setPos(x, y)
* sprite:setRot(angle)
* sprite:setScl(x, y)
* sprite:setVisible(visible)

### Text

* text = KaptanText.new(font_path, text, font_size)
* text:getPiv()
* text:getPos()
* text:getRot()
* text:getScl()
* text:getSize()
* text:isVisible()
* text:setColor(r, g, b, a)
* text:setPiv(x, y)
* text:setPos(x, y)
* text:setRot(angle)
* text:setScl(scale)
* text:setText(text)
* text:setVisible(visible)

### Draw

* shape = KaptanDraw.newPoint(x, y)
* shape = KaptanDraw.newLine(x1, y1, x2, y2)
* shape = KaptanDraw.newRect(x, y, width, height)
* shape = KaptanDraw.newCircle(x, y, radius)
* shape = KaptanDraw.newEllipse(x, y, radiusX, radiusY)
* shape = KaptanDraw.newPolygon(points)
* shape:getPiv()
* shape:getPos()
* shape:getRot()
* shape:getScl()
* shape:isVisible()
* shape:setBorderColor(r, g, b, a)
* shape:setBorderSize(size)
* shape:setColor(r, g, b, a)
* shape:setPiv(x, y)
* shape:setPos(x, y)
* shape:setRot(angle)
* shape:setScl(x, y)
* shape:setVisible(visible)

`KaptanDraw.newPolygon(points)` expects a flat point list: `{x1, y1, x2, y2, ...}`.
