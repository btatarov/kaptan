package physics

import "core:c"
import "core:log"
import "core:math"

import b2 "vendor:box2d"
import lua "vendor:lua/jit"
import rl "vendor:raylib"

import "../core"

PhysicsSystem :: struct {
    initialized:     bool,
    world:           b2.WorldId,
    bodies:          [dynamic]^PhysicsBody,
    contact_events:  [dynamic]PhysicsContactEvent,
    sensor_events:   [dynamic]PhysicsSensorEvent,
    substeps:        i32,
    units_per_meter: f32,
    tick_rate:       f32,
    accumulator:     f32,
    debug_draw:      bool,
    paused:          bool,
}

PhysicsQueryContext :: struct {
    shapes: [dynamic]^PhysicsShape,
}

PhysicsContactEventKind :: enum {
    Begin,
    End,
    Hit,
}

PhysicsSensorEventKind :: enum {
    Begin,
    End,
}

PhysicsContactEvent :: struct {
    kind:           PhysicsContactEventKind,
    shape_a:        ^PhysicsShape,
    shape_b:        ^PhysicsShape,
    point:          b2.Vec2,
    normal:         b2.Vec2,
    approach_speed: f32,
}

PhysicsSensorEvent :: struct {
    kind:    PhysicsSensorEventKind,
    sensor:  ^PhysicsShape,
    visitor: ^PhysicsShape,
}

@(private="file") physics_system: PhysicsSystem
@(private="file") DEFAULT_SUBSTEPS: i32 = 2
@(private="file") DEFAULT_UNITS_PER_METER: f32 = 64
@(private="file") DEFAULT_TICK_RATE: f32 = 60
@(private="file") MAX_TICK_RATE: f32 = 1000
@(private="file") MAX_FRAME_TIME: f32 = 0.25

PhysicsSystemInit :: proc() {
    if physics_system.initialized {
        return
    }

    log.debugf("KaptanPhysics: Init")

    if physics_system.units_per_meter <= 0 {
        physics_system.units_per_meter = DEFAULT_UNITS_PER_METER
    }

    if physics_system.substeps < 1 {
        physics_system.substeps = DEFAULT_SUBSTEPS
    }

    if physics_system.tick_rate <= 0 {
        physics_system.tick_rate = DEFAULT_TICK_RATE
    }

    physics_system.accumulator = 0

    b2.SetLengthUnitsPerMeter(physics_system.units_per_meter)

    world_def := b2.DefaultWorldDef()
    world_def.gravity = b2.Vec2{0, 0}

    physics_system.world = b2.CreateWorld(world_def)
    physics_system.initialized = b2.World_IsValid(physics_system.world)
}

PhysicsSystemDestroy :: proc() {
    if ! physics_system.initialized {
        return
    }

    log.debugf("KaptanPhysics: Destroy")

    clear_contact_events()
    clear_sensor_events()
    invalidate_physics_bodies()
    b2.DestroyWorld(physics_system.world)
    physics_system.initialized = false
    physics_system.world = {}
    physics_system.accumulator = 0
    physics_system.paused = false
}

PhysicsSystemClear :: proc() {
    if ! physics_system.initialized {
        return
    }

    gravity := b2.World_GetGravity(physics_system.world)
    paused := physics_system.paused
    PhysicsSystemDestroy()
    PhysicsSystemInit()
    b2.World_SetGravity(physics_system.world, gravity)
    physics_system.paused = paused
}

PhysicsSystemUpdate :: proc(dt: f32) {
    if ! physics_system.initialized || dt <= 0 {
        return
    }

    clear_contact_events()
    clear_sensor_events()

    if physics_system.paused {
        return
    }

    frame_time := min(dt, MAX_FRAME_TIME)
    tick_dt := 1 / physics_system.tick_rate
    physics_system.accumulator += frame_time

    for physics_system.accumulator >= tick_dt {
        step_world(tick_dt)
        physics_system.accumulator -= tick_dt
    }
}

PhysicsSystemIsDebugDraw :: proc "contextless" () -> bool {
    return physics_system.debug_draw
}

