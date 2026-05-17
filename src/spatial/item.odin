package spatial

import "core:log"
import "core:strings"

import lua "vendor:lua/jit"

import "../core"

SpatialShapeKind :: enum {
    Point,
    Circle,
    Rect,
    Ellipse,
}

SpatialItem :: struct {
    space:    ^SpatialSpace,
    kind:     SpatialShapeKind,
    x:        f32,
    y:        f32,
    width:    f32,
    height:   f32,
    radius_x: f32,
    radius_y: f32,
    tag:      cstring,
    refs:     int,
    is_gone:  bool,
    enabled:  bool,
}

SpatialItemLuaBind :: proc(L: ^lua.State) {
    @static static_reg_table: []lua.L_Reg = {
        { nil, nil },
    }

    @static instance_reg_table: []lua.L_Reg = {
        { "getPos",     _get_pos },
        { "getTag",     _get_tag },
        { "isEnabled",  _is_enabled },
        { "isValid",    _is_valid },
        { "remove",     _remove },
        { "setCircle",  _set_circle },
        { "setEnabled", _set_enabled },
        { "setEllipse", _set_ellipse },
        { "setPos",     _set_pos },
        { "setRect",    _set_rect },
        { "setTag",     _set_tag },
        { nil, nil },
    }

    core.LuaBindClass(L, "KaptanSpatialItem", &static_reg_table, &instance_reg_table, __gc)
}

SpatialItemLuaUnbind :: proc(L: ^lua.State) {
    // nothing to do
}

SpatialItemInitPoint :: proc(item: ^SpatialItem, space: ^SpatialSpace, x, y: f32) {
    init_spatial_item(item, space, .Point, x, y)
}

SpatialItemInitCircle :: proc(item: ^SpatialItem, space: ^SpatialSpace, x, y, radius: f32) {
    init_spatial_item(item, space, .Circle, x, y)
    item.radius_x = radius
    item.radius_y = radius
}

SpatialItemInitRect :: proc(item: ^SpatialItem, space: ^SpatialSpace, x, y, width, height: f32) {
    init_spatial_item(item, space, .Rect, x, y)
    item.width = width
    item.height = height
}

SpatialItemInitEllipse :: proc(item: ^SpatialItem, space: ^SpatialSpace, x, y, radius_x, radius_y: f32) {
    init_spatial_item(item, space, .Ellipse, x, y)
    item.radius_x = radius_x
    item.radius_y = radius_y
}

SpatialItemFromLua :: proc "contextless" (L: ^lua.State, idx: i32) -> ^SpatialItem {
    return (^SpatialItem)(core.LuaUserdataHandle(L, idx, "KaptanSpatialItemMT"))
}

SpatialItemPushLua :: proc(L: ^lua.State, item: ^SpatialItem) {
    SpatialItemAddRef(item)
    handle := (^^SpatialItem)(lua.newuserdata(L, size_of(^SpatialItem)))
    handle^ = item
    core.LuaSetClassMetatable(L, "KaptanSpatialItem")
}

SpatialItemAddRef :: proc "contextless" (item: ^SpatialItem) {
    if item != nil {
        item.refs += 1
    }
}

SpatialItemReleaseRef :: proc(item: ^SpatialItem) {
    if item == nil {
        return
    }

    item.refs -= 1
    if item.refs <= 0 && item.is_gone {
        free_spatial_item(item)
    }
}

SpatialItemIsValid :: proc "contextless" (item: ^SpatialItem) -> bool {
    return item != nil && ! item.is_gone && item.space != nil && ! item.space.is_gone
}

SpatialItemIsQueryable :: proc "contextless" (item: ^SpatialItem) -> bool {
    return SpatialItemIsValid(item) && item.enabled
}

SpatialItemRemove :: proc(item: ^SpatialItem) -> bool {
    if ! SpatialItemIsValid(item) {
        return false
    }

    space := item.space
    item.is_gone = true
    item.space = nil
    clear_item_tag(item)

    if space != nil && ! space.is_gone {
        for existing, index in space.items {
            if existing == item {
                ordered_remove(&space.items, index)
                SpatialItemReleaseRef(item)
                break
            }
        }
    }

    return true
}

SpatialItemInvalidateFromSpace :: proc(item: ^SpatialItem) {
    if item == nil || item.is_gone {
        return
    }

    item.is_gone = true
    item.space = nil
    clear_item_tag(item)
}

