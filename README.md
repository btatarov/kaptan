# Kaptan

Kaptan is a 2D game engine with Box2D physics and Lua scripting. Written in Odin using Raylib. Work in progress.

## Quick Start

Run the default non-window smoke script:

```sh
./build.sh
```

Run a simple window scenario:

```sh
./build.sh debug tests/window/main.lua
```

`tests/main.lua` is the safest smoke test because it does not open a window. Most other scenarios under `tests/` open a Raylib window and are intended for manual checks.

## Rendering Model

Kaptan uses a center-relative 2D rendering model. Object positions are not top-left screen coordinates. By default, `{0, 0}` means the center of the current render space.

For normal world layers, the render space is controlled by `KaptanCamera`. For GUI layers, the render space is the screen itself, but still center-relative.

Positive `x` moves right. Positive `y` moves down.

### Layers And Camera Attachment

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
KaptanCamera.setPos(300, 200) -- put world point {300, 200} at the screen center
```

`KaptanCamera.setPiv(x, y)` moves where the camera target appears on screen, relative to the screen center.

```lua
KaptanCamera.setPiv(100, 0) -- keep the camera target 100 pixels to the right of screen center
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

### Sprite Atlases

Sprites can render a trimmed source rectangle from a larger texture atlas while keeping logical frame size and pivot behavior from the original untrimmed sprite.

Kaptan includes a TexturePacker custom exporter in `extra/TexturePacker/kaptan`. See the TexturePacker custom exporter documentation for installation and usage details: <https://www.codeandweb.com/texturepacker/documentation/custom-exporter>.

The included exporter emits a `.lua` file using the format below and disables rotated sprites because atlas rotation is not currently supported by Kaptan's sprite renderer.

A Lua spritesheet can keep all metadata in pixels:

```lua
return {
    texture = 'sheet.png',
    sprites = {
        kaptan1 = {
            source = { x = 2, y = 2, w = 150, h = 100 },
            frame = { w = 160, h = 110 },
            offset = { x = 5, y = 5 },
        },
    }
}
```

- `source` is the pixel rectangle sampled from the atlas texture.
- `frame` is the original untrimmed logical sprite size.
- `offset` is where the trimmed visible pixels start inside the untrimmed frame, measured from the frame top-left.

Use the metadata when constructing a sprite:

```lua
local sheet = dofile('tests/spritesheet/sheet.lua')
local data = sheet.sprites.kaptan1

local sprite = KaptanSprite.new('tests/spritesheet/' .. sheet.texture)
sprite:setFrame(data)
```

`sprite:getSize()` returns the logical frame size, not the trimmed source size. This keeps placement and pivot formulas consistent:

```lua
local w, h = sprite:getSize()
sprite:setPiv(-w / 2, -h / 2) -- logical frame top-left
```

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

## Object Lifetime And Ownership

Kaptan objects are split between Lua handles and Odin-owned runtime objects.

When Lua creates a layer, sprite, draw shape, or text object, Lua receives userdata that stores a handle to an Odin object. The Odin object owns the actual runtime state, GPU/cache references, transform data, and render behavior.

Engine containers can also hold references. A layer keeps references to sprites, shapes, and text objects added with `layer:add(...)`. The renderer keeps references to layers added with `KaptanRenderer.add(layer)`. The audio system keeps references to channels added with `KaptanAudioSystem.add(channel)`.

The important fields behind the scenes are `refs` and `is_gone`.

`refs` tracks engine references that are keeping an Odin object alive. `is_gone` marks an object for removal from render lists after Lua has dropped its handle.

These solve different problems. Ref counts prevent use-after-free while a layer, renderer, or audio system still references an object. The gone flag lets Lua garbage collection request removal from engine lists without freeing an object that is still referenced by the engine.

### Lua Handles And Engine References

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

Instead, Lua garbage collection marks the sprite as gone. On a later render cleanup, the layer removes gone items from its list and releases its references. If `refs` reaches zero and the object is already gone, the object is destroyed.

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

Adding an item to a layer gives the layer a reference. Layers do not accept duplicate references to the same object. `layer:add(...)` returns `true` when it adds a new object and `false` when the object is already in that layer.

```lua
layer:add(sprite)
layer:add(text)
layer:add(shape)
```

