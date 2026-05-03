package graphics

import "core:c"
import "core:log"

import lua "vendor:lua/5.4"

import "../core"

RenderItemKind :: enum {
    Sprite,
    DrawShape,
    Text,
}

RenderItem :: struct {
    kind:   RenderItemKind,
    sprite: ^Sprite,
    shape:  ^DrawShape,
    text:   ^Text,
}

Layer :: struct {
    items:        [dynamic]RenderItem,
    refs:         int,
    visible:      bool,
    cam_attached: bool,
    is_gone:      bool,

    contains:    proc(layer: ^Layer, target: RenderItem) -> bool,
    remove_gone: proc(layer: ^Layer),
}

InitLayer :: proc(layer: ^Layer) {
    log.debugf("KaptanLayer: Init")

    layer.items        = make([dynamic]RenderItem)
    layer.refs         = 0
    layer.visible      = true
    layer.cam_attached = true
    layer.is_gone      = false

    layer.contains    = layer_contains
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

LayerFromLua :: proc "contextless" (L: ^lua.State, idx: i32) -> ^Layer {
    return (^Layer)(core.LuaUserdataHandle(L, idx, "KaptanLayerMT"))
}

LayerLuaBind :: proc(L: ^lua.State) {
    @static static_reg_table: []lua.L_Reg = {
        { "new",        _new },
        { nil, nil },
    }

    @static instance_reg_table: []lua.L_Reg = {
        { "add",            _add },
        { "clear",          _clear },
        { "isCamAttached",  _get_cam_attached },
        { "isVisible",      _get_visible },
        { "remove",         _remove },
        { "setCamAttached", _set_cam_attached },
        { "setVisible",     _set_visible },
        { nil, nil },
    }

    core.LuaBindClass(L, "KaptanLayer", &static_reg_table, &instance_reg_table, __gc)
}

LayerLuaUnbind :: proc(L: ^lua.State) {
    // nothing to do
}

@(private="file")
layer_contains :: proc(layer: ^Layer, target: RenderItem) -> bool {
    for item in layer.items {
        if item_matches(item, target) {
            return true
        }
    }

    return false
}

@(private="file")
layer_remove_gone :: proc(layer: ^Layer) {
    write := 0
    for item in layer.items {
        if is_item_gone(item) {
            release_item_ref(item)
            continue
        }

        layer.items[write] = item
        write += 1
    }

    resize(&layer.items, write)
}

@(private="file")
add_item_ref :: proc(item: RenderItem) {
    switch item.kind {
    case .Sprite:
        SpriteAddRef(item.sprite)
    case .DrawShape:
        DrawShapeAddRef(item.shape)
    case .Text:
        TextAddRef(item.text)
    }
}

@(private="file")
release_item_ref :: proc(item: RenderItem) {
    switch item.kind {
    case .Sprite:
        SpriteReleaseRef(item.sprite)
    case .DrawShape:
        DrawShapeReleaseRef(item.shape)
    case .Text:
        TextReleaseRef(item.text)
    }
}

@(private="file")
clear_items :: proc(layer: ^Layer) {
    for item in layer.items {
        release_item_ref(item)
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
    case .Text:
        return item.text.is_gone
    }

    return true
}

@(private="file")
item_matches :: proc(item, target: RenderItem) -> bool {
    if item.kind != target.kind {
        return false
    }

    switch item.kind {
    case .Sprite:
        return item.sprite == target.sprite
    case .DrawShape:
        return item.shape == target.shape
    case .Text:
        return item.text == target.text
    }

    return false
}

@(private="file")
item_from_lua :: proc "contextless" (L: ^lua.State, idx: i32) -> (RenderItem, bool) {
    if core.LuaIsUserdataType(L, idx, "KaptanSpriteMT") {
        return RenderItem{kind = .Sprite, sprite = SpriteFromLua(L, idx)}, true
    } else if core.LuaIsUserdataType(L, idx, "KaptanDrawMT") {
        return RenderItem{kind = .DrawShape, shape = DrawShapeFromLua(L, idx)}, true
    } else if core.LuaIsUserdataType(L, idx, "KaptanTextMT") {
        return RenderItem{kind = .Text, text = TextFromLua(L, idx)}, true
    }

    return {}, false
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
    item, ok := item_from_lua(L, 2)
    if ! ok {
        return i32(lua.L_argerror(L, c.int(2), "KaptanSprite, KaptanDraw, or KaptanText expected"))
    }

    if layer->contains(item) {
        lua.pushboolean(L, false)

        return 1
    }

    add_item_ref(item)
    append(&layer.items, item)

    lua.pushboolean(L, true)

    return 1
}

@(private="file")
_clear :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    layer := LayerFromLua(L, 1)

    clear_items(layer)

    return 0
}

@(private="file")
_remove :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    layer := LayerFromLua(L, 1)
    target, ok := item_from_lua(L, 2)
    if ! ok {
        return i32(lua.L_argerror(L, c.int(2), "KaptanSprite, KaptanDraw, or KaptanText expected"))
    }

    for item, index in layer.items {
        if item_matches(item, target) {
            release_item_ref(item)
            ordered_remove(&layer.items, index)
            lua.pushboolean(L, true)

            return 1
        }
    }

    lua.pushboolean(L, false)

    return 1
}

@(private="file")
_get_cam_attached :: proc "c" (L: ^lua.State) -> i32 {
    layer := LayerFromLua(L, 1)

    lua.pushboolean(L, b32(layer.cam_attached))

    return 1
}

@(private="file")
_get_visible :: proc "c" (L: ^lua.State) -> i32 {
    layer := LayerFromLua(L, 1)

    lua.pushboolean(L, b32(layer.visible))

    return 1
}

@(private="file")
_set_cam_attached :: proc "c" (L: ^lua.State) -> i32 {
    layer := LayerFromLua(L, 1)
    layer.cam_attached = bool(lua.toboolean(L, 2))

    return 0
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
