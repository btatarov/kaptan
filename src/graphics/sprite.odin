package graphics

import "core:log"

import lua "vendor:lua/5.4"
import rl "vendor:raylib"

import "../core"

Sprite :: struct {
    using transform: Transform,
    texture:         ^Texture,
    source:          rl.Rectangle,
    offset:          rl.Vector2,
    width:           i32,
    height:          i32,
    color:           rl.Color,
    refs:            int,
    visible:         bool,
    is_gone:         bool,

    draw:            proc(sprite: ^Sprite),
}

@(private="file") sprite_count: u32

InitSprite :: proc(sprite: ^Sprite, texture: ^Texture) {
    log.debugf("LakshmiSprite: Init\n")

    InitTransform(&sprite.transform)

    sprite.texture = texture
    sprite.source  = rl.Rectangle{0, 0, f32(texture.tex.width), f32(texture.tex.height)}
    sprite.offset  = rl.Vector2{0, 0}
    sprite.width   = texture.tex.width
    sprite.height  = texture.tex.height
    sprite.color   = rl.WHITE
    sprite.refs    = 0
    sprite.visible = true
    sprite.is_gone = false

    sprite_count += 1

    sprite.draw = sprite_draw
}

DestroySprite :: proc(sprite: ^Sprite) {
    if sprite == nil {
        return
    }

    log.debugf("LakshmiSprite: Destroy\n")

    TextureDestroy(sprite.texture)

    sprite.is_gone = true
    sprite_count -= 1
    free(sprite)
}

SpriteAddRef :: proc(sprite: ^Sprite) {
    sprite.refs += 1
}

SpriteReleaseRef :: proc(sprite: ^Sprite) {
    sprite.refs -= 1

    if sprite.is_gone && sprite.refs == 0 {
        DestroySprite(sprite)
    }
}

SpriteFromLua :: proc "contextless" (L: ^lua.State, idx: i32) -> ^Sprite {
    return (^Sprite)(core.LuaUserdataHandle(L, idx, "KaptanSpriteMT"))
}

SpriteLuaBind :: proc(L: ^lua.State) {
    @static static_reg_table: []lua.L_Reg = {
        { "new",        _new },
        { nil, nil },
    }

    @static instance_reg_table: []lua.L_Reg = {
        { "getPiv",        _get_piv },
        { "getPos",        _get_pos },
        { "getRot",        _get_rot },
        { "getScl",        _get_scl },
        { "getSize",       _get_size },
        { "isVisible",     _get_visible },
        { "setColor",      _set_color },
        { "setFrameSize",  _set_frame_size },
        { "setOffset",     _set_offset },
        { "setPiv",        _set_piv },
        { "setPos",        _set_pos },
        { "setRot",        _set_rot },
        { "setScl",        _set_scl },
        { "setSourceRect", _set_source_rect },
        { "setVisible",    _set_visible },
        { nil, nil },
    }
    core.LuaBindClass(L, "KaptanSprite", &static_reg_table, &instance_reg_table, __gc)
}

SpriteLuaUnbind :: proc(L: ^lua.State) {
    // nothing to do
}

@(private="file")
sprite_draw :: proc(sprite: ^Sprite) {
    if !sprite.is_gone && sprite.visible {
        visible_left := -f32(sprite.width) * 0.5 + sprite.offset.x
        visible_top := -f32(sprite.height) * 0.5 + sprite.offset.y

        origin := rl.Vector2{
            (sprite.pivot.x - visible_left) * sprite.scale.x,
            (sprite.pivot.y - visible_top) * sprite.scale.y,
        }

        dst := rl.Rectangle{
            sprite.position.x + sprite.pivot.x,
            sprite.position.y + sprite.pivot.y,
            sprite.source.width * sprite.scale.x,
            sprite.source.height * sprite.scale.y,
        }

        rl.DrawTexturePro(
            sprite.texture.tex,
            sprite.source,
            dst,
            origin,
            sprite.rotation,
            sprite.color,
        )
    }
}

@(private="file")
_new :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    handle := (^^Sprite)(lua.newuserdata(L, size_of(^Sprite)))
    path := lua.L_checkstring(L, 1)

    sprite := new(Sprite)
    texture := TextureInit(path)
    InitSprite(sprite, texture)
    handle^ = sprite

    core.LuaBindClassMetatable(L, "KaptanSprite")

    return 1
}

@(private="file")
_get_piv :: proc "c" (L: ^lua.State) -> i32 {
    sprite := SpriteFromLua(L, 1)

    lua.pushnumber(L, lua.Number(sprite.pivot.x))
    lua.pushnumber(L, lua.Number(sprite.pivot.y))

    return 2
}

