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

    remove_gone: proc(layer: ^Layer),
}

InitLayer :: proc(layer: ^Layer) {
    log.debugf("KaptanLayer: Init")

    layer.items = make([dynamic]RenderItem)
    layer.refs    = 0
    layer.visible = true
    layer.is_gone = false

    layer.remove_gone = layer_remove_gone
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
    return (^Layer)(core.LuaUserdataHandle(L, idx, "KaptanLayerMT"))
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
layer_remove_gone :: proc(layer: ^Layer) {
    write := 0
    for item in layer.items {
        if is_item_gone(item) {
            release_item(item)
            continue
        }

        layer.items[write] = item
        write += 1
    }

    resize(&layer.items, write)
}

@(private="file")
clear_items :: proc(layer: ^Layer) {
    for item in layer.items {
        release_item(item)
    }

    clear(&layer.items)
}

@(private="file")
is_item_gone :: proc(item: RenderItem) -> bool {
    switch item.kind {
    case .Sprite:
        return item.sprite.is_gone
    case .DrawShape:
        return item.shape.is_gone
    }

    return true
}

@(private="file")
release_item :: proc(item: RenderItem) {
    switch item.kind {
    case .Sprite:
        SpriteReleaseRef(item.sprite)
    case .DrawShape:
        DrawShapeReleaseRef(item.shape)
    }
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
        shape := DrawShapeFromLua(L, 2)
        DrawShapeAddRef(shape)
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
