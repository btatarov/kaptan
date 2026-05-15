package graphics

import "core:c"
import "core:math"

import lua "vendor:lua/jit"

import "../core"

EaseKind :: enum u32 {
    Linear,
    Step,
    In_Quad,
    Out_Quad,
    In_Out_Quad,
    In_Cubic,
    Out_Cubic,
    In_Out_Cubic,
    In_Sine,
    Out_Sine,
    In_Out_Sine,
    In_Back,
    Out_Back,
    In_Out_Back,
}

EaseLuaBind :: proc(L: ^lua.State) {
    @static reg_table: []lua.L_Reg = {
        { "sample", _sample },
        { nil, nil },
    }

    constants := make(map[cstring]u32, allocator = context.temp_allocator)
    constants["LINEAR"]       = u32(EaseKind.Linear)
    constants["STEP"]         = u32(EaseKind.Step)
    constants["IN_QUAD"]      = u32(EaseKind.In_Quad)
    constants["OUT_QUAD"]     = u32(EaseKind.Out_Quad)
    constants["IN_OUT_QUAD"]  = u32(EaseKind.In_Out_Quad)
    constants["IN_CUBIC"]     = u32(EaseKind.In_Cubic)
    constants["OUT_CUBIC"]    = u32(EaseKind.Out_Cubic)
    constants["IN_OUT_CUBIC"] = u32(EaseKind.In_Out_Cubic)
    constants["IN_SINE"]      = u32(EaseKind.In_Sine)
    constants["OUT_SINE"]     = u32(EaseKind.Out_Sine)
    constants["IN_OUT_SINE"]  = u32(EaseKind.In_Out_Sine)
    constants["IN_BACK"]      = u32(EaseKind.In_Back)
    constants["OUT_BACK"]     = u32(EaseKind.Out_Back)
    constants["IN_OUT_BACK"]  = u32(EaseKind.In_Out_Back)

    core.LuaBindSingleton(L, "KaptanEase", &reg_table, &constants)
}

EaseLuaUnbind :: proc(L: ^lua.State) {
    // nothing to do
}

EaseKindFromLua :: proc "contextless" (L: ^lua.State, idx: i32) -> EaseKind {
    kind := EaseKind(lua.L_checkinteger(L, idx))
    if kind < .Linear || kind > .In_Out_Back {
        lua.L_argerror(L, c.int(idx), "valid KaptanEase constant expected")
    }

    return kind
}

EaseSample :: proc "contextless" (kind: EaseKind, t: f32) -> f32 {
    x := clamp(t, 0, 1)
    switch kind {
    case .Linear:
        return x
    case .Step:
        return 0 if x < 1 else 1
    case .In_Quad:
        return x * x
    case .Out_Quad:
        return 1 - (1 - x) * (1 - x)
    case .In_Out_Quad:
        return 2 * x * x if x < 0.5 else 1 - math.pow(-2 * x + 2, 2) * 0.5
    case .In_Cubic:
        return x * x * x
    case .Out_Cubic:
        return 1 - math.pow(1 - x, 3)
    case .In_Out_Cubic:
        return 4 * x * x * x if x < 0.5 else 1 - math.pow(-2 * x + 2, 3) * 0.5
    case .In_Sine:
        return 1 - math.cos(x * math.PI * 0.5)
    case .Out_Sine:
        return math.sin(x * math.PI * 0.5)
    case .In_Out_Sine:
        return -(math.cos(math.PI * x) - 1) * 0.5
    case .In_Back:
        c1: f32 = 1.70158
        c3 := c1 + 1
        return c3 * x * x * x - c1 * x * x
    case .Out_Back:
        c1: f32 = 1.70158
        c3 := c1 + 1
        y := x - 1
        return 1 + c3 * y * y * y + c1 * y * y
    case .In_Out_Back:
        c1: f32 = 1.70158
        c2 := c1 * 1.525
        if x < 0.5 {
            return math.pow(2 * x, 2) * ((c2 + 1) * 2 * x - c2) * 0.5
        }
        return (math.pow(2 * x - 2, 2) * ((c2 + 1) * (x * 2 - 2) + c2) + 2) * 0.5
    }

    return x
}

@(private="file")
_sample :: proc "c" (L: ^lua.State) -> i32 {
    kind := EaseKindFromLua(L, 1)
    t := f32(lua.L_checknumber(L, 2))
    lua.pushnumber(L, lua.Number(EaseSample(kind, t)))

    return 1
}