@(private="file")
init_spatial_item :: proc(item: ^SpatialItem, space: ^SpatialSpace, kind: SpatialShapeKind, x, y: f32) {
    log.debugf("KaptanSpatialItem: Init")

    item.space = space
    item.kind = kind
    item.x = x
    item.y = y
    item.width = 0
    item.height = 0
    item.radius_x = 0
    item.radius_y = 0
    item.tag = nil
    item.refs = 0
    item.is_gone = false
    item.enabled = true
}

@(private="file")
free_spatial_item :: proc(item: ^SpatialItem) {
    if item == nil {
        return
    }

    log.debugf("KaptanSpatialItem: Destroy")
    clear_item_tag(item)
    free(item)
}

@(private="file")
clear_item_tag :: proc(item: ^SpatialItem) {
    if item.tag != nil {
        delete(item.tag)
        item.tag = nil
    }
}

@(private="file")
_get_pos :: proc "c" (L: ^lua.State) -> i32 {
    item := SpatialItemFromLua(L, 1)
    lua.pushnumber(L, lua.Number(item.x))
    lua.pushnumber(L, lua.Number(item.y))

    return 2
}

@(private="file")
_get_tag :: proc "c" (L: ^lua.State) -> i32 {
    item := SpatialItemFromLua(L, 1)
    if item.tag == nil {
        lua.pushnil(L)
    } else {
        lua.pushstring(L, item.tag)
    }

    return 1
}

@(private="file")
_is_valid :: proc "c" (L: ^lua.State) -> i32 {
    item := SpatialItemFromLua(L, 1)
    lua.pushboolean(L, b32(SpatialItemIsValid(item)))

    return 1
}

@(private="file")
_is_enabled :: proc "c" (L: ^lua.State) -> i32 {
    item := SpatialItemFromLua(L, 1)
    lua.pushboolean(L, b32(item.enabled))

    return 1
}

@(private="file")
_remove :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    item := SpatialItemFromLua(L, 1)
    lua.pushboolean(L, b32(SpatialItemRemove(item)))

    return 1
}

@(private="file")
_set_circle :: proc "c" (L: ^lua.State) -> i32 {
    item := SpatialItemFromLua(L, 1)
    radius := f32(lua.L_checknumber(L, 2))
    if radius < 0 {
        return i32(lua.L_argerror(L, 2, "radius must be >= 0"))
    }

    item.kind = .Circle
    item.radius_x = radius
    item.radius_y = radius

    return 0
}

@(private="file")
_set_enabled :: proc "c" (L: ^lua.State) -> i32 {
    item := SpatialItemFromLua(L, 1)
    item.enabled = bool(lua.toboolean(L, 2))

    return 0
}

@(private="file")
_set_ellipse :: proc "c" (L: ^lua.State) -> i32 {
    item := SpatialItemFromLua(L, 1)
    radius_x := f32(lua.L_checknumber(L, 2))
    radius_y := f32(lua.L_checknumber(L, 3))
    if radius_x < 0 {
        return i32(lua.L_argerror(L, 2, "radiusX must be >= 0"))
    }
    if radius_y < 0 {
        return i32(lua.L_argerror(L, 3, "radiusY must be >= 0"))
    }

    item.kind = .Ellipse
    item.radius_x = radius_x
    item.radius_y = radius_y

    return 0
}

@(private="file")
_set_pos :: proc "c" (L: ^lua.State) -> i32 {
    item := SpatialItemFromLua(L, 1)
    item.x = f32(lua.L_checknumber(L, 2))
    item.y = f32(lua.L_checknumber(L, 3))

    return 0
}

@(private="file")
_set_rect :: proc "c" (L: ^lua.State) -> i32 {
    item := SpatialItemFromLua(L, 1)
    width := f32(lua.L_checknumber(L, 2))
    height := f32(lua.L_checknumber(L, 3))
    if width < 0 {
        return i32(lua.L_argerror(L, 2, "width must be >= 0"))
    }
    if height < 0 {
        return i32(lua.L_argerror(L, 3, "height must be >= 0"))
    }

    item.kind = .Rect
    item.width = width
    item.height = height

    return 0
}

@(private="file")
_set_tag :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    item := SpatialItemFromLua(L, 1)
    clear_item_tag(item)

    if lua.isnoneornil(L, 2) {
        return 0
    }

    item.tag = strings.clone_to_cstring(string(lua.L_checkstring(L, 2)))

    return 0
}

@(private="file")
__gc :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    item := SpatialItemFromLua(L, 1)
    SpatialItemReleaseRef(item)

    return 0
}
