package physics

import "core:c"
import "core:log"

import b2 "vendor:box2d"
import lua "vendor:lua/5.4"

import "../core"

PhysicsSystem :: struct {
    initialized:     bool,
    world:           b2.WorldId,
    bodies:          [dynamic]^PhysicsBody,
    substeps:        i32,
    units_per_meter: f32,
}

PhysicsQueryContext :: struct {
    shapes: [dynamic]^PhysicsShape,
}

@(private="file") physics_system: PhysicsSystem
@(private="file") DEFAULT_SUBSTEPS: i32 = 2
@(private="file") DEFAULT_UNITS_PER_METER: f32 = 64

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

    invalidate_physics_bodies()
    b2.DestroyWorld(physics_system.world)
    physics_system.initialized = false
    physics_system.world = {}
}

PhysicsSystemClear :: proc() {
    if ! physics_system.initialized {
        return
    }

    gravity := b2.World_GetGravity(physics_system.world)
    PhysicsSystemDestroy()
    PhysicsSystemInit()
    b2.World_SetGravity(physics_system.world, gravity)
}

PhysicsSystemUpdate :: proc(dt: f32) {
    if ! physics_system.initialized || dt <= 0 {
        return
    }

    b2.World_Step(physics_system.world, dt, c.int(physics_system.substeps))
}

PhysicsSystemStep :: proc "contextless" (L: ^lua.State, dt: f32) {
    PhysicsSystemRequireReady(L)

    if dt <= 0 {
        lua.L_argerror(L, 1, "dt must be > 0")
    }

    b2.World_Step(physics_system.world, dt, c.int(physics_system.substeps))
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
        { "getUnitsPerMeter", _get_units_per_meter },
        { "init",             _init },
        { "isReady",          _is_ready },
        { "queryAABB",        _query_aabb },
        { "raycast",          _raycast },
        { "setGravity",       _set_gravity },
        { "setSubsteps",      _set_substeps },
        { "setUnitsPerMeter", _set_units_per_meter },
        { "step",             _step },
        { nil, nil },
    }

    physics_system.substeps = DEFAULT_SUBSTEPS
    physics_system.units_per_meter = DEFAULT_UNITS_PER_METER
    physics_system.bodies = make([dynamic]^PhysicsBody)

    core.LuaBindSingleton(L, "KaptanPhysics", &reg_table)
}

PhysicsLuaUnbind :: proc(L: ^lua.State) {
    PhysicsSystemDestroy()
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
push_contact_pair_event :: proc(L: ^lua.State, kind: cstring, shape_id_a, shape_id_b: b2.ShapeId) {
    lua.createtable(L, 0, 3)
    event_idx := lua.gettop(L)

    set_event_kind(L, event_idx, kind)
    set_event_shape(L, event_idx, "shapeA", PhysicsShapeFromId(shape_id_a))
    set_event_shape(L, event_idx, "shapeB", PhysicsShapeFromId(shape_id_b))
}

@(private="file")
push_sensor_event :: proc(L: ^lua.State, kind: cstring, sensor_id, visitor_id: b2.ShapeId) {
    lua.createtable(L, 0, 3)
    event_idx := lua.gettop(L)

    set_event_kind(L, event_idx, kind)
    set_event_shape(L, event_idx, "sensor", PhysicsShapeFromId(sensor_id))
    set_event_shape(L, event_idx, "visitor", PhysicsShapeFromId(visitor_id))
}

@(private="file")
push_contact_hit_event :: proc(L: ^lua.State, event: b2.ContactHitEvent) {
    lua.createtable(L, 0, 9)
    event_idx := lua.gettop(L)

    set_event_kind(L, event_idx, "hit")
    set_event_shape(L, event_idx, "shapeA", PhysicsShapeFromId(event.shapeIdA))
    set_event_shape(L, event_idx, "shapeB", PhysicsShapeFromId(event.shapeIdB))
    set_event_number(L, event_idx, "x", event.point.x)
    set_event_number(L, event_idx, "y", event.point.y)
    set_event_number(L, event_idx, "normalX", event.normal.x)
    set_event_number(L, event_idx, "normalY", event.normal.y)
    set_event_number(L, event_idx, "approachSpeed", event.approachSpeed)
}

@(private="file")
query_filter_from_lua :: proc "contextless" (L: ^lua.State, idx: i32) -> b2.QueryFilter {
    filter := b2.DefaultQueryFilter()
    if idx == 0 || lua.isnoneornil(L, idx) {
        return filter
    }

    if ! lua.istable(L, idx) {
        lua.L_typeerror(L, idx, "table")
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
        lua.rawseti(L, -2, lua.Integer(index + 1))
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

    events := b2.World_GetContactEvents(physics_system.world)
    count := events.beginCount + events.endCount + events.hitCount
    lua.createtable(L, c.int(count), 0)

    out_idx := i32(1)
    for i := i32(0); i < events.beginCount; i += 1 {
        event := events.beginEvents[i]
        push_contact_pair_event(L, "begin", event.shapeIdA, event.shapeIdB)
        lua.rawseti(L, -2, lua.Integer(out_idx))
        out_idx += 1
    }

    for i := i32(0); i < events.endCount; i += 1 {
        event := events.endEvents[i]
        push_contact_pair_event(L, "end", event.shapeIdA, event.shapeIdB)
        lua.rawseti(L, -2, lua.Integer(out_idx))
        out_idx += 1
    }

    for i := i32(0); i < events.hitCount; i += 1 {
        push_contact_hit_event(L, events.hitEvents[i])
        lua.rawseti(L, -2, lua.Integer(out_idx))
        out_idx += 1
    }

    return 1
}

@(private="file")
_get_sensor_events :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    PhysicsSystemRequireReady(L)

    events := b2.World_GetSensorEvents(physics_system.world)
    count := events.beginCount + events.endCount
    lua.createtable(L, c.int(count), 0)

    out_idx := i32(1)
    for i := i32(0); i < events.beginCount; i += 1 {
        event := events.beginEvents[i]
        push_sensor_event(L, "begin", event.sensorShapeId, event.visitorShapeId)
        lua.rawseti(L, -2, lua.Integer(out_idx))
        out_idx += 1
    }

    for i := i32(0); i < events.endCount; i += 1 {
        event := events.endEvents[i]
        push_sensor_event(L, "end", event.sensorShapeId, event.visitorShapeId)
        lua.rawseti(L, -2, lua.Integer(out_idx))
        out_idx += 1
    }

    return 1
}

@(private="file")
_get_substeps :: proc "c" (L: ^lua.State) -> i32 {
    lua.pushinteger(L, lua.Integer(physics_system.substeps))
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
_is_ready :: proc "c" (L: ^lua.State) -> i32 {
    lua.pushboolean(L, b32(physics_system.initialized && b2.World_IsValid(physics_system.world)))
    return 1
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
_set_substeps :: proc "c" (L: ^lua.State) -> i32 {
    substeps := i32(lua.L_checkinteger(L, 1))
    if substeps < 1 {
        return i32(lua.L_argerror(L, 1, "substeps must be >= 1"))
    }

    physics_system.substeps = substeps

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
    PhysicsSystemStep(L, f32(lua.L_checknumber(L, 1)))
    return 0
}
