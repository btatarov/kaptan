# Kaptan

Kaptan is a 2D game engine with Box2D physics and Lua scripting. Written in Odin using Raylib. Work in progress.

## Rendering Model

Kaptan uses a center-relative 2D rendering model. Object positions are not top-left screen coordinates. By default, `{0, 0}` means the center of the current render space.

For normal world layers, the render space is controlled by `KaptanCamera`. For GUI layers, the render space is the screen itself, but still center-relative.

Positive `x` moves right. Positive `y` moves down.

### Layers And Cameras

Layers are render containers. A layer can be attached to the camera or detached from it.

Camera-attached layers are the default:

```lua
world = KaptanLayer.new()
KaptanRenderer.add(world)

print(world:isCamAttached()) -- true
```

A camera-attached layer renders through `KaptanCamera`. Moving, rotating, or zooming the camera affects every sprite, shape, or text object in that layer.

Detached layers are useful for GUI and HUD rendering:

```lua
hud = KaptanLayer.new()
hud:setCamAttached(false)
KaptanRenderer.add(hud)
```

A detached layer ignores `KaptanCamera`. It uses a screen-space camera where `{0, 0}` is the screen center. This keeps HUD elements fixed on screen while the world camera moves.

Layer order is preserved. If you add a world layer first and a HUD layer second, the HUD renders on top:

```lua
world = KaptanLayer.new()
hud = KaptanLayer.new()
hud:setCamAttached(false)

KaptanRenderer.add(world)
KaptanRenderer.add(hud)
```

### Camera Coordinates

The default camera maps world `{0, 0}` to the screen center.

```lua
KaptanCamera.setPos(0, 0)
KaptanCamera.setPiv(0, 0)
KaptanCamera.setZoom(1)
KaptanCamera.setRot(0)
```

`KaptanCamera.setPos(x, y)` chooses the world point the camera looks at. With the default pivot, that world point appears at the screen center.

```lua
-- Put world point {300, 200} at the screen center.
KaptanCamera.setPos(300, 200)
```

`KaptanCamera.setPiv(x, y)` moves where the camera target appears on screen, relative to the screen center.

```lua
-- Keep the camera target 100 pixels to the right of screen center.
KaptanCamera.setPiv(100, 0)
```

`KaptanCamera.setZoom(zoom)` zooms camera-attached layers only. Detached GUI layers are not zoomed.

```lua
KaptanCamera.setZoom(2) -- world appears 2x larger, HUD stays unchanged
```

### Object Position

Sprites, shapes, and text all use `setPos` to place their transform position. For sprites and text, the default pivot is the object center, so `setPos(0, 0)` centers the object in the active render space.

```lua
sprite = KaptanSprite.new('tests/sprites/kaptan1.png')
sprite:setPos(0, 0) -- sprite center at world/screen center
world:add(sprite)
```

For a GUI layer, the same position means screen center and does not move with the camera:

```lua
hud = KaptanLayer.new()
hud:setCamAttached(false)
KaptanRenderer.add(hud)

label = KaptanText.new('tests/text/unitblock.ttf', 'Hello', 72)
label:setPos(0, 0) -- centered on screen
hud:add(label)
```

### Top-Left Placement

Because positions are center-relative, top-left placement uses half the screen dimensions and half the object dimensions.

For a sprite with size `{sprite_width, sprite_height}`, place its center so its top-left corner lands at screen top-left:

```lua
screen_width = KaptanWindow.getWidth()
screen_height = KaptanWindow.getHeight()
sprite_width, sprite_height = sprite:getSize()

sprite:setPos(
    -screen_width / 2 + sprite_width / 2,
    -screen_height / 2 + sprite_height / 2
)
```

For text, `getSize()` returns the measured unscaled text size:

```lua
screen_width = KaptanWindow.getWidth()
screen_height = KaptanWindow.getHeight()
text_width, text_height = label:getSize()

label:setPos(
    -screen_width / 2 + text_width / 2,
    -screen_height / 2 + text_height / 2
)
```

This works naturally for detached GUI layers because `{0, 0}` is the screen center. For camera-attached world layers, the same formula places the object relative to the camera's current view, not permanent world top-left.

### Pivot