Removing an item releases the layer's reference without destroying a Lua-owned object. `layer:remove(...)` returns `true` when it removes an object and `false` when the object was not in that layer.

```lua
layer:remove(sprite)
```

Adding a layer to the renderer gives the renderer a reference. The renderer does not accept duplicate references to the same layer. `KaptanRenderer.add(layer)` returns `true` when it adds a new layer and `false` when the layer is already registered.

```lua
KaptanRenderer.add(layer)
```

Removing a layer releases the renderer's reference without destroying a Lua-owned layer. `KaptanRenderer.remove(layer)` returns `true` when it removes a layer and `false` when the layer was not registered.

```lua
KaptanRenderer.remove(layer)
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

Do not rely on exact Lua GC timing for gameplay rules. Lua GC may run later than the line where you set a variable to `nil`. If something must disappear immediately from a layer, use `layer:remove(object)`, `layer:clear()` for that whole layer, or keep the object invisible with `setVisible(false)`.

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

## Audio System

Audio initialization is explicit. Call `KaptanAudioSystem.init()` before loading or playing audio.

```lua
KaptanAudioSystem.init()
```

Kaptan does not initialize audio automatically because not every script needs an audio device. This keeps non-audio scripts and smoke tests usable in environments where audio may not be available.

Cleanup is automatic on shutdown if audio was initialized, but you can call `KaptanAudioSystem.destroy()` manually when entering a mode that no longer needs audio:

```lua
KaptanAudioSystem.destroy()
```

### Sound And Music

Kaptan has two channel kinds:

`KaptanAudioChannel.SOUND` loads files into memory with Raylib `Sound`. Use it for short effects like hits, jumps, pickups, UI clicks, and weapon sounds.

`KaptanAudioChannel.MUSIC` streams from disk with Raylib `Music`. Use it for longer background music or ambience.

```lua
local sfx = KaptanAudioChannel.new(KaptanAudioChannel.SOUND)
local music = KaptanAudioChannel.new(KaptanAudioChannel.MUSIC)
```

### Loading And Playback

Audio channels store named resources. Load a resource once with `channel:add(name, path)`, then play it by name.

```lua
local sfx = KaptanAudioChannel.new(KaptanAudioChannel.SOUND)
sfx:add('hit', 'tests/audio/hit.wav')
KaptanAudioSystem.add(sfx)

if KaptanKeyboard.isPressed(KaptanKeyboard.KEY_SPACE) then
    sfx:play('hit')
end
```

For music, create a music channel, load a streamed file, optionally enable looping, register it with the audio system, then play it:

```lua
local music = KaptanAudioChannel.new(KaptanAudioChannel.MUSIC)
music:add('theme', 'tests/audio/theme.ogg')
music:setLoop(true)
KaptanAudioSystem.add(music)

