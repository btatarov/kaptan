package spatial

import "core:c"
import "core:log"
import "core:math"

import lua "vendor:lua/jit"

import "../core"

SpatialSpace :: struct {
    items:       [dynamic]^SpatialItem,
    query_items: [dynamic]^SpatialItem,
    refs:        int,
    is_gone:     bool,
    enabled:     bool,
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
        { "anyAABB",      _any_aabb },
        { "anyCircle",    _any_circle },
        { "anyEllipse",   _any_ellipse },
        { "clear",        _clear },
        { "countAABB",    _count_aabb },
        { "countCircle",  _count_circle },
        { "countEllipse", _count_ellipse },
        { "isEnabled",    _is_enabled },
        { "nearest",      _nearest },
        { "nearestInto",  _nearest_into },
        { "nearestItem",  _nearest_item },
        { "queryAABB",    _query_aabb },
        { "queryAABBInto", _query_aabb_into },
        { "queryCircle",  _query_circle },
        { "queryCircleInto", _query_circle_into },
        { "queryEllipse", _query_ellipse },
        { "queryEllipseInto", _query_ellipse_into },
        { "remove",       _remove },
        { "setEnabled",   _set_enabled },
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

SpatialSpaceIsQueryable :: proc "contextless" (space: ^SpatialSpace) -> bool {
    return space != nil && ! space.is_gone && space.enabled
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
    clear(&space.query_items)
}

SpatialSpaceAddItem :: proc(space: ^SpatialSpace, item: ^SpatialItem) {
    if space == nil || space.is_gone || item == nil || item.item_index >= 0 {
        return
    }

    item.item_index = len(space.items)
    append(&space.items, item)
}

SpatialSpaceRemoveItem :: proc(space: ^SpatialSpace, item: ^SpatialItem) {
    if space == nil || item == nil || item.item_index < 0 {
        return
    }

    index := item.item_index
    last_index := len(space.items) - 1
    if index < 0 || index > last_index {
        item.item_index = -1
        return
    }

    if index != last_index {
        moved := space.items[last_index]
        space.items[index] = moved
        moved.item_index = index
    }

    resize(&space.items, last_index)
    item.item_index = -1
    SpatialItemReleaseRef(item)
}

SpatialSpaceAddQueryItem :: proc(space: ^SpatialSpace, item: ^SpatialItem) {
    if space == nil || space.is_gone || item == nil || item.query_index >= 0 {
        return
    }

    item.query_index = len(space.query_items)
    append(&space.query_items, item)
}

SpatialSpaceRemoveQueryItem :: proc(space: ^SpatialSpace, item: ^SpatialItem) {
    if space == nil || item == nil || item.query_index < 0 {
        return
    }

    index := item.query_index
    last_index := len(space.query_items) - 1
    if index < 0 || index > last_index {
        item.query_index = -1
        return
    }

    if index != last_index {
        moved := space.query_items[last_index]
        space.query_items[index] = moved
        moved.query_index = index
    }

    resize(&space.query_items, last_index)
    item.query_index = -1
}

@(private="file")
init_space :: proc(space: ^SpatialSpace) {
    log.debugf("KaptanSpatial: Init")

    space.items = make([dynamic]^SpatialItem)
    space.query_items = make([dynamic]^SpatialItem)
    space.refs = 0
    space.is_gone = false
    space.enabled = true
}

@(private="file")
destroy_space :: proc(space: ^SpatialSpace) {
    if space == nil {
        return
    }

    log.debugf("KaptanSpatial: Destroy")
    SpatialSpaceClear(space)
    space.is_gone = true
    delete(space.query_items)
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
    SpatialSpaceAddItem(space, item)
    SpatialSpaceAddQueryItem(space, item)
    SpatialItemPushLua(L, item)
}

@(private="file")
HitTestProc :: proc "contextless" (item: ^SpatialItem, data: rawptr) -> bool

@(private="file")
push_items_array :: proc(L: ^lua.State, items: []^SpatialItem) {
    lua.createtable(L, c.int(len(items)), 0)
    for item, index in items {
        SpatialItemPushLua(L, item)
        lua.rawseti(L, -2, i32(index + 1))
    }
}

query_items :: proc(space: ^SpatialSpace, hit_test: HitTestProc, data: rawptr) -> [dynamic]^SpatialItem {
    hits := make([dynamic]^SpatialItem, allocator = context.temp_allocator)
    if ! SpatialSpaceIsQueryable(space) {
        return hits
    }

    for item in space.query_items {
        if hit_test(item, data) {
            append(&hits, item)
        }
    }

    return hits
}

@(private="file")
query_into_table :: proc(L: ^lua.State, table_idx: i32, space: ^SpatialSpace, hit_test: HitTestProc, data: rawptr) -> i32 {
    abs_idx := core.LuaGetAbsIndex(L, table_idx)
    old_count := i32(lua.objlen(L, abs_idx))
    count := i32(0)

    if SpatialSpaceIsQueryable(space) {
        for item in space.query_items {
            if hit_test(item, data) {
                count += 1
                SpatialItemPushLua(L, item)
                lua.rawseti(L, abs_idx, count)
            }
        }
    }

    for index := count + 1; index <= old_count; index += 1 {
        lua.pushnil(L)
        lua.rawseti(L, abs_idx, index)
    }

    return count
}

@(private="file")
query_count :: proc "contextless" (space: ^SpatialSpace, hit_test: HitTestProc, data: rawptr) -> int {
    count := 0
    if ! SpatialSpaceIsQueryable(space) {
        return count
    }

    for item in space.query_items {
        if hit_test(item, data) {
            count += 1
        }
    }

    return count
}

@(private="file")
query_any :: proc "contextless" (space: ^SpatialSpace, hit_test: HitTestProc, data: rawptr) -> bool {
    if ! SpatialSpaceIsQueryable(space) {
        return false
    }

    for item in space.query_items {
        if hit_test(item, data) {
            return true
        }
    }

    return false
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
check_output_table :: proc "contextless" (L: ^lua.State, idx: i32) -> i32 {
    if ! lua.istable(L, idx) {
        lua.L_argerror(L, c.int(idx), "table expected")
    }

    return core.LuaGetAbsIndex(L, idx)
}

@(private="file")
aabb_query_from_lua :: proc "contextless" (L: ^lua.State, x_idx: i32) -> AABBQuery {
    width_idx := x_idx + 2
    height_idx := x_idx + 3
    width := f32(lua.L_checknumber(L, width_idx))
    height := f32(lua.L_checknumber(L, height_idx))
    if width < 0 {
        lua.L_argerror(L, c.int(width_idx), "width must be >= 0")
    }
    if height < 0 {
        lua.L_argerror(L, c.int(height_idx), "height must be >= 0")
    }

    return AABBQuery{
        x = f32(lua.L_checknumber(L, x_idx)),
        y = f32(lua.L_checknumber(L, x_idx + 1)),
        width = width,
        height = height,
    }
}

@(private="file")
circle_query_from_lua :: proc "contextless" (L: ^lua.State, x_idx: i32) -> CircleQuery {
    radius_idx := x_idx + 2
    radius := f32(lua.L_checknumber(L, radius_idx))
    if radius < 0 {
        lua.L_argerror(L, c.int(radius_idx), "radius must be >= 0")
    }

    return CircleQuery{
        x = f32(lua.L_checknumber(L, x_idx)),
        y = f32(lua.L_checknumber(L, x_idx + 1)),
        radius = radius,
    }
}

@(private="file")
ellipse_query_from_lua :: proc "contextless" (L: ^lua.State, x_idx: i32) -> EllipseQuery {
    radius_x_idx := x_idx + 2
    radius_y_idx := x_idx + 3
    radius_x := f32(lua.L_checknumber(L, radius_x_idx))
    radius_y := f32(lua.L_checknumber(L, radius_y_idx))
    if radius_x < 0 {
        lua.L_argerror(L, c.int(radius_x_idx), "radiusX must be >= 0")
    }
    if radius_y < 0 {
        lua.L_argerror(L, c.int(radius_y_idx), "radiusY must be >= 0")
    }

    return EllipseQuery{
        x = f32(lua.L_checknumber(L, x_idx)),
        y = f32(lua.L_checknumber(L, x_idx + 1)),
        radius_x = radius_x,
        radius_y = radius_y,
    }
}

@(private="file")
nearest_item :: proc "contextless" (space: ^SpatialSpace, x, y, max_distance: f32) -> (best: ^SpatialItem, distance: f32) {
    best_dist_sq := f32(0)
    if max_distance >= 0 {
        best_dist_sq = max_distance * max_distance
    }

    if SpatialSpaceIsQueryable(space) {
        for item in space.query_items {
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
        return nil, 0
    }

    return best, math.sqrt(best_dist_sq)
}

@(private="file")
nearest_max_distance_from_lua :: proc "contextless" (L: ^lua.State, idx: i32) -> f32 {
    max_distance := f32(-1)
    if lua.gettop(L) >= idx && ! lua.isnil(L, idx) {
        max_distance = f32(lua.L_checknumber(L, idx))
    }

    return max_distance
}

@(private="file")
set_nearest_result :: proc(L: ^lua.State, table_idx: i32, item: ^SpatialItem, distance: f32) {
    abs_idx := core.LuaGetAbsIndex(L, table_idx)

    SpatialItemPushLua(L, item)
    lua.setfield(L, abs_idx, "item")

    lua.pushnumber(L, lua.Number(item.x))
    lua.setfield(L, abs_idx, "x")

    lua.pushnumber(L, lua.Number(item.y))
    lua.setfield(L, abs_idx, "y")

    lua.pushnumber(L, lua.Number(distance))
    lua.setfield(L, abs_idx, "distance")
}

@(private="file")
clear_nearest_result :: proc "contextless" (L: ^lua.State, table_idx: i32) {
    abs_idx := core.LuaGetAbsIndex(L, table_idx)

    lua.pushnil(L)
    lua.setfield(L, abs_idx, "item")

    lua.pushnil(L)
    lua.setfield(L, abs_idx, "x")

    lua.pushnil(L)
    lua.setfield(L, abs_idx, "y")

    lua.pushnil(L)
    lua.setfield(L, abs_idx, "distance")
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
_is_enabled :: proc "c" (L: ^lua.State) -> i32 {
    space := SpatialSpaceFromLua(L, 1)
    lua.pushboolean(L, b32(space.enabled))

    return 1
}

@(private="file")
_set_enabled :: proc "c" (L: ^lua.State) -> i32 {
    space := SpatialSpaceFromLua(L, 1)
    space.enabled = bool(lua.toboolean(L, 2))

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

    space := SpatialSpaceFromLua(L, 1)
    query := aabb_query_from_lua(L, 2)
    hits := query_items(space, aabb_hit_test, &query)
    push_items_array(L, hits[:])

    return 1
}

@(private="file")
_query_circle :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    space := SpatialSpaceFromLua(L, 1)
    query := circle_query_from_lua(L, 2)
    hits := query_items(space, circle_hit_test, &query)
    push_items_array(L, hits[:])

    return 1
}

@(private="file")
_query_ellipse :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    space := SpatialSpaceFromLua(L, 1)
    query := ellipse_query_from_lua(L, 2)
    hits := query_items(space, ellipse_hit_test, &query)
    push_items_array(L, hits[:])

    return 1
}

@(private="file")
_query_aabb_into :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    space := SpatialSpaceFromLua(L, 1)
    result_idx := check_output_table(L, 2)
    query := aabb_query_from_lua(L, 3)
    count := query_into_table(L, result_idx, space, aabb_hit_test, &query)
    lua.pushinteger(L, lua.Integer(count))

    return 1
}

@(private="file")
_query_circle_into :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    space := SpatialSpaceFromLua(L, 1)
    result_idx := check_output_table(L, 2)
    query := circle_query_from_lua(L, 3)
    count := query_into_table(L, result_idx, space, circle_hit_test, &query)
    lua.pushinteger(L, lua.Integer(count))

    return 1
}