PhysicsSystemDebugDraw :: proc() {
    if ! physics_system.initialized || ! physics_system.debug_draw {
        return
    }

    draw := b2.DefaultDebugDraw()
    draw.DrawPolygonFcn = debug_draw_polygon
    draw.DrawSolidPolygonFcn = debug_draw_solid_polygon
    draw.DrawCircleFcn = debug_draw_circle
    draw.DrawSolidCircleFcn = debug_draw_solid_circle
    draw.DrawSolidCapsuleFcn = debug_draw_solid_capsule
    draw.DrawSegmentFcn = debug_draw_segment
    draw.DrawTransformFcn = debug_draw_transform
    draw.DrawPointFcn = debug_draw_point
    draw.drawShapes = true
    draw.drawJoints = true
    draw.drawBounds = false
    draw.drawContacts = true
    draw.drawContactNormals = true

    b2.World_Draw(physics_system.world, &draw)
}

PhysicsSystemStep :: proc(L: ^lua.State, dt: f32) {
    PhysicsSystemRequireReady(L)

    if dt <= 0 {
        lua.L_argerror(L, 1, "dt must be > 0")
    }

    if physics_system.paused {
        return
    }

    step_world(dt)
}

PhysicsSystemPause :: proc "contextless" () {
    physics_system.paused = true
    physics_system.accumulator = 0
}

PhysicsSystemResume :: proc "contextless" () {
    physics_system.paused = false
    physics_system.accumulator = 0
}

PhysicsSystemIsPaused :: proc "contextless" () -> bool {
    return physics_system.paused
}

PhysicsSystemRequireReady :: proc "contextless" (L: ^lua.State) {
    if ! physics_system.initialized || ! b2.World_IsValid(physics_system.world) {
        lua.L_error(L, "KaptanPhysics.init() must be called before using physics")
    }
}

PhysicsSystemGetWorld :: proc "contextless" () -> b2.WorldId {
    return physics_system.world
}

PhysicsLuaBind :: proc(L: ^lua.State) {
    @static reg_table: []lua.L_Reg = {
        { "clear",            _clear },
        { "destroy",          _destroy },
        { "getGravity",       _get_gravity },
        { "getContactEvents", _get_contact_events },
        { "getSensorEvents",  _get_sensor_events },
        { "getSubsteps",      _get_substeps },
        { "getTickRate",      _get_tick_rate },
        { "getUnitsPerMeter", _get_units_per_meter },
        { "init",             _init },
        { "isDebugDraw",      _is_debug_draw },
        { "isPaused",         _is_paused },
        { "isReady",          _is_ready },
        { "pause",            _pause },
        { "queryAABB",        _query_aabb },
        { "raycast",          _raycast },
        { "resume",           _resume },
        { "setGravity",       _set_gravity },
        { "setDebugDraw",     _set_debug_draw },
        { "setSubsteps",      _set_substeps },
        { "setTickRate",      _set_tick_rate },
        { "setUnitsPerMeter", _set_units_per_meter },
        { "step",             _step },
        { nil, nil },
    }

    physics_system.substeps = DEFAULT_SUBSTEPS
    physics_system.units_per_meter = DEFAULT_UNITS_PER_METER
    physics_system.tick_rate = DEFAULT_TICK_RATE
    physics_system.accumulator = 0
    physics_system.debug_draw = false
    physics_system.paused = false
    physics_system.bodies = make([dynamic]^PhysicsBody)
    physics_system.contact_events = make([dynamic]PhysicsContactEvent)
    physics_system.sensor_events = make([dynamic]PhysicsSensorEvent)

    core.LuaBindSingleton(L, "KaptanPhysics", &reg_table)
}

PhysicsLuaUnbind :: proc(L: ^lua.State) {
    PhysicsSystemDestroy()
    clear_contact_events()
    clear_sensor_events()
    delete(physics_system.contact_events)
    delete(physics_system.sensor_events)
    delete(physics_system.bodies)
}

PhysicsSystemRegisterBody :: proc(body: ^PhysicsBody) {
    append(&physics_system.bodies, body)
}

PhysicsSystemUnregisterBody :: proc(body: ^PhysicsBody) {
    for existing, index in physics_system.bodies {
        if existing == body {
            ordered_remove(&physics_system.bodies, index)
            return
        }
    }
}

@(private="file")
invalidate_physics_bodies :: proc() {
    for body in physics_system.bodies {
        PhysicsBodyInvalidate(body)
    }

    clear(&physics_system.bodies)
}