music:play('theme')
```

`channel:pause()`, `channel:resume()`, `channel:stop()`, and `channel:isPlaying()` operate on the channel's active resource. The active resource is set by the most recent `channel:play(name)` call.

### System Registration

`KaptanAudioSystem.add(channel)` registers a channel with the audio system. The audio system does not accept duplicate references to the same channel. `KaptanAudioSystem.add(channel)` returns `true` when it registers a new channel and `false` when the channel is already registered.

Registered channels are kept alive by the system and released by `KaptanAudioSystem.remove(channel)`, `KaptanAudioSystem.clear()`, or `KaptanAudioSystem.destroy()`. Removing a channel releases the system's reference without destroying a Lua-owned channel. `KaptanAudioSystem.remove(channel)` returns `true` when it removes a channel and `false` when the channel was not registered.

Music channels registered with the audio system are updated automatically once per frame. This is required by Raylib streamed music playback.

```lua
KaptanAudioSystem.add(music)
```

If you do not add a music channel to the audio system, its stream will not be updated automatically.

### Volume, Pan, Pitch, And Looping

Volume, pan, and pitch are channel-wide settings. They are applied to loaded resources and reused when a named resource is played.

```lua
sfx:setVolume(0.75)
sfx:setPan(0.5)
sfx:setPitch(1.0)
```

`channel:setLoop(loop)` is only valid for music channels. Calling it on a sound channel raises a Lua error.

```lua
music:setLoop(true)
```

### Audio Best Practices

Load audio once, then play by name. Avoid loading files every time an effect plays.

Use a few sound channels for categories such as combat, UI, and ambience. Use music channels for streamed tracks.

Register music channels with `KaptanAudioSystem.add(channel)` so streaming updates happen automatically.

Use `KaptanAudioSystem.remove(channel)` when one channel should stop being owned and updated by the audio system.

Use `KaptanAudioSystem.clear()` to release all registered channels when changing scenes or resetting audio state:

```lua
KaptanAudioSystem.clear()
```

## Physics System

Physics initialization is explicit. Call `KaptanPhysics.init()` before creating or updating physics objects.

```lua
KaptanPhysics.init()
```

Physics uses the same world coordinate model as rendering. Positive `x` moves right, positive `y` moves down, and `{0, 0}` is the world center. A physics body position can be copied directly to a sprite on a camera-attached layer.

Physics is updated automatically by Kaptan while the window loop is running. It uses a fixed timestep with a default tick rate of 60 Hz, so physics stays stable when rendering frame time varies.

Use `KaptanPhysics.step(dt)` only for scripts that do not open a window, such as smoke tests or offline simulations. Do not call it inside `KaptanWindow.setLoopCallback`, because the window loop already steps physics automatically.

```lua
KaptanPhysics.setGravity(0, 0)
KaptanPhysics.setSubsteps(2)
KaptanPhysics.setTickRate(60)
```

`KaptanPhysics.setUnitsPerMeter(value)` configures Box2D's length scale. It must be called before `KaptanPhysics.init()`. The default is `64` Kaptan units per meter.

Use `KaptanPhysics.clear()` to reset the world while keeping physics initialized. Use `KaptanPhysics.destroy()` when physics is no longer needed.

Create bodies with `KaptanPhysicsBody.new(kind)`. Body kinds are `KaptanPhysicsBody.STATIC`, `KaptanPhysicsBody.KINEMATIC`, and `KaptanPhysicsBody.DYNAMIC`.

```lua
local enemy_body = KaptanPhysicsBody.new(KaptanPhysicsBody.DYNAMIC)
print(enemy_body:isValid())
```

`body:destroy()` explicitly removes the body from the physics world. `KaptanPhysics.clear()` and `KaptanPhysics.destroy()` invalidate all existing body handles, so `body:isValid()` returns `false` after the world is cleared or destroyed.

Body positions use Kaptan world coordinates. Rotation is exposed in degrees, matching sprites, text, draw shapes, and the camera. Linear velocity uses Kaptan units per second.

Use forces and impulses to move dynamic bodies through the physics simulation. `applyForce` and `applyImpulse` act at the body's center, while `applyTorque` and `applyAngularImpulse` rotate it.

```lua
enemy_body:setPos(0, 0)
enemy_body:setVelocity(120, 0)
enemy_body:applyImpulse(300, 0)
enemy_body:setFixedRotation(true)

local x, y = enemy_body:getPos()
enemy_sprite:setPos(x, y)
```

Add shapes to bodies to make them collide. Shape creation supports circles, boxes, rounded boxes, capsules, and convex polygons.

```lua
local enemy_shape = enemy_body:addCircle(16)
local wall_shape = wall_body:addBox(200, 32)
local rounded_wall_shape = wall_body:addBox(200, 32, 6)
local capsule_shape = enemy_body:addCapsule(24, 48, 12)
local triangle_shape = enemy_body:addPolygon({ -12, -8, 12, -8, 0, 14 })
```

Polygons must be convex and use at most 8 points. `addPolygon` accepts a flat `{ x1, y1, x2, y2, ... }` table in body-local coordinates.

Pass an options table when creating a shape to make it a sensor or enable event collection:

```lua
local pickup_sensor = pickup_body:addCircle(24, {
    sensor = true,
    sensorEvents = true,
})
```

Sensors are creation-time behavior in Box2D. Use `shape:isSensor()` to inspect a shape, and create a new shape if you need to switch between solid and sensor behavior.

Poll contact and sensor events after physics updates. During the automatic window loop, Kaptan keeps the latest update's accumulated events, including all fixed physics ticks that ran during that update. Unpolled automatic events are discarded when the next automatic physics update begins, so event buffers stay bounded. Manual `KaptanPhysics.step(dt)` calls accumulate events until you call `getContactEvents()` or `getSensorEvents()`. Contact events require `contactEvents = true` on at least one participating shape. Sensor events require a sensor shape with `sensorEvents = true`.

```lua
for _, event in ipairs(KaptanPhysics.getContactEvents()) do
    if event.kind == "begin" then
        print("contact", event.shapeA, event.shapeB)
    end
