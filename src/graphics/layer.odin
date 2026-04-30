package graphics

import "core:log"

import lua "vendor:lua/5.4"

import "../core"

RenderItemKind :: enum {
    Sprite,
    DrawShape,
}

RenderItem :: struct {
    kind:   RenderItemKind,
    sprite: ^Sprite,
    shape:  ^DrawShape,
}

Layer :: struct {
    items:   [dynamic]RenderItem,
    refs:    int,
    visible: bool,
    is_gone: bool,
}

InitLayer :: proc(layer: ^Layer) {
    log.debugf("KaptanLayer: Init")

    layer.items = make([dynamic]RenderItem)
    layer.refs    = 0
    layer.visible = true
    layer.is_gone = false
}

DestroyLayer :: proc(layer: ^Layer) {
    if layer == nil {
        return
    }

    log.debugf("KaptanLayer: Destroy")

    layer.is_gone = true

    clear_items(layer)
    delete(layer.items)
    free(layer)
}

LayerAddRef :: proc(layer: ^Layer) {
    layer.refs += 1
}

LayerReleaseRef :: proc(layer: ^Layer) {
    layer.refs -= 1

    if layer.is_gone && layer.refs == 0 {
        DestroyLayer(layer)
    }
}

LayerFromLua :: proc "c" (L: ^lua.State, idx: i32) -> ^Layer {
    handle := (^^Layer)(lua.touserdata(L, idx))
    return handle^
}

LayerLuaBind :: proc(L: ^lua.State) {
    @static static_reg_table: []lua.L_Reg = {
        { "new",        _new },
        { nil, nil },
    }

    @static instance_reg_table: []lua.L_Reg = {
        { "add",        _add },
        { "clear",      _clear },
        { "isVisible",  _get_visible },
        { "setVisible", _set_visible },
        { nil, nil },
    }

    core.LuaBindClass(L, "KaptanLayer", &static_reg_table, &instance_reg_table, __gc)
}

LayerLuaUnbind :: proc(L: ^lua.State) {
    // nothing to do
}

@(private="file")
_new :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    handle := (^^Layer)(lua.newuserdata(L, size_of(^Layer)))
    layer := new(Layer)
    InitLayer(layer)
    handle^ = layer

    core.LuaBindClassMetatable(L, "KaptanLayer")

    return 1
}

@(private="file")
_add :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    layer := LayerFromLua(L, 1)

    if core.LuaIsUserdataType(L, 2, "KaptanSpriteMT") {
        sprite := SpriteFromLua(L, 2)
        SpriteAddRef(sprite)
        append(&layer.items, RenderItem{kind = .Sprite, sprite = sprite})
    } else if core.LuaIsUserdataType(L, 2, "KaptanDrawMT") {
        shape := (^DrawShape)(lua.touserdata(L, 2))
        append(&layer.items, RenderItem{kind = .DrawShape, shape = shape})
    } else {
        log.errorf("KaptanLayer.add: argument 1 is not a KaptanSprite or KaptanDraw")
    }

    return 0
}

@(private="file")
_clear :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    layer := LayerFromLua(L, 1)

    clear_items(layer)

    return 0
}

@(private="file")
clear_items :: proc(layer: ^Layer) {
    for item in layer.items {
        switch item.kind {
        case .Sprite:
            SpriteReleaseRef(item.sprite)
        case .DrawShape:
            // DrawShape refs are handled when DrawShape gets the same ownership model.
        }
    }

    clear(&layer.items)
}

@(private="file")
_get_visible :: proc "c" (L: ^lua.State) -> i32 {
    layer := LayerFromLua(L, 1)

    lua.pushboolean(L, b32(layer.visible))

    return 1
}

@(private="file")
_set_visible :: proc "c" (L: ^lua.State) -> i32 {
    layer := LayerFromLua(L, 1)
    layer.visible = bool(lua.toboolean(L, 2))

    return 0
}

@(private="file")
__gc :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    layer := LayerFromLua(L, 1)

    if ! layer.is_gone {
        layer.is_gone = true

        if layer.refs == 0 {
            DestroyLayer(layer)
        }
    }

    return 0
}