@(private="file")
add_shape_event_ref :: proc(shape: ^PhysicsShape) -> ^PhysicsShape {
    if PhysicsShapeIsValid(shape) {
        PhysicsShapeAddRef(shape)
        return shape
    }

    return nil
}

@(private="file")
release_shape_event_ref :: proc(shape: ^PhysicsShape) {
    if shape != nil {
        PhysicsShapeReleaseRef(shape)
    }
}

@(private="file")
clear_contact_events :: proc() {
    for event in physics_system.contact_events {
        release_shape_event_ref(event.shape_a)
        release_shape_event_ref(event.shape_b)
    }
    clear(&physics_system.contact_events)
}

@(private="file")
clear_sensor_events :: proc() {
    for event in physics_system.sensor_events {
        release_shape_event_ref(event.sensor)
        release_shape_event_ref(event.visitor)
    }
    clear(&physics_system.sensor_events)
}

@(private="file")
step_world :: proc(dt: f32) {
    b2.World_Step(physics_system.world, dt, c.int(physics_system.substeps))
    accumulate_contact_events()
    accumulate_sensor_events()
}

@(private="file")
accumulate_contact_events :: proc() {
    events := b2.World_GetContactEvents(physics_system.world)
    for i := i32(0); i < events.beginCount; i += 1 {
        event := events.beginEvents[i]
        append(&physics_system.contact_events, PhysicsContactEvent{
            kind = .Begin,
            shape_a = add_shape_event_ref(PhysicsShapeFromId(event.shapeIdA)),
            shape_b = add_shape_event_ref(PhysicsShapeFromId(event.shapeIdB)),
        })
    }

    for i := i32(0); i < events.endCount; i += 1 {
        event := events.endEvents[i]
        append(&physics_system.contact_events, PhysicsContactEvent{
            kind = .End,
            shape_a = add_shape_event_ref(PhysicsShapeFromId(event.shapeIdA)),
            shape_b = add_shape_event_ref(PhysicsShapeFromId(event.shapeIdB)),
        })
    }

    for i := i32(0); i < events.hitCount; i += 1 {
        event := events.hitEvents[i]
        append(&physics_system.contact_events, PhysicsContactEvent{
            kind = .Hit,
            shape_a = add_shape_event_ref(PhysicsShapeFromId(event.shapeIdA)),
            shape_b = add_shape_event_ref(PhysicsShapeFromId(event.shapeIdB)),
            point = event.point,
            normal = event.normal,
            approach_speed = event.approachSpeed,
        })
    }
}

@(private="file")
accumulate_sensor_events :: proc() {
    events := b2.World_GetSensorEvents(physics_system.world)
    for i := i32(0); i < events.beginCount; i += 1 {
        event := events.beginEvents[i]
        append(&physics_system.sensor_events, PhysicsSensorEvent{
            kind = .Begin,
            sensor = add_shape_event_ref(PhysicsShapeFromId(event.sensorShapeId)),
            visitor = add_shape_event_ref(PhysicsShapeFromId(event.visitorShapeId)),
        })
    }

    for i := i32(0); i < events.endCount; i += 1 {
        event := events.endEvents[i]
        append(&physics_system.sensor_events, PhysicsSensorEvent{
            kind = .End,
            sensor = add_shape_event_ref(PhysicsShapeFromId(event.sensorShapeId)),
            visitor = add_shape_event_ref(PhysicsShapeFromId(event.visitorShapeId)),
        })
    }
}

@(private="file")
push_shape_or_nil :: proc(L: ^lua.State, shape: ^PhysicsShape) {
    if PhysicsShapeIsValid(shape) {
        PhysicsShapePushLuaRef(L, shape)
    } else {
        lua.pushnil(L)
    }
}

@(private="file")
set_event_shape :: proc(L: ^lua.State, table_idx: i32, name: cstring, shape: ^PhysicsShape) {
    push_shape_or_nil(L, shape)
    lua.setfield(L, table_idx, name)
}

@(private="file")
set_event_number :: proc(L: ^lua.State, table_idx: i32, name: cstring, value: f32) {
    lua.pushnumber(L, lua.Number(value))
    lua.setfield(L, table_idx, name)
}

@(private="file")
set_event_kind :: proc(L: ^lua.State, table_idx: i32, name: cstring) {
    lua.pushstring(L, name)
    lua.setfield(L, table_idx, "kind")
}