@(private="file")
_query_ellipse_into :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    space := SpatialSpaceFromLua(L, 1)
    result_idx := check_output_table(L, 2)
    query := ellipse_query_from_lua(L, 3)
    count := query_into_table(L, result_idx, space, ellipse_hit_test, &query)
    lua.pushinteger(L, lua.Integer(count))

    return 1
}

@(private="file")
_any_aabb :: proc "c" (L: ^lua.State) -> i32 {
    space := SpatialSpaceFromLua(L, 1)
    query := aabb_query_from_lua(L, 2)
    lua.pushboolean(L, b32(query_any(space, aabb_hit_test, &query)))

    return 1
}

@(private="file")
_any_circle :: proc "c" (L: ^lua.State) -> i32 {
    space := SpatialSpaceFromLua(L, 1)
    query := circle_query_from_lua(L, 2)
    lua.pushboolean(L, b32(query_any(space, circle_hit_test, &query)))

    return 1
}

@(private="file")
_any_ellipse :: proc "c" (L: ^lua.State) -> i32 {
    space := SpatialSpaceFromLua(L, 1)
    query := ellipse_query_from_lua(L, 2)
    lua.pushboolean(L, b32(query_any(space, ellipse_hit_test, &query)))

    return 1
}

@(private="file")
_count_aabb :: proc "c" (L: ^lua.State) -> i32 {
    space := SpatialSpaceFromLua(L, 1)
    query := aabb_query_from_lua(L, 2)
    lua.pushinteger(L, lua.Integer(query_count(space, aabb_hit_test, &query)))

    return 1
}