end

for _, event in ipairs(KaptanPhysics.getSensorEvents()) do
    if event.kind == "begin" then
        print("sensor", event.sensor, event.visitor)
    end
end
```

Event shape fields can be `nil` for end events if Box2D reports a shape that was already destroyed. Check fields before using them.

Use queries to find shapes without changing the simulation:

```lua
local hits = KaptanPhysics.queryAABB(0, 0, 128, 128, {
    mask = CATEGORY_ENEMY,
})

local hit = KaptanPhysics.raycast(0, 0, 400, 0, {
    mask = CATEGORY_WALL,
})

if hit then
    print(hit.shape, hit.x, hit.y, hit.normalX, hit.normalY, hit.fraction)
end
```

`queryAABB(x, y, width, height, options)` treats `x, y` as the center of the query box. Query options support `category` and `mask` bits. `raycast` returns the closest hit or `nil`.

Use tags to attach game-defined labels to bodies and shapes. Tags have no engine-defined meaning; they are just strings you can read from event/query results.

```lua
enemy_body:setTag("enemy")
enemy_shape:setTag("enemy_hitbox")

local hit = KaptanPhysics.raycast(0, 0, 400, 0)
if hit and hit.shape:getTag() == "enemy_hitbox" then
    print("hit enemy")
end
```

Enable debug drawing in debug builds to render physics shapes as a world-space overlay after normal layers. It uses the main camera and does not require a `KaptanLayer`.

```lua
KaptanPhysics.setDebugDraw(true)
```

Debug draw is intended for development diagnostics, not game visuals. It only appears while a window is open.

Use category and mask bits to control which shapes collide or appear in queries:

```lua
local CATEGORY_PLAYER = 1 << 0
local CATEGORY_ENEMY = 1 << 1
local CATEGORY_WALL = 1 << 2

enemy_shape:setCategory(CATEGORY_ENEMY)
enemy_shape:setMask(CATEGORY_PLAYER | CATEGORY_WALL)
```

Kaptan does not define game-specific category constants. Define category bits in Lua for each game.

`shape:destroy()` removes one shape from its body. `body:destroy()`, `KaptanPhysics.clear()`, and `KaptanPhysics.destroy()` invalidate all shapes attached to destroyed bodies.

## Input System

Kaptan exposes input through singleton globals. Input is polled from Lua, usually inside `KaptanWindow.setLoopCallback`.

Supported devices are keyboard, mouse, and gamepad.

### Keyboard Input

Keyboard constants are exposed as `KaptanKeyboard.KEY_*`.

`KaptanKeyboard.isDown(key)` is true while a key is held. `KaptanKeyboard.isPressed(key)` is true only on the frame where the key transitions from up to down. `KaptanKeyboard.isReleased(key)` is true only on the release frame. `KaptanKeyboard.isUp(key)` is true while the key is not held.

`KaptanKeyboard.getKeysDown()` returns an array of currently held key codes.

```lua
KaptanWindow.setLoopCallback(function()
    if KaptanKeyboard.isPressed(KaptanKeyboard.KEY_SPACE) then
        print('jump')
    end

    if KaptanKeyboard.isDown(KaptanKeyboard.KEY_Q) then
        KaptanWindow.quit()
    end
end)
```

### Mouse Input

Mouse button constants are exposed as `KaptanMouse.BUTTON_*`.

`KaptanMouse.getScreenPos()` returns raw top-left window coordinates. This matches Raylib screen coordinates.

`KaptanMouse.getPos()` returns center-relative screen coordinates. Use it for GUI or HUD elements on layers with `layer:setCamAttached(false)`.

`KaptanMouse.getWorldPos()` converts the current mouse position through `KaptanCamera`. Use it for picking or placing objects in camera-attached world layers.

`KaptanMouse.getDelta()` returns mouse movement since the last frame. `KaptanMouse.getWheel()` returns vertical wheel movement. `KaptanMouse.getWheelV()` returns horizontal and vertical wheel movement.

```lua
if KaptanMouse.isPressed(KaptanMouse.BUTTON_LEFT) then
    local x, y = KaptanMouse.getWorldPos()
    print('clicked world position', x, y)
