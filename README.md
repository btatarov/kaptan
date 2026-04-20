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
* KaptanLayer.add(sprite)

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
