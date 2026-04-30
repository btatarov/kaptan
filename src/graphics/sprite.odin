package graphics

import "core:log"

import lua "vendor:lua/5.4"
import rl "vendor:raylib"

import "../core"

Sprite :: struct {
    using transform: Transform,
    texture:         ^Texture,
    width:           i32,
    height:          i32,
    visible:         bool,
    is_gone:         bool,

    draw:            proc(sprite: ^Sprite),
}

@(private="file") sprite_count: u32

InitSprite :: proc(sprite: ^Sprite, texture: ^Texture) {
    log.debugf("LakshmiSprite: Init\n")

    InitTransform(&sprite.transform)

    sprite.texture = texture
    sprite.width   = texture.tex.width
    sprite.height  = texture.tex.height
    sprite.visible = true
    sprite.is_gone = false

    sprite_count += 1

    sprite.draw = sprite_draw
}

DestroySprite :: proc(sprite: ^Sprite) {
    if sprite.is_gone {
        return
    }

    log.debugf("LakshmiSprite: Destroy\n")

    TextureDestroy(sprite.texture)

    sprite.is_gone = true
    sprite_count -= 1
}

SpriteLuaBind :: proc(L: ^lua.State) {
    @static reg_table: []lua.L_Reg = {
        { "new",        _new },
        { "getPiv",     _get_piv },
        { "getPos",     _get_pos },
        { "getRot",     _get_rot },
        { "getScl",     _get_scl },
        { "getSize",    _get_size },
        { "isVisible",  _get_visible },
        { "setPiv",     _set_piv },
        { "setPos",     _set_pos },
        { "setRot",     _set_rot },
        { "setScl",     _set_scl },
        { "setVisible", _set_visible },
        { nil, nil },
    }
    core.LuaBindClass(L, "KaptanSprite", &reg_table, __gc)
}

SpriteLuaUnbind :: proc(L: ^lua.State) {
    // nothing to do
}

@(private="file")
sprite_draw :: proc(sprite: ^Sprite) {
    if !sprite.is_gone && sprite.visible {
        w := f32(sprite.width)
        h := f32(sprite.height)

        src := rl.Rectangle{
            0,
            0,
            w,
            h,
        }

        origin := rl.Vector2{
            (w * 0.5 + sprite.pivot.x) * sprite.scale.x,
            (h * 0.5 + sprite.pivot.y) * sprite.scale.y,
        }

        dst := rl.Rectangle{
            sprite.position.x + sprite.pivot.x,
            sprite.position.y + sprite.pivot.y,
            w * sprite.scale.x,
            h * sprite.scale.y,
        }

        rl.DrawTexturePro(
            sprite.texture.tex,
            src,
            dst,
            origin,
            sprite.rotation,
            rl.WHITE,
        )
    }
}

@(private="file")
_new :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    sprite := (^Sprite)(lua.newuserdata(L, size_of(Sprite)))
    path := lua.L_checkstring(L, 1)

    texture := TextureInit(path)
    InitSprite(sprite, texture)

    core.LuaBindClassMetatable(L, "KaptanSprite")

    return 1
}

@(private="file")
_get_piv :: proc "c" (L: ^lua.State) -> i32 {
    sprite := (^Sprite)(lua.touserdata(L, 1))

    lua.pushnumber(L, lua.Number(sprite.pivot.x))
    lua.pushnumber(L, lua.Number(sprite.pivot.y))

    return 2
}

@(private="file")
_get_pos :: proc "c" (L: ^lua.State) -> i32 {
    sprite := (^Sprite)(lua.touserdata(L, 1))

    lua.pushnumber(L, lua.Number(sprite.position.x))
    lua.pushnumber(L, lua.Number(sprite.position.y))

    return 2
}

@(private="file")
_get_rot :: proc "c" (L: ^lua.State) -> i32 {
    sprite := (^Sprite)(lua.touserdata(L, 1))

    lua.pushnumber(L, lua.Number(sprite.rotation))

    return 1
}

@(private="file")
_get_scl :: proc "c" (L: ^lua.State) -> i32 {
    sprite := (^Sprite)(lua.touserdata(L, 1))

    lua.pushnumber(L, lua.Number(sprite.scale.x))
    lua.pushnumber(L, lua.Number(sprite.scale.y))

    return 2
}

@(private="file")
_get_size :: proc "c" (L: ^lua.State) -> i32 {
    sprite := (^Sprite)(lua.touserdata(L, 1))

    lua.pushnumber(L, lua.Number(sprite.width))
    lua.pushnumber(L, lua.Number(sprite.height))

    return 2
}

@(private="file")
_get_visible :: proc "c" (L: ^lua.State) -> i32 {
    sprite := (^Sprite)(lua.touserdata(L, 1))

    lua.pushboolean(L, b32(sprite.visible))

    return 1
}

@(private="file")
_set_piv :: proc "c" (L: ^lua.State) -> i32 {
    sprite := (^Sprite)(lua.touserdata(L, 1))

    sprite.pivot.x = f32(lua.tonumber(L, 2))
    sprite.pivot.y = f32(lua.tonumber(L, 3))

    return 0
}

@(private="file")
_set_pos :: proc "c" (L: ^lua.State) -> i32 {
    sprite := (^Sprite)(lua.touserdata(L, 1))

    sprite.position.x = f32(lua.tonumber(L, 2))
    sprite.position.y = f32(lua.tonumber(L, 3))

    return 0
}

@(private="file")
_set_rot :: proc "c" (L: ^lua.State) -> i32 {
    sprite := (^Sprite)(lua.touserdata(L, 1))

    sprite.rotation = f32(lua.tonumber(L, 2))

    return 0
}

@(private="file")
_set_scl :: proc "c" (L: ^lua.State) -> i32 {
    sprite := (^Sprite)(lua.touserdata(L, 1))

    sprite.scale.x = f32(lua.tonumber(L, 2))
    sprite.scale.y = f32(lua.tonumber(L, 3))

    return 0
}

@(private="file")
_set_visible :: proc "c" (L: ^lua.State) -> i32 {
    sprite := (^Sprite)(lua.touserdata(L, 1))

    sprite.visible = bool(lua.toboolean(L, 2))

    return 0
}

@(private="file")
__gc :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    sprite := (^Sprite)(lua.touserdata(L, -1))
    DestroySprite(sprite)

    return 0
}