@(private="file")
push_accumulated_contact_pair_event :: proc(L: ^lua.State, kind: cstring, shape_a, shape_b: ^PhysicsShape) {
    lua.createtable(L, 0, 3)
    event_idx := lua.gettop(L)

    set_event_kind(L, event_idx, kind)
    set_event_shape(L, event_idx, "shapeA", shape_a)
    set_event_shape(L, event_idx, "shapeB", shape_b)
}

@(private="file")
push_accumulated_sensor_event :: proc(L: ^lua.State, kind: cstring, sensor, visitor: ^PhysicsShape) {
    lua.createtable(L, 0, 3)
    event_idx := lua.gettop(L)

    set_event_kind(L, event_idx, kind)
    set_event_shape(L, event_idx, "sensor", sensor)
    set_event_shape(L, event_idx, "visitor", visitor)
}

@(private="file")
push_accumulated_contact_hit_event :: proc(L: ^lua.State, event: PhysicsContactEvent) {
    lua.createtable(L, 0, 9)
    event_idx := lua.gettop(L)

    set_event_kind(L, event_idx, "hit")
    set_event_shape(L, event_idx, "shapeA", event.shape_a)
    set_event_shape(L, event_idx, "shapeB", event.shape_b)
    set_event_number(L, event_idx, "x", event.point.x)
    set_event_number(L, event_idx, "y", event.point.y)
    set_event_number(L, event_idx, "normalX", event.normal.x)
    set_event_number(L, event_idx, "normalY", event.normal.y)
    set_event_number(L, event_idx, "approachSpeed", event.approach_speed)
}

@(private="file")
query_filter_from_lua :: proc "contextless" (L: ^lua.State, idx: i32) -> b2.QueryFilter {
    filter := b2.DefaultQueryFilter()
    if idx == 0 || lua.isnoneornil(L, idx) {
        return filter
    }

    if ! lua.istable(L, idx) {
        lua.L_error(L, "bad argument #%d (table expected)", idx)
    }

    abs_idx := core.LuaGetAbsIndex(L, idx)

    lua.getfield(L, abs_idx, "category")
    if ! lua.isnil(L, -1) {
        filter.categoryBits = u64(lua.L_checkinteger(L, -1))
    }
    lua.pop(L, 1)

    lua.getfield(L, abs_idx, "mask")
    if ! lua.isnil(L, -1) {
        filter.maskBits = u64(lua.L_checkinteger(L, -1))
    }
    lua.pop(L, 1)

    return filter
}

@(private="file")
push_shape_refs_array :: proc(L: ^lua.State, shapes: []^PhysicsShape) {
    lua.createtable(L, c.int(len(shapes)), 0)
    for shape, index in shapes {
        PhysicsShapePushLuaRef(L, shape)
        lua.rawseti(L, -2, i32(index + 1))
    }
}

@(private="file")
overlap_aabb_callback :: proc "c" (shape_id: b2.ShapeId, ctx: rawptr) -> bool {
    context = core.GetDefaultContext()

    query := (^PhysicsQueryContext)(ctx)
    shape := PhysicsShapeFromId(shape_id)
    if PhysicsShapeIsValid(shape) {
        append(&query.shapes, shape)
    }

    return true
}

@(private="file")
push_ray_result :: proc(L: ^lua.State, result: b2.RayResult) {
    if ! result.hit {
        lua.pushnil(L)
        return
    }

    lua.createtable(L, 0, 8)
    result_idx := lua.gettop(L)

    set_event_shape(L, result_idx, "shape", PhysicsShapeFromId(result.shapeId))
    set_event_number(L, result_idx, "x", result.point.x)
    set_event_number(L, result_idx, "y", result.point.y)
    set_event_number(L, result_idx, "normalX", result.normal.x)
    set_event_number(L, result_idx, "normalY", result.normal.y)
    set_event_number(L, result_idx, "fraction", result.fraction)
}

@(private="file")
debug_color :: proc "contextless" (color: b2.HexColor, alpha: u8 = 255) -> rl.Color {
    value := u32(color)
    return rl.Color{
        u8((value >> 16) & 0xff),
        u8((value >> 8) & 0xff),
        u8(value & 0xff),
        alpha,
    }
}

@(private="file")
debug_vec :: proc "contextless" (v: b2.Vec2) -> rl.Vector2 {
    return rl.Vector2{v.x, v.y}
}

