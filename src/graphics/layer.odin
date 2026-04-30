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
    visible: bool,
    is_gone: bool,
}

InitLayer :: proc(layer: ^Layer) {
    log.debugf("KaptanLayer: Init")

    layer.items = make([dynamic]RenderItem)
    layer.visible = true
    layer.is_gone = false
}

DestroyLayer :: proc(layer: ^Layer) {
    log.debugf("KaptanLayer: Destroy")

    layer.is_gone = true

    delete(layer.items)
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

    layer := (^Layer)(lua.newuserdata(L, size_of(Layer)))
    InitLayer(layer)

    core.LuaBindClassMetatable(L, "KaptanLayer")

    return 1
}

@(private="file")
_add :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    layer := (^Layer)(lua.touserdata(L, 1))

    if is_userdata_type(L, 2, "KaptanSpriteMT") {
        sprite := (^Sprite)(lua.touserdata(L, 2))
        append(&layer.items, RenderItem{kind = .Sprite, sprite = sprite})
    } else if is_userdata_type(L, 2, "KaptanDrawMT") {
        shape := (^DrawShape)(lua.touserdata(L, 2))
        append(&layer.items, RenderItem{kind = .DrawShape, shape = shape})
    } else {
        log.errorf("KaptanLayer.add: argument 1 is not a KaptanSprite or KaptanDraw")
    }

    return 0
}

@(private="file")
is_userdata_type :: proc(L: ^lua.State, idx: i32, name: cstring) -> bool {
    if !lua.isuserdata(L, idx) {
        return false
    }

    abs_idx := core.LuaGetAbsIndex(L, idx)
    lua.getmetatable(L, abs_idx)
    lua.L_getmetatable(L, name)

    result := lua.rawequal(L, -1, -2)
    lua.pop(L, 2)

    return bool(result)
}

@(private="file")
_clear :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    layer := (^Layer)(lua.touserdata(L, 1))

    delete(layer.items)
    layer.items = make([dynamic]RenderItem)

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