@(private="file")
_count_circle :: proc "c" (L: ^lua.State) -> i32 {
    space := SpatialSpaceFromLua(L, 1)
    query := circle_query_from_lua(L, 2)
    lua.pushinteger(L, lua.Integer(query_count(space, circle_hit_test, &query)))

    return 1
}

@(private="file")
_count_ellipse :: proc "c" (L: ^lua.State) -> i32 {
    space := SpatialSpaceFromLua(L, 1)
    query := ellipse_query_from_lua(L, 2)
    lua.pushinteger(L, lua.Integer(query_count(space, ellipse_hit_test, &query)))

    return 1
}

@(private="file")
_nearest :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    space := SpatialSpaceFromLua(L, 1)
    x := f32(lua.L_checknumber(L, 2))
    y := f32(lua.L_checknumber(L, 3))
    max_distance := nearest_max_distance_from_lua(L, 4)
    best, distance := nearest_item(space, x, y, max_distance)

    if best == nil {
        lua.pushnil(L)
        return 1
    }

    lua.createtable(L, 0, 4)
    set_nearest_result(L, lua.gettop(L), best, distance)

    return 1
}

@(private="file")
_nearest_into :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    space := SpatialSpaceFromLua(L, 1)
    result_idx := check_output_table(L, 2)
    x := f32(lua.L_checknumber(L, 3))
    y := f32(lua.L_checknumber(L, 4))
    max_distance := nearest_max_distance_from_lua(L, 5)
    best, distance := nearest_item(space, x, y, max_distance)

    if best == nil {
        clear_nearest_result(L, result_idx)
        lua.pushboolean(L, false)
        return 1
    }

    set_nearest_result(L, result_idx, best, distance)
    lua.pushboolean(L, true)

    return 1
}

@(private="file")
_nearest_item :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    space := SpatialSpaceFromLua(L, 1)
    x := f32(lua.L_checknumber(L, 2))
    y := f32(lua.L_checknumber(L, 3))
    max_distance := nearest_max_distance_from_lua(L, 4)
    best, _ := nearest_item(space, x, y, max_distance)

    if best == nil {
        lua.pushnil(L)
        return 1
    }

    SpatialItemPushLua(L, best)

    return 1
}

@(private="file")
__gc :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    space := SpatialSpaceFromLua(L, 1)
    SpatialSpaceReleaseRef(space)

    return 0
}
