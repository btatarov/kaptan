package graphics

import "core:c"
import "core:log"
import "core:math"

import lua "vendor:lua/5.4"

import "../core"

CurveKey :: struct {
    time:  f32,
    value: f32,
    ease:  EaseKind,
}

Curve :: struct {
    keys: [dynamic]CurveKey,
}

CurveLuaBind :: proc(L: ^lua.State) {
    @static static_reg_table: []lua.L_Reg = {
        { "new", _new },
        { nil, nil },
    }

    @static instance_reg_table: []lua.L_Reg = {
        { "addKey",      _add_key },
        { "clear",       _clear },
        { "getDuration", _get_duration },
        { "getKeyCount", _get_key_count },
        { "removeKey",   _remove_key },
        { "sample",      _sample },
        { nil, nil },
    }

    core.LuaBindClass(L, "KaptanAnimationCurve", &static_reg_table, &instance_reg_table, __gc)
}

CurveLuaUnbind :: proc(L: ^lua.State) {
    // nothing to do
}

CurveFromLua :: proc "contextless" (L: ^lua.State, idx: i32) -> ^Curve {
    return (^Curve)(core.LuaUserdataHandle(L, idx, "KaptanAnimationCurveMT"))
}

@(private="file")
init_curve :: proc(curve: ^Curve) {
    log.debugf("KaptanAnimationCurve: Init")
    curve.keys = make([dynamic]CurveKey)
}

@(private="file")
destroy_curve :: proc(curve: ^Curve) {
    if curve == nil {
        return
    }

    log.debugf("KaptanAnimationCurve: Destroy")
    delete(curve.keys)
    free(curve)
}

@(private="file")
check_key_time :: proc "contextless" (L: ^lua.State, idx: i32) -> f32 {
    time := f32(lua.L_checknumber(L, idx))
    if time < 0 {
        lua.L_argerror(L, c.int(idx), "key time must be >= 0")
    }

    return time
}

@(private="file")
curve_insert_key :: proc(curve: ^Curve, key: CurveKey) {
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
curve_remove_key :: proc(curve: ^Curve, index: int) {
    ordered_remove(&curve.keys, index)
}

@(private="file")
curve_duration :: proc "contextless" (curve: ^Curve) -> f32 {
    if len(curve.keys) == 0 {
        return 0
    }

    return curve.keys[len(curve.keys) - 1].time
}

@(private="file")
curve_sample_value :: proc "contextless" (curve: ^Curve, time: f32) -> f32 {
    if len(curve.keys) == 0 {
        return 0
    }
    if len(curve.keys) == 1 || time <= curve.keys[0].time {
        return curve.keys[0].value
    }

    last_index := len(curve.keys) - 1
    if time >= curve.keys[last_index].time {
        return curve.keys[last_index].value
    }

    for i := 0; i < last_index; i += 1 {
        a := curve.keys[i]
        b := curve.keys[i + 1]
        if time <= b.time {
            duration := b.time - a.time
            if duration <= 0 {
                return b.value
            }

            local_t := (time - a.time) / duration
            eased_t := EaseSample(a.ease, local_t)
            return math.lerp(a.value, b.value, eased_t)
        }
    }

    return curve.keys[last_index].value
}

@(private="file")
_new :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    curve := new(Curve)
    init_curve(curve)

    handle := (^^Curve)(lua.newuserdata(L, size_of(^Curve)))
    handle^ = curve
    core.LuaSetClassMetatable(L, "KaptanAnimationCurve")

    return 1
}

@(private="file")
_add_key :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    curve := CurveFromLua(L, 1)
    time := check_key_time(L, 2)
    value := f32(lua.L_checknumber(L, 3))
    ease := EaseKind.Linear
    if ! lua.isnoneornil(L, 4) {
        ease = EaseKindFromLua(L, 4)
    }

    curve_insert_key(curve, CurveKey{time = time, value = value, ease = ease})

    return 0
}

@(private="file")
_clear :: proc "c" (L: ^lua.State) -> i32 {
    curve := CurveFromLua(L, 1)
    clear(&curve.keys)

    return 0
}

@(private="file")
_get_duration :: proc "c" (L: ^lua.State) -> i32 {
    curve := CurveFromLua(L, 1)
    lua.pushnumber(L, lua.Number(curve_duration(curve)))

    return 1
}

@(private="file")
_get_key_count :: proc "c" (L: ^lua.State) -> i32 {
    curve := CurveFromLua(L, 1)
    lua.pushinteger(L, lua.Integer(len(curve.keys)))

    return 1
}

@(private="file")
_remove_key :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    curve := CurveFromLua(L, 1)
    index := int(lua.L_checkinteger(L, 2))
    if index < 1 || index > len(curve.keys) {
        return i32(lua.L_argerror(L, 2, "key index out of range"))
    }

    curve_remove_key(curve, index - 1)

    return 0
}

@(private="file")
_sample :: proc "c" (L: ^lua.State) -> i32 {
    curve := CurveFromLua(L, 1)
    time := f32(lua.L_checknumber(L, 2))
    lua.pushnumber(L, lua.Number(curve_sample_value(curve, time)))

    return 1
}

@(private="file")
__gc :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    curve := CurveFromLua(L, 1)
    destroy_curve(curve)

    return 0
}