@(private="file")
debug_draw_polyline :: proc "contextless" (vertices: [^]b2.Vec2, vertex_count: c.int, color: rl.Color, closed: bool) {
    if vertex_count < 2 {
        return
    }

    for i := c.int(0); i < vertex_count - 1; i += 1 {
        rl.DrawLineEx(debug_vec(vertices[i]), debug_vec(vertices[i + 1]), 1.5, color)
    }

    if closed {
        rl.DrawLineEx(debug_vec(vertices[vertex_count - 1]), debug_vec(vertices[0]), 1.5, color)
    }
}

@(private="file")
debug_draw_polygon :: proc "c" (vertices: [^]b2.Vec2, vertex_count: c.int, color: b2.HexColor, ctx: rawptr) {
    debug_draw_polyline(vertices, vertex_count, debug_color(color), true)
}

@(private="file")
debug_draw_solid_polygon :: proc "c" (transform: b2.Transform, vertices: [^]b2.Vec2, vertex_count: c.int, radius: f32, color: b2.HexColor, ctx: rawptr) {
    if vertex_count < 2 {
        return
    }

    fill := debug_color(color, 48)
    outline := debug_color(color)
    origin := debug_vec(b2.TransformPoint(transform, vertices[0]))
    for i := c.int(1); i < vertex_count - 1; i += 1 {
        rl.DrawTriangle(origin, debug_vec(b2.TransformPoint(transform, vertices[i + 1])), debug_vec(b2.TransformPoint(transform, vertices[i])), fill)
    }

    for i := c.int(0); i < vertex_count - 1; i += 1 {
        rl.DrawLineEx(debug_vec(b2.TransformPoint(transform, vertices[i])), debug_vec(b2.TransformPoint(transform, vertices[i + 1])), 1.5, outline)
    }
    rl.DrawLineEx(debug_vec(b2.TransformPoint(transform, vertices[vertex_count - 1])), debug_vec(b2.TransformPoint(transform, vertices[0])), 1.5, outline)
}

@(private="file")
debug_draw_circle :: proc "c" (center: b2.Vec2, radius: f32, color: b2.HexColor, ctx: rawptr) {
    rl.DrawCircleLinesV(debug_vec(center), radius, debug_color(color))
}

@(private="file")
debug_draw_solid_circle :: proc "c" (transform: b2.Transform, radius: f32, color: b2.HexColor, ctx: rawptr) {
    center := debug_vec(transform.p)
    fill := debug_color(color, 48)
    outline := debug_color(color)
    axis := debug_vec(transform.p + b2.RotateVector(transform.q, b2.Vec2{radius, 0}))
    rl.DrawCircleV(center, radius, fill)
    rl.DrawCircleLinesV(center, radius, outline)
    rl.DrawLineEx(center, axis, 1.5, outline)
}

@(private="file")
debug_draw_solid_capsule :: proc "c" (p1, p2: b2.Vec2, radius: f32, color: b2.HexColor, ctx: rawptr) {
    draw_color := debug_color(color)
    fill := debug_color(color, 48)
    a := debug_vec(p1)
    b := debug_vec(p2)
    direction := p2 - p1
    length := math.sqrt(direction.x * direction.x + direction.y * direction.y)

    if length <= 0 {
        rl.DrawCircleV(a, radius, fill)
        rl.DrawCircleLinesV(a, radius, draw_color)
        return
    }

    normal := rl.Vector2{-direction.y / length * radius, direction.x / length * radius}
    rl.DrawTriangle(rl.Vector2{a.x + normal.x, a.y + normal.y}, rl.Vector2{b.x + normal.x, b.y + normal.y}, rl.Vector2{b.x - normal.x, b.y - normal.y}, fill)
    rl.DrawTriangle(rl.Vector2{a.x + normal.x, a.y + normal.y}, rl.Vector2{b.x - normal.x, b.y - normal.y}, rl.Vector2{a.x - normal.x, a.y - normal.y}, fill)
    rl.DrawCircleV(a, radius, fill)
    rl.DrawCircleV(b, radius, fill)
    rl.DrawCircleLinesV(a, radius, draw_color)
    rl.DrawCircleLinesV(b, radius, draw_color)
    rl.DrawLineEx(rl.Vector2{a.x + normal.x, a.y + normal.y}, rl.Vector2{b.x + normal.x, b.y + normal.y}, 1.5, draw_color)
    rl.DrawLineEx(rl.Vector2{a.x - normal.x, a.y - normal.y}, rl.Vector2{b.x - normal.x, b.y - normal.y}, 1.5, draw_color)
}

