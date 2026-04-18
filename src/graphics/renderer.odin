package graphics

import "core:fmt"
import "core:log"

import lua "vendor:lua/5.4"
import rl "vendor:raylib"

import "../core"

Renderer :: struct {
    clear_color: rl.Color,
}

@(private="file") renderer: Renderer

InitRenderer :: proc() {
    log.debugf("KaptanRenderer: Init")
}

DestroyRenderer :: proc() {
    log.debugf("KaptanRenderer: Destroy")
}

RendererDraw :: proc() {
    rl.BeginDrawing()

    rl.ClearBackground(renderer.clear_color)

    // FPS counter
    when ODIN_DEBUG {
        fps_text := fmt.ctprintf("FPS: %v", rl.GetFPS())
        text_size := rl.MeasureTextEx(rl.GetFontDefault(), fps_text, 20, 1)
        rl.DrawText(fps_text, rl.GetScreenWidth() - i32(text_size.x) - 20, 10, 20, rl.WHITE)
    }

    rl.EndDrawing()
}

RendererLuaBind :: proc(L: ^lua.State) {
    @static reg_table: []lua.L_Reg = {
        { "setClearColor",  _setClearColor},
        { nil, nil },
    }
    core.LuaBindSingleton(L, "KaptanRenderer", &reg_table)
}

RendererLuaUnbind :: proc(L: ^lua.State) {
    DestroyRenderer()
}

_setClearColor :: proc "c" (L: ^lua.State) -> i32 {
    r := u8(lua.tonumber(L, 1))
    g := u8(lua.tonumber(L, 2))
    b := u8(lua.tonumber(L, 3))
    a := u8(lua.tonumber(L, 4))

    renderer.clear_color = rl.Color{r, g, b, a}

    return 0
}