@(private="file")
_get_pos :: proc "c" (L: ^lua.State) -> i32 {
    sprite := SpriteFromLua(L, 1)

    lua.pushnumber(L, lua.Number(sprite.position.x))
    lua.pushnumber(L, lua.Number(sprite.position.y))

    return 2
}

@(private="file")
_get_rot :: proc "c" (L: ^lua.State) -> i32 {
    sprite := SpriteFromLua(L, 1)

    lua.pushnumber(L, lua.Number(sprite.rotation))

    return 1
}

@(private="file")
_get_scl :: proc "c" (L: ^lua.State) -> i32 {
    sprite := SpriteFromLua(L, 1)

    lua.pushnumber(L, lua.Number(sprite.scale.x))
    lua.pushnumber(L, lua.Number(sprite.scale.y))

    return 2
}

@(private="file")
_get_size :: proc "c" (L: ^lua.State) -> i32 {
    sprite := SpriteFromLua(L, 1)

    lua.pushnumber(L, lua.Number(sprite.width))
    lua.pushnumber(L, lua.Number(sprite.height))

    return 2
}

@(private="file")
_get_visible :: proc "c" (L: ^lua.State) -> i32 {
    sprite := SpriteFromLua(L, 1)

    lua.pushboolean(L, b32(sprite.visible))

    return 1
}

@(private="file")
_set_color :: proc "c" (L: ^lua.State) -> i32 {
    sprite := SpriteFromLua(L, 1)

    r := u8(clamp(int(lua.L_checkinteger(L, 2)), 0, 255))
    g := u8(clamp(int(lua.L_checkinteger(L, 3)), 0, 255))
    b := u8(clamp(int(lua.L_checkinteger(L, 4)), 0, 255))
    a := u8(clamp(int(lua.L_checkinteger(L, 5)), 0, 255))

    sprite.color = rl.Color{r, g, b, a}

    return 0
}

@(private="file")
_set_frame_size :: proc "c" (L: ^lua.State) -> i32 {
    sprite := SpriteFromLua(L, 1)

    sprite.width = i32(lua.L_checkinteger(L, 2))
    sprite.height = i32(lua.L_checkinteger(L, 3))

    return 0
}

@(private="file")
_set_offset :: proc "c" (L: ^lua.State) -> i32 {
    sprite := SpriteFromLua(L, 1)

    sprite.offset.x = f32(lua.L_checknumber(L, 2))
    sprite.offset.y = f32(lua.L_checknumber(L, 3))

    return 0
}

@(private="file")
_set_piv :: proc "c" (L: ^lua.State) -> i32 {
    sprite := SpriteFromLua(L, 1)

    sprite.pivot.x = f32(lua.tonumber(L, 2))
    sprite.pivot.y = f32(lua.tonumber(L, 3))

    return 0
}

@(private="file")
_set_pos :: proc "c" (L: ^lua.State) -> i32 {
    sprite := SpriteFromLua(L, 1)

    sprite.position.x = f32(lua.tonumber(L, 2))
    sprite.position.y = f32(lua.tonumber(L, 3))

    return 0
}

@(private="file")
_set_rot :: proc "c" (L: ^lua.State) -> i32 {
    sprite := SpriteFromLua(L, 1)

    sprite.rotation = f32(lua.tonumber(L, 2))

    return 0
}

@(private="file")
_set_scl :: proc "c" (L: ^lua.State) -> i32 {
    sprite := SpriteFromLua(L, 1)

    sprite.scale.x = f32(lua.tonumber(L, 2))
    sprite.scale.y = f32(lua.tonumber(L, 3))

    return 0
}

@(private="file")
_set_source_rect :: proc "c" (L: ^lua.State) -> i32 {
    sprite := SpriteFromLua(L, 1)

    sprite.source.x = f32(lua.L_checknumber(L, 2))
    sprite.source.y = f32(lua.L_checknumber(L, 3))
    sprite.source.width = f32(lua.L_checknumber(L, 4))
    sprite.source.height = f32(lua.L_checknumber(L, 5))

    return 0
}

@(private="file")
_set_visible :: proc "c" (L: ^lua.State) -> i32 {
    sprite := SpriteFromLua(L, 1)

    sprite.visible = bool(lua.toboolean(L, 2))

    return 0
}

@(private="file")
__gc :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    sprite := SpriteFromLua(L, 1)

    if ! sprite.is_gone {
        sprite.is_gone = true

        if sprite.refs == 0 {
            DestroySprite(sprite)
        }
    }

    return 0
}