@(private="file")
debug_draw_segment :: proc "c" (p1, p2: b2.Vec2, color: b2.HexColor, ctx: rawptr) {
    rl.DrawLineEx(debug_vec(p1), debug_vec(p2), 1.5, debug_color(color))
}

@(private="file")
debug_draw_transform :: proc "c" (transform: b2.Transform, ctx: rawptr) {
    origin := transform.p
    x_axis := origin + b2.RotateVector(transform.q, b2.Vec2{24, 0})
    y_axis := origin + b2.RotateVector(transform.q, b2.Vec2{0, 24})
    rl.DrawLineEx(debug_vec(origin), debug_vec(x_axis), 2, rl.RED)
    rl.DrawLineEx(debug_vec(origin), debug_vec(y_axis), 2, rl.GREEN)
}

@(private="file")
debug_draw_point :: proc "c" (p: b2.Vec2, size: f32, color: b2.HexColor, ctx: rawptr) {
    rl.DrawCircleV(debug_vec(p), max(size * 0.5, 1), debug_color(color))
}

@(private="file")
_clear :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    PhysicsSystemClear()
    return 0
}

@(private="file")
_destroy :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    PhysicsSystemDestroy()
    return 0
}

@(private="file")
_get_gravity :: proc "c" (L: ^lua.State) -> i32 {
    PhysicsSystemRequireReady(L)

    gravity := b2.World_GetGravity(physics_system.world)
    lua.pushnumber(L, lua.Number(gravity.x))
    lua.pushnumber(L, lua.Number(gravity.y))

    return 2
}

@(private="file")
_get_contact_events :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    PhysicsSystemRequireReady(L)

    lua.createtable(L, c.int(len(physics_system.contact_events)), 0)

    out_idx := i32(1)
    for event in physics_system.contact_events {
        switch event.kind {
        case .Begin:
            push_accumulated_contact_pair_event(L, "begin", event.shape_a, event.shape_b)
        case .End:
            push_accumulated_contact_pair_event(L, "end", event.shape_a, event.shape_b)
        case .Hit:
            push_accumulated_contact_hit_event(L, event)
        }
        lua.rawseti(L, -2, out_idx)
        out_idx += 1
    }
    clear_contact_events()

    return 1
}

@(private="file")
_get_sensor_events :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    PhysicsSystemRequireReady(L)

    lua.createtable(L, c.int(len(physics_system.sensor_events)), 0)

    out_idx := i32(1)
    for event in physics_system.sensor_events {
        switch event.kind {
        case .Begin:
            push_accumulated_sensor_event(L, "begin", event.sensor, event.visitor)
        case .End:
            push_accumulated_sensor_event(L, "end", event.sensor, event.visitor)
        }
        lua.rawseti(L, -2, out_idx)
        out_idx += 1
    }
    clear_sensor_events()

    return 1
}

@(private="file")
_get_substeps :: proc "c" (L: ^lua.State) -> i32 {
    lua.pushinteger(L, lua.Integer(physics_system.substeps))
    return 1
}

@(private="file")
_get_tick_rate :: proc "c" (L: ^lua.State) -> i32 {
    lua.pushnumber(L, lua.Number(physics_system.tick_rate))
    return 1
}

@(private="file")
_get_units_per_meter :: proc "c" (L: ^lua.State) -> i32 {
    lua.pushnumber(L, lua.Number(physics_system.units_per_meter))
    return 1
}

@(private="file")
_init :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    PhysicsSystemInit()
    return 0
}

@(private="file")
_is_debug_draw :: proc "c" (L: ^lua.State) -> i32 {
    lua.pushboolean(L, b32(physics_system.debug_draw))
    return 1
}

@(private="file")
_is_paused :: proc "c" (L: ^lua.State) -> i32 {
    lua.pushboolean(L, b32(PhysicsSystemIsPaused()))
    return 1
}

@(private="file")
_is_ready :: proc "c" (L: ^lua.State) -> i32 {
    lua.pushboolean(L, b32(physics_system.initialized && b2.World_IsValid(physics_system.world)))
    return 1
}