The pivot controls where rotation and scaling happen from. The default pivot is `{0, 0}`, meaning the object center for sprites and text.

Center pivot:

```lua
sprite:setPiv(0, 0)
sprite:setRot(45) -- rotates around sprite center
sprite:setScl(1.5, 1.5) -- scales outward from sprite center
```

Top-left pivot for a sprite:

```lua
sprite_width, sprite_height = sprite:getSize()

sprite:setPiv(-sprite_width / 2, -sprite_height / 2)
sprite:setRot(45) -- rotates around sprite top-left
sprite:setScl(1.5, 1.5) -- top-left remains fixed while the sprite grows down/right
```

Top-left pivot for text:

```lua
text_width, text_height = label:getSize()

label:setPiv(-text_width / 2, -text_height / 2)
label:setRot(45)
label:setScl(1.5)
```

### Scaling

Sprite and draw-shape scaling uses two axes:

```lua
sprite:setScl(2, 1) -- twice as wide, same height
shape:setScl(1, 2) -- same width, twice as tall
```

Text scaling is currently uniform:

```lua
label:setScl(2) -- text appears 2x larger
```

Text rendering uses Raylib `DrawTextPro`, which supports uniform scale through font size and spacing. Non-uniform text scale would require rendering text to a texture and drawing it with `DrawTexturePro` later.

### Rotation

Rotation is in degrees. Positive rotation follows Raylib's 2D rotation direction.

```lua
sprite:setRot(30)
shape:setRot(30)
label:setRot(30)
```

Rotation happens around the pivot. Use `setPiv` before `setRot` when you need a corner or custom anchor point.

### World Plus HUD Example

This example renders a world sprite affected by the camera and a HUD label that stays fixed near the top of the screen.

```lua
KaptanWindow.open('Kaptan', 1024, 768)
KaptanRenderer.setClearColor(76, 76, 76, 255)

world = KaptanLayer.new()
hud = KaptanLayer.new()
hud:setCamAttached(false)

KaptanRenderer.add(world)
KaptanRenderer.add(hud)

player = KaptanSprite.new('tests/sprites/kaptan1.png')
player:setPos(0, 0)
world:add(player)

label = KaptanText.new('tests/text/unitblock.ttf', 'HP: 100', 32)
label:setPos(0, -KaptanWindow.getHeight() / 2 + 40)
hud:add(label)

KaptanCamera.setPos(200, 100)
KaptanCamera.setZoom(2)
```

The player is rendered in world space and moves relative to the camera. The label is rendered in screen space and remains fixed near the top center of the window.

## Garbage Collection And Ownership

Kaptan objects are split between Lua handles and Odin-owned render objects.

When Lua creates a layer, sprite, draw shape, or text object, Lua receives userdata that stores a handle to an Odin object. The Odin object owns the actual runtime state, GPU/cache references, transform data, and render behavior.

The important fields behind the scenes are `refs` and `is_gone`.

`refs` answers: who is keeping this Odin object alive?

`is_gone` answers: should this object still participate in rendering and owner lists?

These solve different problems. Ref counts prevent use-after-free while a layer or renderer still references an object. `is_gone` is a pending-removal flag that lets Lua garbage collection request removal from renderer/layer lists.

### Why `is_gone` Exists

Consider this example:

```lua
layer = KaptanLayer.new()
KaptanRenderer.add(layer)

sprite = KaptanSprite.new('tests/sprites/kaptan1.png')
layer:add(sprite)

sprite = nil
collectgarbage()
```

After `layer:add(sprite)`, the layer has a reference to the sprite. Internally, the sprite has `refs == 1` because the layer owns one render-list reference.

When `sprite = nil` and Lua collects the userdata, Lua no longer has a handle to the sprite. The sprite should disappear from the layer. But the layer still has a reference, so freeing the sprite immediately would be unsafe.

Instead, the sprite `__gc` marks it as gone:

```odin
__gc :: proc "c" (L: ^lua.State) -> i32 {
    sprite := SpriteFromLua(L, 1)

    if !sprite.is_gone {
        sprite.is_gone = true

        if sprite.refs == 0 {
            DestroySprite(sprite)
        }
    }

    return 0
}
```

