package graphics

import "core:c"
import "core:log"
import "core:math"

import lua "vendor:lua/5.4"

import "../core"

ColorCurveKey :: struct {
    time: f32,
    r:    f32,
    g:    f32,
    b:    f32,
    a:    f32,
    ease: EaseKind,
}

ColorCurve :: struct {
    keys: [dynamic]ColorCurveKey,
}

ColorCurveLuaBind :: proc(L: ^lua.State) {
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

    core.LuaBindClass(L, "KaptanColorCurve", &static_reg_table, &instance_reg_table, __gc)
}

ColorCurveLuaUnbind :: proc(L: ^lua.State) {
    // nothing to do
}

ColorCurveFromLua :: proc "contextless" (L: ^lua.State, idx: i32) -> ^ColorCurve {
    return (^ColorCurve)(core.LuaUserdataHandle(L, idx, "KaptanColorCurveMT"))
}

@(private="file")
init_color_curve :: proc(curve: ^ColorCurve) {
    log.debugf("KaptanColorCurve: Init")
    curve.keys = make([dynamic]ColorCurveKey)
}

@(private="file")
destroy_color_curve :: proc(curve: ^ColorCurve) {
    if curve == nil {
        return
    }

    log.debugf("KaptanColorCurve: Destroy")
    delete(curve.keys)
    free(curve)
}

@(private="file")
check_color_key_time :: proc "contextless" (L: ^lua.State, idx: i32) -> f32 {
    time := f32(lua.L_checknumber(L, idx))
    if time < 0 {
        lua.L_argerror(L, c.int(idx), "key time must be >= 0")
    }

    return time
}

@(private="file")
color_curve_insert_key :: proc(curve: ^ColorCurve, key: ColorCurveKey) {
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
color_curve_duration :: proc "contextless" (curve: ^ColorCurve) -> f32 {
    if len(curve.keys) == 0 {
        return 0
    }

    return curve.keys[len(curve.keys) - 1].time
}

@(private="file")
clamp_color :: proc "contextless" (value: f32) -> lua.Integer {
    return lua.Integer(clamp(int(math.round(value)), 0, 255))
}

@(private="file")
color_curve_sample_value :: proc "contextless" (curve: ^ColorCurve, time: f32) -> (r, g, b, a: lua.Integer) {
    if len(curve.keys) == 0 {
        return 0, 0, 0, 0
    }
    if len(curve.keys) == 1 || time <= curve.keys[0].time {
        key := curve.keys[0]
        return clamp_color(key.r), clamp_color(key.g), clamp_color(key.b), clamp_color(key.a)
    }

    last_index := len(curve.keys) - 1
    if time >= curve.keys[last_index].time {
        key := curve.keys[last_index]
        return clamp_color(key.r), clamp_color(key.g), clamp_color(key.b), clamp_color(key.a)
    }

    for i := 0; i < last_index; i += 1 {
        from := curve.keys[i]
        to := curve.keys[i + 1]
        if time <= to.time {
            duration := to.time - from.time
            if duration <= 0 {
                return clamp_color(to.r), clamp_color(to.g), clamp_color(to.b), clamp_color(to.a)
            }

            local_t := (time - from.time) / duration
            eased_t := EaseSample(from.ease, local_t)
            return \
                clamp_color(math.lerp(from.r, to.r, eased_t)), \
                clamp_color(math.lerp(from.g, to.g, eased_t)), \
                clamp_color(math.lerp(from.b, to.b, eased_t)), \
                clamp_color(math.lerp(from.a, to.a, eased_t))
        }
    }

    key := curve.keys[last_index]
    return clamp_color(key.r), clamp_color(key.g), clamp_color(key.b), clamp_color(key.a)
}

@(private="file")
_new :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    curve := new(ColorCurve)
    init_color_curve(curve)

    handle := (^^ColorCurve)(lua.newuserdata(L, size_of(^ColorCurve)))
    handle^ = curve
    core.LuaSetClassMetatable(L, "KaptanColorCurve")

    return 1
}

@(private="file")
_add_key :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    curve := ColorCurveFromLua(L, 1)
    time := check_color_key_time(L, 2)
    r := f32(lua.L_checknumber(L, 3))
    g := f32(lua.L_checknumber(L, 4))
    b := f32(lua.L_checknumber(L, 5))
    a := f32(lua.L_checknumber(L, 6))
    ease := EaseKind.Linear
    if ! lua.isnoneornil(L, 7) {
        ease = EaseKindFromLua(L, 7)
    }

    color_curve_insert_key(curve, ColorCurveKey{time = time, r = r, g = g, b = b, a = a, ease = ease})

    return 0
}

@(private="file")
_clear :: proc "c" (L: ^lua.State) -> i32 {
    curve := ColorCurveFromLua(L, 1)
    clear(&curve.keys)

    return 0
}

@(private="file")
_get_duration :: proc "c" (L: ^lua.State) -> i32 {
    curve := ColorCurveFromLua(L, 1)
    lua.pushnumber(L, lua.Number(color_curve_duration(curve)))

    return 1
}

@(private="file")
_get_key_count :: proc "c" (L: ^lua.State) -> i32 {
    curve := ColorCurveFromLua(L, 1)
    lua.pushinteger(L, lua.Integer(len(curve.keys)))

    return 1
}

@(private="file")
_remove_key :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    curve := ColorCurveFromLua(L, 1)
    index := int(lua.L_checkinteger(L, 2))
    if index < 1 || index > len(curve.keys) {
        return i32(lua.L_argerror(L, 2, "key index out of range"))
    }

    ordered_remove(&curve.keys, index - 1)

    return 0
}

@(private="file")
_sample :: proc "c" (L: ^lua.State) -> i32 {
    curve := ColorCurveFromLua(L, 1)
    time := f32(lua.L_checknumber(L, 2))
    r, g, b, a := color_curve_sample_value(curve, time)
    lua.pushinteger(L, r)
    lua.pushinteger(L, g)
    lua.pushinteger(L, b)
    lua.pushinteger(L, a)

    return 4
}

@(private="file")
__gc :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    curve := ColorCurveFromLua(L, 1)
    destroy_color_curve(curve)

    return 0
}
