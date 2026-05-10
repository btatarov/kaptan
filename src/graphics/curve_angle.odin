package graphics

import "core:c"
import "core:log"
import "core:math"

import lua "vendor:lua/5.4"

import "../core"

AngleCurveKey :: struct {
    time:  f32,
    angle: f32,
    ease:  EaseKind,
}

AngleCurve :: struct {
    keys:          [dynamic]AngleCurveKey,
    shortest_path: bool,
}

AngleCurveLuaBind :: proc(L: ^lua.State) {
    @static static_reg_table: []lua.L_Reg = {
        { "new", _new },
        { nil, nil },
    }

    @static instance_reg_table: []lua.L_Reg = {
        { "addKey",          _add_key },
        { "clear",           _clear },
        { "getDuration",     _get_duration },
        { "getKeyCount",     _get_key_count },
        { "isShortestPath",  _is_shortest_path },
        { "removeKey",       _remove_key },
        { "sample",          _sample },
        { "setShortestPath", _set_shortest_path },
        { nil, nil },
    }

    core.LuaBindClass(L, "KaptanAngleCurve", &static_reg_table, &instance_reg_table, __gc)
}

AngleCurveLuaUnbind :: proc(L: ^lua.State) {
    // nothing to do
}

AngleCurveFromLua :: proc "contextless" (L: ^lua.State, idx: i32) -> ^AngleCurve {
    return (^AngleCurve)(core.LuaUserdataHandle(L, idx, "KaptanAngleCurveMT"))
}

@(private="file")
init_angle_curve :: proc(curve: ^AngleCurve) {
    log.debugf("KaptanAngleCurve: Init")
    curve.keys = make([dynamic]AngleCurveKey)
    curve.shortest_path = true
}

@(private="file")
destroy_angle_curve :: proc(curve: ^AngleCurve) {
    if curve == nil {
        return
    }

    log.debugf("KaptanAngleCurve: Destroy")
    delete(curve.keys)
    free(curve)
}

@(private="file")
check_angle_key_time :: proc "contextless" (L: ^lua.State, idx: i32) -> f32 {
    time := f32(lua.L_checknumber(L, idx))
    if time < 0 {
        lua.L_argerror(L, c.int(idx), "key time must be >= 0")
    }

    return time
}

@(private="file")
normalize_angle :: proc "contextless" (angle: f32) -> f32 {
    result := angle
    for result < 0 {
        result += 360
    }
    for result >= 360 {
        result -= 360
    }

    return result
}

@(private="file")
shortest_angle_delta :: proc "contextless" (from, to: f32) -> f32 {
    delta := to - from
    for delta > 180 {
        delta -= 360
    }
    for delta < -180 {
        delta += 360
    }

    return delta
}

@(private="file")
angle_curve_insert_key :: proc(curve: ^AngleCurve, key: AngleCurveKey) {
    insert_at := len(curve.keys)
    for existing, index in curve.keys {
        if key.time < existing.time {
            insert_at = index
            break
        }
    }

    append(&curve.keys, key)
    for i := len(curve.keys) - 1; i > insert_at; i -= 1 {
        curve.keys[i] = curve.keys[i - 1]
    }
    curve.keys[insert_at] = key
}

@(private="file")
angle_curve_duration :: proc "contextless" (curve: ^AngleCurve) -> f32 {
    if len(curve.keys) == 0 {
        return 0
    }

    return curve.keys[len(curve.keys) - 1].time
}

@(private="file")
angle_curve_sample_value :: proc "contextless" (curve: ^AngleCurve, time: f32) -> f32 {
    if len(curve.keys) == 0 {
        return 0
    }
    if len(curve.keys) == 1 || time <= curve.keys[0].time {
        return curve.keys[0].angle
    }

    last_index := len(curve.keys) - 1
    if time >= curve.keys[last_index].time {
        return curve.keys[last_index].angle
    }

    for i := 0; i < last_index; i += 1 {
        a := curve.keys[i]
        b := curve.keys[i + 1]
        if time <= b.time {
            duration := b.time - a.time
            if duration <= 0 {
                return b.angle
            }

            local_t := (time - a.time) / duration
            eased_t := EaseSample(a.ease, local_t)
            if curve.shortest_path {
                return normalize_angle(a.angle + shortest_angle_delta(a.angle, b.angle) * eased_t)
            }

            return math.lerp(a.angle, b.angle, eased_t)
        }
    }

    return curve.keys[last_index].angle
}

@(private="file")
_new :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    curve := new(AngleCurve)
    init_angle_curve(curve)

    handle := (^^AngleCurve)(lua.newuserdata(L, size_of(^AngleCurve)))
    handle^ = curve
    core.LuaSetClassMetatable(L, "KaptanAngleCurve")

    return 1
}

@(private="file")
_add_key :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    curve := AngleCurveFromLua(L, 1)
    time := check_angle_key_time(L, 2)
    angle := f32(lua.L_checknumber(L, 3))
    ease := EaseKind.Linear
    if ! lua.isnoneornil(L, 4) {
        ease = EaseKindFromLua(L, 4)
    }

    angle_curve_insert_key(curve, AngleCurveKey{time = time, angle = angle, ease = ease})

    return 0
}

@(private="file")
_clear :: proc "c" (L: ^lua.State) -> i32 {
    curve := AngleCurveFromLua(L, 1)
    clear(&curve.keys)

    return 0
}

@(private="file")
_get_duration :: proc "c" (L: ^lua.State) -> i32 {
    curve := AngleCurveFromLua(L, 1)
    lua.pushnumber(L, lua.Number(angle_curve_duration(curve)))

    return 1
}

@(private="file")
_get_key_count :: proc "c" (L: ^lua.State) -> i32 {
    curve := AngleCurveFromLua(L, 1)
    lua.pushinteger(L, lua.Integer(len(curve.keys)))

    return 1
}

@(private="file")
_is_shortest_path :: proc "c" (L: ^lua.State) -> i32 {
    curve := AngleCurveFromLua(L, 1)
    lua.pushboolean(L, b32(curve.shortest_path))

    return 1
}

@(private="file")
_remove_key :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    curve := AngleCurveFromLua(L, 1)
    index := int(lua.L_checkinteger(L, 2))
    if index < 1 || index > len(curve.keys) {
        return i32(lua.L_argerror(L, 2, "key index out of range"))
    }

    ordered_remove(&curve.keys, index - 1)

    return 0
}

@(private="file")
_sample :: proc "c" (L: ^lua.State) -> i32 {
    curve := AngleCurveFromLua(L, 1)
    time := f32(lua.L_checknumber(L, 2))
    lua.pushnumber(L, lua.Number(angle_curve_sample_value(curve, time)))

    return 1
}

@(private="file")
_set_shortest_path :: proc "c" (L: ^lua.State) -> i32 {
    curve := AngleCurveFromLua(L, 1)
    curve.shortest_path = bool(lua.toboolean(L, 2))

    return 0
}

@(private="file")
__gc :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    curve := AngleCurveFromLua(L, 1)
    destroy_angle_curve(curve)

    return 0
}
