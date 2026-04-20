package graphics

import "core:log"

import lua "vendor:lua/5.4"

import "../core"

Layer :: struct {
    sprites: [dynamic]^Sprite,
    visible: bool,
    is_gone: bool,
}

InitLayer :: proc(layer: ^Layer) {
    log.debugf("KaptanLayer: Init")

    layer.sprites = make([dynamic]^Sprite)
    layer.visible = true
    layer.is_gone = false
}

DestroyLayer :: proc(layer: ^Layer) {
    log.debugf("KaptanLayer: Destroy")

    layer.is_gone = true

    delete(layer.sprites)
}

LayerLuaBind :: proc(L: ^lua.State) {
    @static reg_table: []lua.L_Reg = {
        { "new",        _new },
        { "add",        _add },
        { "clear",      _clear },
        { "isVisible",  _get_visible },
        { "setVisible", _set_visible },
        { nil, nil },
    }

    core.LuaBindClass(L, "KaptanLayer", &reg_table, __gc)
}

LayerLuaUnbind :: proc(L: ^lua.State) {
    // nothing to do
}

@(private="file")
_new :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    layer := (^Layer)(lua.newuserdata(L, size_of(Layer)))
    InitLayer(layer)

    core.LuaBindClassMetatable(L, "KaptanLayer")

    return 1
}

@(private="file")
_add :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    layer := (^Layer)(lua.touserdata(L, 1))
    sprite := (^Sprite)(lua.touserdata(L, 2))

    append(&layer.sprites, sprite)

    return 0
}

@(private="file")
_clear :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    layer := (^Layer)(lua.touserdata(L, 1))

    delete(layer.sprites)
    layer.sprites = make([dynamic]^Sprite)

    return 0
}

@(private="file")
_get_visible :: proc "c" (L: ^lua.State) -> i32 {
    layer := (^Layer)(lua.touserdata(L, 1))

    lua.pushboolean(L, b32(layer.visible))

    return 1
}

@(private="file")
_set_visible :: proc "c" (L: ^lua.State) -> i32 {
    layer := (^Layer)(lua.touserdata(L, 1))
    layer.visible = bool(lua.toboolean(L, 2))

    return 0
}

@(private="file")
__gc :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    layer := (^Layer)(lua.touserdata(L, 1))
    DestroyLayer(layer)

    return 0
}
