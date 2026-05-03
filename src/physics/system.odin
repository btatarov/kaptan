package physics

import "core:c"
import "core:log"

import b2 "vendor:box2d"
import lua "vendor:lua/5.4"

import "../core"

PhysicsSystem :: struct {
    initialized:     bool,
    world:           b2.WorldId,
    substeps:        i32,
    units_per_meter: f32,
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

PhysicsSystemRequireReady :: proc "contextless" (L: ^lua.State) {
    if ! physics_system.initialized || ! b2.World_IsValid(physics_system.world) {
        lua.L_error(L, "KaptanPhysics.init() must be called before using physics")
    }
}

PhysicsLuaBind :: proc(L: ^lua.State) {
    @static reg_table: []lua.L_Reg = {
        { "clear",            _clear },
        { "destroy",          _destroy },
        { "getGravity",       _get_gravity },
        { "getSubsteps",      _get_substeps },
        { "getUnitsPerMeter", _get_units_per_meter },
        { "init",             _init },
        { "isReady",          _is_ready },
        { "setGravity",       _set_gravity },
        { "setSubsteps",      _set_substeps },
        { "setUnitsPerMeter", _set_units_per_meter },
        { nil, nil },
    }

    physics_system.substeps = DEFAULT_SUBSTEPS
    physics_system.units_per_meter = DEFAULT_UNITS_PER_METER

    core.LuaBindSingleton(L, "KaptanPhysics", &reg_table)
}

PhysicsLuaUnbind :: proc(L: ^lua.State) {
    PhysicsSystemDestroy()
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
