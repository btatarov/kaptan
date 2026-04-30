package graphics

import "core:log"
import "core:math"
import "core:math/linalg"

import lua "vendor:lua/5.4"
import rl "vendor:raylib"

import "../core"

DrawShapeKind :: enum {
    Point,
    Line,
    Rect,
    Circle,
    Ellipse,
    Polygon,
}

DrawShape :: struct {
    using transform: Transform,
    kind:            DrawShapeKind,
    points:          [dynamic]linalg.Vector2f32,
    size:            linalg.Vector2f32,
    radius:          f32,
    refs:            int,
    visible:         bool,
    is_gone:         bool,

    draw:            proc(shape: ^DrawShape),
}

@(private="file") DRAW_FILL_COLOR := rl.Color{192, 192, 192, 255}
@(private="file") DRAW_OUTLINE_COLOR := rl.Color{64, 64, 64, 255}
@(private="file") DRAW_THICKNESS: f32 = 2
@(private="file") DRAW_SEGMENTS: int = 48

InitDrawShape :: proc(shape: ^DrawShape, kind: DrawShapeKind) {
    log.debugf("KaptanDraw: Init")

    InitTransform(&shape.transform)

    shape.kind    = kind
    shape.points  = make([dynamic]linalg.Vector2f32)
    shape.refs    = 0
    shape.visible = true
    shape.is_gone = false

    shape.draw = draw_shape
}

DestroyDrawShape :: proc(shape: ^DrawShape) {
    if shape == nil {
        return
    }

    log.debugf("KaptanDraw: Destroy")

    delete(shape.points)
    shape.is_gone = true
    free(shape)
}

DrawShapeAddRef :: proc(shape: ^DrawShape) {
    shape.refs += 1
}

DrawShapeReleaseRef :: proc(shape: ^DrawShape) {
    shape.refs -= 1

    if shape.is_gone && shape.refs == 0 {
        DestroyDrawShape(shape)
    }
}

DrawShapeFromLua :: proc "contextless" (L: ^lua.State, idx: i32) -> ^DrawShape {
    return (^DrawShape)(core.LuaUserdataHandle(L, idx, "KaptanDrawMT"))
}

DrawLuaBind :: proc(L: ^lua.State) {
    @static static_reg_table: []lua.L_Reg = {
        { "newPoint",   _new_point },
        { "newLine",    _new_line },
        { "newRect",    _new_rect },
        { "newCircle",  _new_circle },
        { "newEllipse", _new_ellipse },
        { "newPolygon", _new_polygon },
        { nil, nil },
    }

    @static instance_reg_table: []lua.L_Reg = {
        { "getPiv",     _get_piv },
        { "getPos",     _get_pos },
        { "getRot",     _get_rot },
        { "getScl",     _get_scl },
        { "isVisible",  _get_visible },
        { "setPiv",     _set_piv },
        { "setPos",     _set_pos },
        { "setRot",     _set_rot },
        { "setScl",     _set_scl },
        { "setVisible", _set_visible },
        { nil, nil },
    }
    core.LuaBindClass(L, "KaptanDraw", &static_reg_table, &instance_reg_table, __gc)
}

DrawLuaUnbind :: proc(L: ^lua.State) {
    // nothing to do
}

@(private="file")
draw_shape :: proc(shape: ^DrawShape) {
    if shape.is_gone || !shape.visible {
        return
    }

    switch shape.kind {
    case .Point:
        draw_point(shape)
    case .Line:
        draw_line(shape)
    case .Rect:
        draw_rect(shape)
    case .Circle:
        draw_circle(shape)
    case .Ellipse:
        draw_ellipse(shape)
    case .Polygon:
        draw_polygon(shape)
    }
}

@(private="file")
draw_point :: proc(shape: ^DrawShape) {
    if len(shape.points) < 1 {
        return
    }

    p := transform_point(shape, shape.points[0])
    rl.DrawCircleV(p, DRAW_THICKNESS, DRAW_FILL_COLOR)
    rl.DrawCircleLinesV(p, DRAW_THICKNESS, DRAW_OUTLINE_COLOR)
}

@(private="file")
draw_line :: proc(shape: ^DrawShape) {
    if len(shape.points) < 2 {
        return
    }

    a := transform_point(shape, shape.points[0])
    b := transform_point(shape, shape.points[1])
    rl.DrawLineEx(a, b, DRAW_THICKNESS, DRAW_OUTLINE_COLOR)
}

