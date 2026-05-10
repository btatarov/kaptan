package graphics

import "core:c"
import "core:log"
import "core:math"

import lua "vendor:lua/5.4"

import "../core"

Vec2CurveKey :: struct {
    time: f32,
    x:    f32,
    y:    f32,
    ease: EaseKind,
}

Vec2Curve :: struct {
    keys: [dynamic]Vec2CurveKey,
}

Vec2CurveLuaBind :: proc(L: ^lua.State) {
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

    core.LuaBindClass(L, "KaptanVec2Curve", &static_reg_table, &instance_reg_table, __gc)
}

Vec2CurveLuaUnbind :: proc(L: ^lua.State) {
    // nothing to do
}

Vec2CurveFromLua :: proc "contextless" (L: ^lua.State, idx: i32) -> ^Vec2Curve {
    return (^Vec2Curve)(core.LuaUserdataHandle(L, idx, "KaptanVec2CurveMT"))
}

@(private="file")
init_vec2_curve :: proc(curve: ^Vec2Curve) {
    log.debugf("KaptanVec2Curve: Init")
    curve.keys = make([dynamic]Vec2CurveKey)
}

@(private="file")
destroy_vec2_curve :: proc(curve: ^Vec2Curve) {
    if curve == nil {
        return
    }

    log.debugf("KaptanVec2Curve: Destroy")
    delete(curve.keys)
    free(curve)
}

@(private="file")
check_vec2_key_time :: proc "contextless" (L: ^lua.State, idx: i32) -> f32 {
    time := f32(lua.L_checknumber(L, idx))
    if time < 0 {
        lua.L_argerror(L, c.int(idx), "key time must be >= 0")
    }

    return time
}

@(private="file")
vec2_curve_insert_key :: proc(curve: ^Vec2Curve, key: Vec2CurveKey) {
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
vec2_curve_duration :: proc "contextless" (curve: ^Vec2Curve) -> f32 {
    if len(curve.keys) == 0 {
        return 0
    }

    return curve.keys[len(curve.keys) - 1].time
}

@(private="file")
vec2_curve_sample_value :: proc "contextless" (curve: ^Vec2Curve, time: f32) -> (x, y: f32) {
    if len(curve.keys) == 0 {
        return 0, 0
    }
    if len(curve.keys) == 1 || time <= curve.keys[0].time {
        return curve.keys[0].x, curve.keys[0].y
    }

    last_index := len(curve.keys) - 1
    if time >= curve.keys[last_index].time {
        return curve.keys[last_index].x, curve.keys[last_index].y
    }

    for i := 0; i < last_index; i += 1 {
        a := curve.keys[i]
        b := curve.keys[i + 1]
        if time <= b.time {
            duration := b.time - a.time
            if duration <= 0 {
                return b.x, b.y
            }

            local_t := (time - a.time) / duration
            eased_t := EaseSample(a.ease, local_t)
            return math.lerp(a.x, b.x, eased_t), math.lerp(a.y, b.y, eased_t)
        }
    }

    return curve.keys[last_index].x, curve.keys[last_index].y
}

@(private="file")
_new :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    curve := new(Vec2Curve)
    init_vec2_curve(curve)

    handle := (^^Vec2Curve)(lua.newuserdata(L, size_of(^Vec2Curve)))
    handle^ = curve
    core.LuaSetClassMetatable(L, "KaptanVec2Curve")

    return 1
}

@(private="file")
_add_key :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    curve := Vec2CurveFromLua(L, 1)
    time := check_vec2_key_time(L, 2)
    x := f32(lua.L_checknumber(L, 3))
    y := f32(lua.L_checknumber(L, 4))
    ease := EaseKind.Linear
    if ! lua.isnoneornil(L, 5) {
        ease = EaseKindFromLua(L, 5)
    }

    vec2_curve_insert_key(curve, Vec2CurveKey{time = time, x = x, y = y, ease = ease})

    return 0
}

@(private="file")
_clear :: proc "c" (L: ^lua.State) -> i32 {
    curve := Vec2CurveFromLua(L, 1)
    clear(&curve.keys)

    return 0
}

@(private="file")
_get_duration :: proc "c" (L: ^lua.State) -> i32 {
    curve := Vec2CurveFromLua(L, 1)
    lua.pushnumber(L, lua.Number(vec2_curve_duration(curve)))

    return 1
}

@(private="file")
_get_key_count :: proc "c" (L: ^lua.State) -> i32 {
    curve := Vec2CurveFromLua(L, 1)
    lua.pushinteger(L, lua.Integer(len(curve.keys)))

    return 1
}

@(private="file")
_remove_key :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    curve := Vec2CurveFromLua(L, 1)
    index := int(lua.L_checkinteger(L, 2))
    if index < 1 || index > len(curve.keys) {
        return i32(lua.L_argerror(L, 2, "key index out of range"))
    }

    ordered_remove(&curve.keys, index - 1)

    return 0
}

@(private="file")
_sample :: proc "c" (L: ^lua.State) -> i32 {
    curve := Vec2CurveFromLua(L, 1)
    time := f32(lua.L_checknumber(L, 2))
    x, y := vec2_curve_sample_value(curve, time)
    lua.pushnumber(L, lua.Number(x))
    lua.pushnumber(L, lua.Number(y))

    return 2
}

@(private="file")
__gc :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    curve := Vec2CurveFromLua(L, 1)
    destroy_vec2_curve(curve)

    return 0
}
