package spatial

import "core:c"
import "core:log"
import "core:math"

import lua "vendor:lua/jit"

import "../core"

SpatialSpace :: struct {
    items:   [dynamic]^SpatialItem,
    refs:    int,
    is_gone: bool,
}

SpatialSpaceLuaBind :: proc(L: ^lua.State) {
    @static static_reg_table: []lua.L_Reg = {
        { "new", _new },
        { nil, nil },
    }

    @static instance_reg_table: []lua.L_Reg = {
        { "addCircle",    _add_circle },
        { "addEllipse",   _add_ellipse },
        { "addPoint",     _add_point },
        { "addRect",      _add_rect },
        { "clear",        _clear },
        { "nearest",      _nearest },
        { "queryAABB",    _query_aabb },
        { "queryCircle",  _query_circle },
        { "queryEllipse", _query_ellipse },
        { "remove",       _remove },
        { nil, nil },
    }

    core.LuaBindClass(L, "KaptanSpatial", &static_reg_table, &instance_reg_table, __gc)
}

SpatialSpaceLuaUnbind :: proc(L: ^lua.State) {
    // nothing to do
}

SpatialSpaceFromLua :: proc "contextless" (L: ^lua.State, idx: i32) -> ^SpatialSpace {
    return (^SpatialSpace)(core.LuaUserdataHandle(L, idx, "KaptanSpatialMT"))
}

SpatialSpaceAddRef :: proc "contextless" (space: ^SpatialSpace) {
    if space != nil {
        space.refs += 1
    }
}

SpatialSpaceReleaseRef :: proc(space: ^SpatialSpace) {
    if space == nil {
        return
    }

    space.refs -= 1
    if space.refs <= 0 {
        destroy_space(space)
    }
}

SpatialSpaceClear :: proc(space: ^SpatialSpace) {
    if space == nil || space.is_gone {
        return
    }

    for item in space.items {
        SpatialItemInvalidateFromSpace(item)
        SpatialItemReleaseRef(item)
    }

    clear(&space.items)
}

@(private="file")
init_space :: proc(space: ^SpatialSpace) {
    log.debugf("KaptanSpatial: Init")

    space.items = make([dynamic]^SpatialItem)
    space.refs = 0
    space.is_gone = false
}

@(private="file")
destroy_space :: proc(space: ^SpatialSpace) {
    if space == nil {
        return
    }

    log.debugf("KaptanSpatial: Destroy")
    SpatialSpaceClear(space)
    space.is_gone = true
    delete(space.items)
    free(space)
}

@(private="file")
push_space_lua :: proc(L: ^lua.State, space: ^SpatialSpace) {
    SpatialSpaceAddRef(space)
    handle := (^^SpatialSpace)(lua.newuserdata(L, size_of(^SpatialSpace)))
    handle^ = space
    core.LuaSetClassMetatable(L, "KaptanSpatial")
}

@(private="file")
add_item :: proc(L: ^lua.State, space: ^SpatialSpace, item: ^SpatialItem) {
    SpatialItemAddRef(item)
    append(&space.items, item)
    SpatialItemPushLua(L, item)
}

@(private="file")
push_items_array :: proc(L: ^lua.State, items: []^SpatialItem) {
    lua.createtable(L, c.int(len(items)), 0)
    for item, index in items {
        SpatialItemPushLua(L, item)
        lua.rawseti(L, -2, i32(index + 1))
    }
}

@(private="file")
query_items :: proc(space: ^SpatialSpace, hit_test: proc "contextless" (item: ^SpatialItem, data: rawptr) -> bool, data: rawptr) -> [dynamic]^SpatialItem {
    hits := make([dynamic]^SpatialItem, allocator = context.temp_allocator)
    if space == nil || space.is_gone {
        return hits
    }

    for item in space.items {
        if SpatialItemIsValid(item) && hit_test(item, data) {
            append(&hits, item)
        }
    }

    return hits
}