@(private="file")
draw_rect :: proc(shape: ^DrawShape) {
    if len(shape.points) < 1 {
        return
    }

    p := shape.points[0]
    w := shape.size.x
    h := shape.size.y
    points := [?]linalg.Vector2f32{
        p,
        {p.x + w, p.y},
        {p.x + w, p.y + h},
        {p.x, p.y + h},
    }

    draw_polyline(shape, points[:], true)
}

@(private="file")
draw_circle :: proc(shape: ^DrawShape) {
    if len(shape.points) < 1 {
        return
    }

    draw_ellipse_points(shape, shape.points[0], shape.radius, shape.radius)
}

@(private="file")
draw_ellipse :: proc(shape: ^DrawShape) {
    if len(shape.points) < 1 {
        return
    }

    draw_ellipse_points(shape, shape.points[0], shape.size.x, shape.size.y)
}

@(private="file")
draw_polygon :: proc(shape: ^DrawShape) {
    draw_polyline(shape, shape.points[:], true)
}

@(private="file")
draw_ellipse_points :: proc(shape: ^DrawShape, center: linalg.Vector2f32, radius_x, radius_y: f32) {
    points := make([dynamic]linalg.Vector2f32, 0, DRAW_SEGMENTS)
    defer delete(points)

    for i in 0..<DRAW_SEGMENTS {
        angle := f32(i) / f32(DRAW_SEGMENTS) * math.TAU
        append(&points, linalg.Vector2f32{
            center.x + math.cos(angle) * radius_x,
            center.y + math.sin(angle) * radius_y,
        })
    }

    draw_polyline(shape, points[:], true)
}

@(private="file")
draw_polyline :: proc(shape: ^DrawShape, local_points: []linalg.Vector2f32, closed: bool) {
    if len(local_points) < 2 {
        return
    }

    points := make([dynamic]rl.Vector2, 0, len(local_points))
    defer delete(points)

    for point in local_points {
        append(&points, transform_point(shape, point))
    }

    if closed && len(points) >= 3 {
        for i in 1..<len(points) - 1 {
            rl.DrawTriangle(points[0], points[i + 1], points[i], DRAW_FILL_COLOR)
        }
    }

    for i in 0..<len(points) - 1 {
        rl.DrawLineEx(points[i], points[i + 1], DRAW_THICKNESS, DRAW_OUTLINE_COLOR)
    }

    if closed {
        rl.DrawLineEx(points[len(points) - 1], points[0], DRAW_THICKNESS, DRAW_OUTLINE_COLOR)
    }
}

@(private="file")
transform_point :: proc(shape: ^DrawShape, point: linalg.Vector2f32) -> rl.Vector2 {
    x := (point.x - shape.pivot.x) * shape.scale.x
    y := (point.y - shape.pivot.y) * shape.scale.y
    radians := math.to_radians(shape.rotation)
    sin := math.sin(radians)
    cos := math.cos(radians)

    return rl.Vector2{
        shape.position.x + shape.pivot.x + x * cos - y * sin,
        shape.position.y + shape.pivot.y + x * sin + y * cos,
    }
}

@(private="file")
new_shape :: proc(L: ^lua.State, kind: DrawShapeKind) -> ^DrawShape {
    handle := (^^DrawShape)(lua.newuserdata(L, size_of(^DrawShape)))
    shape := new(DrawShape)
    InitDrawShape(shape, kind)
    handle^ = shape

    core.LuaBindClassMetatable(L, "KaptanDraw")

    return shape
}

@(private="file")
_new_point :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    shape := new_shape(L, .Point)
    append(&shape.points, linalg.Vector2f32{f32(lua.tonumber(L, 1)), f32(lua.tonumber(L, 2))})

    return 1
}

@(private="file")
_new_line :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    shape := new_shape(L, .Line)
    append(&shape.points, linalg.Vector2f32{f32(lua.tonumber(L, 1)), f32(lua.tonumber(L, 2))})
    append(&shape.points, linalg.Vector2f32{f32(lua.tonumber(L, 3)), f32(lua.tonumber(L, 4))})

    return 1
}