end
```

```lua
local x, y = KaptanMouse.getPos()
cursor_label:setPos(x, y)
```

### Gamepad Input

Gamepad indices are Lua-style: `1` is the first connected gamepad. Internally, Kaptan converts this to Raylib's zero-based gamepad index.

PS and Xbox controllers use Raylib's generic gamepad layout. Button constants are exposed as `KaptanGamepad.BUTTON_*`. Axis constants are exposed as `KaptanGamepad.AXIS_*`.

Use `KaptanGamepad.getLeftStick(gamepad)`, `KaptanGamepad.getRightStick(gamepad)`, and `KaptanGamepad.getTriggers(gamepad)` for common controller input. Use `KaptanGamepad.getAxis(gamepad, axis)` for raw axis access.

Game code should apply deadzones to analog stick input.

```lua
local pad = 1

KaptanWindow.setLoopCallback(function()
    if KaptanGamepad.isAvailable(pad) then
        local x, y = KaptanGamepad.getLeftStick(pad)

        if math.abs(x) > 0.2 or math.abs(y) > 0.2 then
            print('move', x, y)
        end

        if KaptanGamepad.isPressed(pad, KaptanGamepad.BUTTON_RIGHT_FACE_DOWN) then
            print('confirm')
        end
    end
end)
```

### Input Best Practices

Use `isPressed` for one-shot actions like jump, confirm, pause, or opening a menu.

Use `isDown` for continuous actions like movement, charging, aiming, or holding a button.

Use a deadzone for analog sticks to avoid drift.

Use `KaptanMouse.getWorldPos()` when interacting with world objects.

Use `KaptanMouse.getPos()` when interacting with GUI or HUD objects.

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
* KaptanRenderer.remove(layer)
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
* layer:add(sprite_or_shape_or_text)
* layer:clear()
* layer:isCamAttached()
* layer:isVisible()
* layer:remove(sprite_or_shape_or_text)
* layer:setCamAttached(attached)
* layer:setVisible(visible)

### Sprite

* sprite = KaptanSprite.new(path)
* sprite:getPiv()
* sprite:getPos()
* sprite:getRot()
* sprite:getScl()
* sprite:getSize()
* sprite:isVisible()
* sprite:setColor(r, g, b, a)
* sprite:setFrame(frame_table)
* sprite:setFrameSize(w, h)
* sprite:setOffset(x, y)
* sprite:setPiv(x, y)
* sprite:setPos(x, y)
* sprite:setRot(angle)
* sprite:setScl(x, y)
* sprite:setSourceRect(x, y, w, h)
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
* shape = KaptanDraw.newPolygon(points)  -- a flat list: `{x1, y1, x2, y2, ...}`
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

### Audio

#### Audio System

* KaptanAudioSystem.init()
* KaptanAudioSystem.destroy()
* KaptanAudioSystem.isReady()
* KaptanAudioSystem.add(channel)
* KaptanAudioSystem.clear()
* KaptanAudioSystem.remove(channel)
* KaptanAudioSystem.setMasterVolume(volume)
* KaptanAudioSystem.getMasterVolume()

#### Audio Channel

* channel = KaptanAudioChannel.new(kind)
* channel:add(name, path)
* channel:clear()
* channel:play(name)
* channel:pause()
* channel:resume()
* channel:stop()
* channel:isPlaying()
* channel:setVolume(volume)
* channel:setPan(pan)
* channel:setPitch(pitch)
* channel:setLoop(loop)
* KaptanAudioChannel.SOUND
* KaptanAudioChannel.MUSIC

### Physics

* KaptanPhysics.clear()
* KaptanPhysics.destroy()
* KaptanPhysics.getContactEvents()
* KaptanPhysics.getGravity()
* KaptanPhysics.getSensorEvents()
* KaptanPhysics.getSubsteps()
* KaptanPhysics.getTickRate()
* KaptanPhysics.getUnitsPerMeter()
* KaptanPhysics.init()
* KaptanPhysics.isDebugDraw()
* KaptanPhysics.isReady()
* KaptanPhysics.queryAABB(x, y, width, height, options)
* KaptanPhysics.raycast(x1, y1, x2, y2, options)
* KaptanPhysics.setDebugDraw(enabled)
* KaptanPhysics.setGravity(x, y)
* KaptanPhysics.setSubsteps(count)
* KaptanPhysics.setTickRate(hz)
* KaptanPhysics.setUnitsPerMeter(value)
* KaptanPhysics.step(dt)  -- non-window/manual scripts only

#### Physics Body

* body = KaptanPhysicsBody.new(kind)
* body:addBox(width, height, options)
* body:addBox(width, height, radius, options)
* body:addCapsule(width, height, radius, options)
* body:addCircle(radius, options)
* body:addPolygon(points, options)
* body:applyAngularImpulse(value)
* body:applyForce(x, y)
* body:applyImpulse(x, y)
* body:applyTorque(value)
* body:destroy()
* body:getAngularDamping()
* body:getAngularVelocity()
* body:getId()
* body:getLinearDamping()
* body:getPos()
* body:getRot()
* body:getTag()
* body:getType()
* body:getVelocity()
* body:isBullet()
* body:isEnabled()
* body:isFixedRotation()
* body:isValid()
* body:setAngularDamping(value)
* body:setAngularVelocity(value)
* body:setBullet(enabled)
* body:setEnabled(enabled)
* body:setFixedRotation(enabled)
* body:setLinearDamping(value)
* body:setPos(x, y)
* body:setRot(angle)
* body:setTag(tag)
* body:setType(kind)
* body:setVelocity(x, y)
* KaptanPhysicsBody.STATIC
* KaptanPhysicsBody.KINEMATIC
* KaptanPhysicsBody.DYNAMIC

#### Physics Shape

* shape:destroy()
* shape:getCategory()
* shape:getDensity()
* shape:getFriction()
* shape:getGroup()
* shape:getId()
* shape:getMask()
* shape:getRestitution()
* shape:getTag()
* shape:isContactEvents()
* shape:isHitEvents()
* shape:isSensor()
* shape:isSensorEvents()
* shape:isValid()
* shape:setCategory(bits)
* shape:setContactEvents(enabled)
* shape:setDensity(value)
* shape:setFriction(value)
* shape:setGroup(group)
* shape:setHitEvents(enabled)
* shape:setMask(bits)
* shape:setRestitution(value)
* shape:setSensorEvents(enabled)
* shape:setTag(tag)

### Keyboard

* KaptanKeyboard.getKeysDown()
* KaptanKeyboard.isDown(key)
* KaptanKeyboard.isPressed(key)
* KaptanKeyboard.isReleased(key)
* KaptanKeyboard.isUp(key)
* KaptanKeyboard.KEY_*

### Mouse

* KaptanMouse.getDelta()
* KaptanMouse.getPos()
* KaptanMouse.getScreenPos()
* KaptanMouse.getWheel()
* KaptanMouse.getWheelV()
* KaptanMouse.getWorldPos()
* KaptanMouse.isDown(button)
* KaptanMouse.isPressed(button)
* KaptanMouse.isReleased(button)
* KaptanMouse.isUp(button)
* KaptanMouse.BUTTON_*

### Gamepad

* KaptanGamepad.getAxis(gamepad, axis)
* KaptanGamepad.getAxisCount(gamepad)
* KaptanGamepad.getButtonPressed()
* KaptanGamepad.getLeftStick(gamepad)
* KaptanGamepad.getName(gamepad)
* KaptanGamepad.getRightStick(gamepad)
* KaptanGamepad.getTriggers(gamepad)
* KaptanGamepad.isAvailable(gamepad)
* KaptanGamepad.isDown(gamepad, button)
* KaptanGamepad.isPressed(gamepad, button)
* KaptanGamepad.isReleased(gamepad, button)
* KaptanGamepad.isUp(gamepad, button)
* KaptanGamepad.AXIS_*
* KaptanGamepad.BUTTON_*