@(private="file")
AABBQuery :: struct {
    x:      f32,
    y:      f32,
    width:  f32,
    height: f32,
}

@(private="file")
CircleQuery :: struct {
    x:      f32,
    y:      f32,
    radius: f32,
}

@(private="file")
EllipseQuery :: struct {
    x:        f32,
    y:        f32,
    radius_x: f32,
    radius_y: f32,
}

@(private="file")
aabb_hit_test :: proc "contextless" (item: ^SpatialItem, data: rawptr) -> bool {
    query := (^AABBQuery)(data)
    return item_intersects_aabb(item, query.x, query.y, query.width, query.height)
}

@(private="file")
circle_hit_test :: proc "contextless" (item: ^SpatialItem, data: rawptr) -> bool {
    query := (^CircleQuery)(data)
    return item_intersects_circle(item, query.x, query.y, query.radius)
}

@(private="file")
ellipse_hit_test :: proc "contextless" (item: ^SpatialItem, data: rawptr) -> bool {
    query := (^EllipseQuery)(data)
    return item_intersects_ellipse(item, query.x, query.y, query.radius_x, query.radius_y)
}

@(private="file")
item_intersects_aabb :: proc "contextless" (item: ^SpatialItem, x, y, width, height: f32) -> bool {
    switch item.kind {
    case .Point:
        return point_in_aabb(item.x, item.y, x, y, width, height)
    case .Circle:
        return circle_intersects_aabb(item.x, item.y, item.radius_x, x, y, width, height)
    case .Rect:
        return aabb_intersects_aabb(item.x, item.y, item.width, item.height, x, y, width, height)
    case .Ellipse:
        return ellipse_intersects_aabb(item.x, item.y, item.radius_x, item.radius_y, x, y, width, height)
    }

    return false
}

@(private="file")
item_intersects_circle :: proc "contextless" (item: ^SpatialItem, x, y, radius: f32) -> bool {
    switch item.kind {
    case .Point:
        return point_in_circle(item.x, item.y, x, y, radius)
    case .Circle:
        return circle_intersects_circle(item.x, item.y, item.radius_x, x, y, radius)
    case .Rect:
        return circle_intersects_aabb(x, y, radius, item.x, item.y, item.width, item.height)
    case .Ellipse:
        return point_in_ellipse(x, y, item.x, item.y, item.radius_x + radius, item.radius_y + radius)
    }

    return false
}

@(private="file")
item_intersects_ellipse :: proc "contextless" (item: ^SpatialItem, x, y, radius_x, radius_y: f32) -> bool {
    switch item.kind {
    case .Point:
        return point_in_ellipse(item.x, item.y, x, y, radius_x, radius_y)
    case .Circle:
        return point_in_ellipse(item.x, item.y, x, y, radius_x + item.radius_x, radius_y + item.radius_x)
    case .Rect:
        return ellipse_intersects_aabb(x, y, radius_x, radius_y, item.x, item.y, item.width, item.height)
    case .Ellipse:
        return point_in_ellipse(item.x, item.y, x, y, radius_x + item.radius_x, radius_y + item.radius_y)
    }

    return false
}

@(private="file")
point_in_aabb :: proc "contextless" (px, py, x, y, width, height: f32) -> bool {
    return math.abs(px - x) <= width * 0.5 && math.abs(py - y) <= height * 0.5
}

@(private="file")
point_in_circle :: proc "contextless" (px, py, x, y, radius: f32) -> bool {
    dx := px - x
    dy := py - y
    return dx * dx + dy * dy <= radius * radius
}

@(private="file")
point_in_ellipse :: proc "contextless" (px, py, x, y, radius_x, radius_y: f32) -> bool {
    if radius_x <= 0 || radius_y <= 0 {
        return px == x && py == y
    }

    dx := (px - x) / radius_x
    dy := (py - y) / radius_y
    return dx * dx + dy * dy <= 1
}