On a later render cleanup, the layer sees the gone sprite and removes it from its item list:

```odin
for item in layer.items {
    if is_item_gone(item) {
        release_item(item)
        continue
    }

    keep_item(item)
}
```

Releasing the layer reference decrements `refs`. If `refs` reaches zero and the object is already gone, the object is destroyed.

Without `is_gone`, the layer reference would keep the sprite alive and visible even though Lua discarded it. Without `refs`, Lua GC could free the sprite while the layer still had a pointer to it.

The same rule applies to layers owned by the renderer:

```lua
layer = KaptanLayer.new()
KaptanRenderer.add(layer)

layer = nil
collectgarbage()
```

The renderer has a reference to the layer. Lua GC marks the layer as gone, and the renderer removes it during cleanup. When the renderer releases its reference, the layer can be destroyed.

### Ownership Flow

Creating an object gives Lua a handle:

```lua
sprite = KaptanSprite.new('tests/sprites/kaptan1.png')
text = KaptanText.new('tests/text/unitblock.ttf', 'Hello', 32)
shape = KaptanDraw.newCircle(0, 0, 20)
layer = KaptanLayer.new()
```

Adding an item to a layer gives the layer a reference:

```lua
layer:add(sprite)
layer:add(text)
layer:add(shape)
```

Adding a layer to the renderer gives the renderer a reference:

```lua
KaptanRenderer.add(layer)
```

Clearing a layer releases all item references held by that layer:

```lua
layer:clear()
```

Clearing the renderer releases all layer references held by the renderer:

```lua
KaptanRenderer.clear()
```

Setting a Lua variable to `nil` only removes the Lua handle. Actual destruction happens when Lua GC runs and all engine references have also been released.

### Best Practices

Keep Lua variables for objects you plan to update:

```lua
player = KaptanSprite.new('tests/sprites/kaptan1.png')
world:add(player)

function update_player(x, y)
    player:setPos(x, y)
end
```

Set a Lua variable to `nil` when you want Lua to stop owning that handle:

```lua
temporary_sprite = nil
collectgarbage()
```

Use `layer:clear()` when a scene, enemy group, particle group, or HUD layer should drop every item it owns:

```lua
world:clear()
```

Use `KaptanRenderer.clear()` when changing the whole render graph:

```lua
KaptanRenderer.clear()
```

Do not rely on exact Lua GC timing for gameplay rules. Lua GC may run later than the line where you set a variable to `nil`. If something must disappear immediately from a layer, use `layer:clear()` for that whole layer or keep the object invisible with `setVisible(false)` until a more specific remove API exists.

Avoid creating and discarding large numbers of objects every frame. For high-frequency effects such as damage numbers, prefer pooling reusable text objects:

```lua
damage = KaptanText.new('tests/text/unitblock.ttf', '', 28)
damage:setVisible(false)
hud:add(damage)

function show_damage(amount, x, y)
    damage:setText(tostring(amount))
    damage:setPos(x, y)
    damage:setVisible(true)
end
```

### Resource Caches

Sprites use a texture cache. Loading multiple sprites from the same path reuses the same cached texture resource.

Text uses a font cache. Loading multiple text objects with the same font path and font size reuses the same cached Raylib font resource.

When a sprite is destroyed, it releases its texture reference. When a text object is destroyed, it releases its font reference. Cached textures and fonts unload only when their cache reference count reaches zero.

This means these patterns are efficient:

```lua
enemy1 = KaptanSprite.new('tests/sprites/kaptan1.png')
enemy2 = KaptanSprite.new('tests/sprites/kaptan1.png')

label1 = KaptanText.new('tests/text/unitblock.ttf', '10', 28)
label2 = KaptanText.new('tests/text/unitblock.ttf', '25', 28)
```

Both sprites share one texture resource. Both text objects share one font resource because the font path and size match.

### Shutdown

Kaptan destroys the Lua state before tearing down renderer resources. This gives Lua `__gc` methods a chance to mark objects as gone before renderer, layer, texture, and font cleanup runs.

Renderer cleanup then releases remaining layer references. Layer cleanup releases remaining item references. Texture and font caches unload any resources that are still cached during final graphics teardown.

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
