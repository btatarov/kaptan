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

* KaptanLayer.new()
* KaptanLayer.isVisible()
* KaptanLayer.setVisible(visible)
* KaptanLayer.add(sprite_or_shape)

### Sprite

* KaptanSprite.new(path)
* KaptanSprite.getPiv()
* KaptanSprite.getPos()
* KaptanSprite.getRot()
* KaptanSprite.getScl()
* KaptanSprite.getSize()
* KaptanSprite.isVisible()
* KaptanSprite.setPiv(x, y)
* KaptanSprite.setPos(x, y)
* KaptanSprite.setRot(angle)
* KaptanSprite.setScl(x, y)
* KaptanSprite.setVisible(visible)

### Draw

* KaptanDraw.newPoint(x, y)
* KaptanDraw.newLine(x1, y1, x2, y2)
* KaptanDraw.newRect(x, y, width, height)
* KaptanDraw.newCircle(x, y, radius)
* KaptanDraw.newEllipse(x, y, radiusX, radiusY)
* KaptanDraw.newPolygon(points)
* KaptanDraw.getPiv()
* KaptanDraw.getPos()
* KaptanDraw.getRot()
* KaptanDraw.getScl()
* KaptanDraw.isVisible()
* KaptanDraw.setPiv(x, y)
* KaptanDraw.setPos(x, y)
* KaptanDraw.setRot(angle)
* KaptanDraw.setScl(x, y)
* KaptanDraw.setVisible(visible)

`KaptanDraw.newPolygon(points)` expects a flat point list: `{x1, y1, x2, y2, ...}`.