@(private="file")
circle_intersects_circle :: proc "contextless" (ax, ay, ar, bx, by, br: f32) -> bool {
    dx := ax - bx
    dy := ay - by
    r := ar + br
    return dx * dx + dy * dy <= r * r
}

@(private="file")
aabb_intersects_aabb :: proc "contextless" (ax, ay, aw, ah, bx, by, bw, bh: f32) -> bool {
    return math.abs(ax - bx) <= aw * 0.5 + bw * 0.5 && math.abs(ay - by) <= ah * 0.5 + bh * 0.5
}

@(private="file")
circle_intersects_aabb :: proc "contextless" (cx, cy, radius, x, y, width, height: f32) -> bool {
    closest_x := clamp(cx, x - width * 0.5, x + width * 0.5)
    closest_y := clamp(cy, y - height * 0.5, y + height * 0.5)
    return point_in_circle(closest_x, closest_y, cx, cy, radius)
}

@(private="file")
ellipse_intersects_aabb :: proc "contextless" (ex, ey, radius_x, radius_y, x, y, width, height: f32) -> bool {
    if point_in_aabb(ex, ey, x, y, width, height) {
        return true
    }

    closest_x := clamp(ex, x - width * 0.5, x + width * 0.5)
    closest_y := clamp(ey, y - height * 0.5, y + height * 0.5)
    return point_in_ellipse(closest_x, closest_y, ex, ey, radius_x, radius_y)
}

@(private="file")
_new :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    space := new(SpatialSpace)
    init_space(space)
    push_space_lua(L, space)

    return 1
}

@(private="file")
_add_point :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    space := SpatialSpaceFromLua(L, 1)
    item := new(SpatialItem)
    SpatialItemInitPoint(item, space, f32(lua.L_checknumber(L, 2)), f32(lua.L_checknumber(L, 3)))
    add_item(L, space, item)

    return 1
}

@(private="file")
_add_circle :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    radius := f32(lua.L_checknumber(L, 4))
    if radius < 0 {
        return i32(lua.L_argerror(L, 4, "radius must be >= 0"))
    }

    space := SpatialSpaceFromLua(L, 1)
    item := new(SpatialItem)
    SpatialItemInitCircle(item, space, f32(lua.L_checknumber(L, 2)), f32(lua.L_checknumber(L, 3)), radius)
    add_item(L, space, item)

    return 1
}

@(private="file")
_add_rect :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    width := f32(lua.L_checknumber(L, 4))
    height := f32(lua.L_checknumber(L, 5))
    if width < 0 {
        return i32(lua.L_argerror(L, 4, "width must be >= 0"))
    }
    if height < 0 {
        return i32(lua.L_argerror(L, 5, "height must be >= 0"))
    }

    space := SpatialSpaceFromLua(L, 1)
    item := new(SpatialItem)
    SpatialItemInitRect(item, space, f32(lua.L_checknumber(L, 2)), f32(lua.L_checknumber(L, 3)), width, height)
    add_item(L, space, item)

    return 1
}

@(private="file")
_add_ellipse :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    radius_x := f32(lua.L_checknumber(L, 4))
    radius_y := f32(lua.L_checknumber(L, 5))
    if radius_x < 0 {
        return i32(lua.L_argerror(L, 4, "radiusX must be >= 0"))
    }
    if radius_y < 0 {
        return i32(lua.L_argerror(L, 5, "radiusY must be >= 0"))
    }

    space := SpatialSpaceFromLua(L, 1)
    item := new(SpatialItem)
    SpatialItemInitEllipse(item, space, f32(lua.L_checknumber(L, 2)), f32(lua.L_checknumber(L, 3)), radius_x, radius_y)
    add_item(L, space, item)

    return 1
}

@(private="file")
_clear :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    space := SpatialSpaceFromLua(L, 1)
    SpatialSpaceClear(space)

    return 0
}

@(private="file")
_remove :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    space := SpatialSpaceFromLua(L, 1)
    item := SpatialItemFromLua(L, 2)
    if item.space != space {
        lua.pushboolean(L, false)
        return 1
    }

    lua.pushboolean(L, b32(SpatialItemRemove(item)))

    return 1
}

