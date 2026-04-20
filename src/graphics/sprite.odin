package graphics

import "core:log"
import "core:math/linalg"
import "core:strings"

import lua "vendor:lua/5.4"

import "../core"

Sprite :: struct {
    texture:  ^Texture,
    position: linalg.Vector3f32,
    width:    i32,
    height:   i32,
    visible:  bool,
    is_gone:  bool,
}

@(private="file") sprite_count: u32

InitSprite :: proc(sprite: ^Sprite, texture: ^Texture) {
    log.debugf("LakshmiSprite: Init\n")

    sprite.texture = texture
    sprite.width   = texture.tex.width
    sprite.height  = texture.tex.height
    sprite.visible = true
    sprite.is_gone = false

    sprite_count += 1
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
        { "getPos",     _get_pos },
        { "isVisible",  _get_visible },
        { "setPos",     _set_pos },
        { "setVisible", _set_visible },
        { nil, nil },
    }
    core.LuaBindClass(L, "KaptanSprite", &reg_table, __gc)
}

SpriteLuaUnbind :: proc(L: ^lua.State) {
    // nothing to do
}

@(private="file")
_new :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    sprite := (^Sprite)(lua.newuserdata(L, size_of(Sprite)))
    path := lua.L_checkstring(L, 1)

    texture := TextureInit(strings.clone_from_cstring(path))
    InitSprite(sprite, texture)

    core.LuaBindClassMetatable(L, "KaptanSprite")

    return 1
}

@(private="file")
_get_pos :: proc "c" (L: ^lua.State) -> i32 {
    sprite := (^Sprite)(lua.touserdata(L, 1))

    lua.pushnumber(L, lua.Number(sprite.position.x))
    lua.pushnumber(L, lua.Number(sprite.position.y))

    return 2
}

@(private="file")
_get_visible :: proc "c" (L: ^lua.State) -> i32 {
    sprite := (^Sprite)(lua.touserdata(L, 1))

    lua.pushboolean(L, b32(sprite.visible))

    return 1
}

@(private="file")
_set_pos :: proc "c" (L: ^lua.State) -> i32 {
    sprite := (^Sprite)(lua.touserdata(L, 1))

    sprite.position.x = f32(lua.tonumber(L, 2))
    sprite.position.y = f32(lua.tonumber(L, 3))

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