@(private="file")
_new_rect :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    shape := new_shape(L, .Rect)
    append(&shape.points, linalg.Vector2f32{f32(lua.tonumber(L, 1)), f32(lua.tonumber(L, 2))})
    shape.size = linalg.Vector2f32{f32(lua.tonumber(L, 3)), f32(lua.tonumber(L, 4))}

    return 1
}

@(private="file")
_new_circle :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    shape := new_shape(L, .Circle)
    append(&shape.points, linalg.Vector2f32{f32(lua.tonumber(L, 1)), f32(lua.tonumber(L, 2))})
    shape.radius = f32(lua.tonumber(L, 3))

    return 1
}

@(private="file")
_new_ellipse :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    shape := new_shape(L, .Ellipse)
    append(&shape.points, linalg.Vector2f32{f32(lua.tonumber(L, 1)), f32(lua.tonumber(L, 2))})
    shape.size = linalg.Vector2f32{f32(lua.tonumber(L, 3)), f32(lua.tonumber(L, 4))}

    return 1
}

@(private="file")
_new_polygon :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    shape := new_shape(L, .Polygon)

    point_count := i32(lua.rawlen(L, 1))
    for i := i32(1); i < point_count; i += 2 {
        lua.rawgeti(L, 1, lua.Integer(i))
        x := f32(lua.tonumber(L, -1))
        lua.pop(L, 1)

        lua.rawgeti(L, 1, lua.Integer(i + 1))
        y := f32(lua.tonumber(L, -1))
        lua.pop(L, 1)

        append(&shape.points, linalg.Vector2f32{x, y})
    }

    return 1
}

@(private="file")
_get_piv :: proc "c" (L: ^lua.State) -> i32 {
    shape := DrawShapeFromLua(L, 1)

    lua.pushnumber(L, lua.Number(shape.pivot.x))
    lua.pushnumber(L, lua.Number(shape.pivot.y))

    return 2
}

@(private="file")
_get_pos :: proc "c" (L: ^lua.State) -> i32 {
    shape := DrawShapeFromLua(L, 1)

    lua.pushnumber(L, lua.Number(shape.position.x))
    lua.pushnumber(L, lua.Number(shape.position.y))

    return 2
}

@(private="file")
_get_rot :: proc "c" (L: ^lua.State) -> i32 {
    shape := DrawShapeFromLua(L, 1)

    lua.pushnumber(L, lua.Number(shape.rotation))

    return 1
}

@(private="file")
_get_scl :: proc "c" (L: ^lua.State) -> i32 {
    shape := DrawShapeFromLua(L, 1)

    lua.pushnumber(L, lua.Number(shape.scale.x))
    lua.pushnumber(L, lua.Number(shape.scale.y))

    return 2
}

@(private="file")
_get_visible :: proc "c" (L: ^lua.State) -> i32 {
    shape := DrawShapeFromLua(L, 1)

    lua.pushboolean(L, b32(shape.visible))

    return 1
}

@(private="file")
_set_piv :: proc "c" (L: ^lua.State) -> i32 {
    shape := DrawShapeFromLua(L, 1)

    shape.pivot.x = f32(lua.tonumber(L, 2))
    shape.pivot.y = f32(lua.tonumber(L, 3))

    return 0
}

@(private="file")
_set_pos :: proc "c" (L: ^lua.State) -> i32 {
    shape := DrawShapeFromLua(L, 1)

    shape.position.x = f32(lua.tonumber(L, 2))
    shape.position.y = f32(lua.tonumber(L, 3))

    return 0
}

@(private="file")
_set_rot :: proc "c" (L: ^lua.State) -> i32 {
    shape := DrawShapeFromLua(L, 1)

    shape.rotation = f32(lua.tonumber(L, 2))

    return 0
}

@(private="file")
_set_scl :: proc "c" (L: ^lua.State) -> i32 {
    shape := DrawShapeFromLua(L, 1)

    shape.scale.x = f32(lua.tonumber(L, 2))
    shape.scale.y = f32(lua.tonumber(L, 3))

    return 0
}

@(private="file")
_set_visible :: proc "c" (L: ^lua.State) -> i32 {
    shape := DrawShapeFromLua(L, 1)

    shape.visible = bool(lua.toboolean(L, 2))

    return 0
}

@(private="file")
__gc :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    shape := DrawShapeFromLua(L, 1)

    if ! shape.is_gone {
        shape.is_gone = true

        if shape.refs == 0 {
            DestroyDrawShape(shape)
        }
    }

    return 0
}