@(private="file")
_query_aabb :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    width := f32(lua.L_checknumber(L, 4))
    height := f32(lua.L_checknumber(L, 5))
    if width < 0 {
        return i32(lua.L_argerror(L, 4, "width must be >= 0"))
    }
    if height < 0 {
        return i32(lua.L_argerror(L, 5, "height must be >= 0"))
    }

    space := SpatialSpaceFromLua(L, 1)
    query := AABBQuery{
        x = f32(lua.L_checknumber(L, 2)),
        y = f32(lua.L_checknumber(L, 3)),
        width = width,
        height = height,
    }
    hits := query_items(space, aabb_hit_test, &query)
    push_items_array(L, hits[:])

    return 1
}

@(private="file")
_query_circle :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    radius := f32(lua.L_checknumber(L, 4))
    if radius < 0 {
        return i32(lua.L_argerror(L, 4, "radius must be >= 0"))
    }

    space := SpatialSpaceFromLua(L, 1)
    query := CircleQuery{
        x = f32(lua.L_checknumber(L, 2)),
        y = f32(lua.L_checknumber(L, 3)),
        radius = radius,
    }
    hits := query_items(space, circle_hit_test, &query)
    push_items_array(L, hits[:])

    return 1
}

@(private="file")
_query_ellipse :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    radius_x := f32(lua.L_checknumber(L, 4))
    radius_y := f32(lua.L_checknumber(L, 5))
    if radius_x < 0 {
        return i32(lua.L_argerror(L, 4, "radiusX must be >= 0"))
    }
    if radius_y < 0 {
        return i32(lua.L_argerror(L, 5, "radiusY must be >= 0"))
    }

    space := SpatialSpaceFromLua(L, 1)
    query := EllipseQuery{
        x = f32(lua.L_checknumber(L, 2)),
        y = f32(lua.L_checknumber(L, 3)),
        radius_x = radius_x,
        radius_y = radius_y,
    }
    hits := query_items(space, ellipse_hit_test, &query)
    push_items_array(L, hits[:])

    return 1
}

@(private="file")
_nearest :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    space := SpatialSpaceFromLua(L, 1)
    x := f32(lua.L_checknumber(L, 2))
    y := f32(lua.L_checknumber(L, 3))
    max_distance := f32(-1)
    if lua.gettop(L) >= 4 && ! lua.isnil(L, 4) {
        max_distance = f32(lua.L_checknumber(L, 4))
    }

    best: ^SpatialItem
    best_dist_sq := f32(0)
    if max_distance >= 0 {
        best_dist_sq = max_distance * max_distance
    }

    if space != nil && ! space.is_gone {
        for item in space.items {
            if ! SpatialItemIsValid(item) {
                continue
            }

            dx := item.x - x
            dy := item.y - y
            dist_sq := dx * dx + dy * dy
            if best == nil || dist_sq < best_dist_sq {
                if max_distance < 0 || dist_sq <= best_dist_sq {
                    best = item
                    best_dist_sq = dist_sq
                }
            }
        }
    }

    if best == nil {
        lua.pushnil(L)
        return 1
    }

    lua.createtable(L, 0, 4)
    result_idx := lua.gettop(L)

    SpatialItemPushLua(L, best)
    lua.setfield(L, result_idx, "item")

    lua.pushnumber(L, lua.Number(best.x))
    lua.setfield(L, result_idx, "x")

    lua.pushnumber(L, lua.Number(best.y))
    lua.setfield(L, result_idx, "y")

    lua.pushnumber(L, lua.Number(math.sqrt(best_dist_sq)))
    lua.setfield(L, result_idx, "distance")

    return 1
}

@(private="file")
__gc :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    space := SpatialSpaceFromLua(L, 1)
    SpatialSpaceReleaseRef(space)

    return 0
}