@(private="file")
_pause :: proc "c" (L: ^lua.State) -> i32 {
    PhysicsSystemPause()
    return 0
}

@(private="file")
_query_aabb :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    PhysicsSystemRequireReady(L)

    x := f32(lua.L_checknumber(L, 1))
    y := f32(lua.L_checknumber(L, 2))
    width := f32(lua.L_checknumber(L, 3))
    height := f32(lua.L_checknumber(L, 4))
    if width <= 0 {
        return i32(lua.L_argerror(L, 3, "query width must be > 0"))
    }
    if height <= 0 {
        return i32(lua.L_argerror(L, 4, "query height must be > 0"))
    }

    half_width := width * 0.5
    half_height := height * 0.5
    aabb := b2.AABB{
        lowerBound = b2.Vec2{x - half_width, y - half_height},
        upperBound = b2.Vec2{x + half_width, y + half_height},
    }
    filter := query_filter_from_lua(L, 5)
    query := PhysicsQueryContext{shapes = make([dynamic]^PhysicsShape, allocator = context.temp_allocator)}
    _ = b2.World_OverlapAABB(physics_system.world, aabb, filter, overlap_aabb_callback, &query)
    push_shape_refs_array(L, query.shapes[:])

    return 1
}

@(private="file")
_raycast :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    PhysicsSystemRequireReady(L)

    start := b2.Vec2{f32(lua.L_checknumber(L, 1)), f32(lua.L_checknumber(L, 2))}
    end := b2.Vec2{f32(lua.L_checknumber(L, 3)), f32(lua.L_checknumber(L, 4))}
    translation := b2.Vec2{end.x - start.x, end.y - start.y}
    if translation.x == 0 && translation.y == 0 {
        return i32(lua.L_argerror(L, 3, "raycast end point must differ from start point"))
    }

    filter := query_filter_from_lua(L, 5)
    result := b2.World_CastRayClosest(physics_system.world, start, translation, filter)
    push_ray_result(L, result)

    return 1
}

@(private="file")
_resume :: proc "c" (L: ^lua.State) -> i32 {
    PhysicsSystemResume()
    return 0
}

@(private="file")
_set_gravity :: proc "c" (L: ^lua.State) -> i32 {
    PhysicsSystemRequireReady(L)

    gravity := b2.Vec2{
        f32(lua.L_checknumber(L, 1)),
        f32(lua.L_checknumber(L, 2)),
    }
    b2.World_SetGravity(physics_system.world, gravity)

    return 0
}

@(private="file")
_set_debug_draw :: proc "c" (L: ^lua.State) -> i32 {
    physics_system.debug_draw = bool(lua.toboolean(L, 1))
    return 0
}

@(private="file")
_set_substeps :: proc "c" (L: ^lua.State) -> i32 {
    substeps := i32(lua.L_checkinteger(L, 1))
    if substeps < 1 {
        return i32(lua.L_argerror(L, 1, "substeps must be >= 1"))
    }

    physics_system.substeps = substeps

    return 0
}

@(private="file")
_set_tick_rate :: proc "c" (L: ^lua.State) -> i32 {
    tick_rate := f32(lua.L_checknumber(L, 1))
    if tick_rate <= 0 {
        return i32(lua.L_argerror(L, 1, "tick rate must be > 0"))
    }
    if tick_rate > MAX_TICK_RATE {
        return i32(lua.L_argerror(L, 1, "tick rate must be <= 1000"))
    }

    physics_system.tick_rate = tick_rate
    physics_system.accumulator = 0

    return 0
}

@(private="file")
_set_units_per_meter :: proc "c" (L: ^lua.State) -> i32 {
    if physics_system.initialized {
        return i32(lua.L_error(L, "KaptanPhysics.setUnitsPerMeter must be called before KaptanPhysics.init()"))
    }

    units_per_meter := f32(lua.L_checknumber(L, 1))
    if units_per_meter <= 0 {
        return i32(lua.L_argerror(L, 1, "units per meter must be > 0"))
    }

    physics_system.units_per_meter = units_per_meter
    b2.SetLengthUnitsPerMeter(units_per_meter)

    return 0
}

@(private="file")
_step :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    PhysicsSystemStep(L, f32(lua.L_checknumber(L, 1)))
    return 0
}
