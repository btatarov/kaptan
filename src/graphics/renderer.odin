package graphics

import "core:fmt"
import "core:log"

import lua "vendor:lua/5.4"
import rl "vendor:raylib"

import "../core"

Renderer :: struct {
    clear_color: rl.Color,
    layer_list:  [dynamic]^Layer,
}

@(private="file") renderer: Renderer

InitRenderer :: proc() {
    log.debugf("KaptanRenderer: Init")

    renderer.layer_list = make([dynamic]^Layer)
    InitTextureCache()
}

DestroyRenderer :: proc() {
    log.debugf("KaptanRenderer: Destroy")

    DestroyTextureCache()
    delete(renderer.layer_list)
}

RendererDraw :: proc() {
    rl.BeginDrawing()

    rl.ClearBackground(renderer.clear_color)

    rl.BeginMode2D(GetCamera()^)

    for layer in renderer.layer_list {
        if ! layer.visible || layer.is_gone {
            continue
        }

        for sprite in layer.sprites {
            sprite->draw()
        }
    }

    rl.EndMode2D()

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
        { "add",           _add },
        { "clear",         _clear },
        { "setClearColor", _setClearColor},
        { nil, nil },
    }
    core.LuaBindSingleton(L, "KaptanRenderer", &reg_table)

    InitRenderer()
}

RendererLuaUnbind :: proc(L: ^lua.State) {
    DestroyRenderer()
}

@(private="file")
_add :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    // TODO: remove on __gc or __close?
    layer := (^Layer)(lua.touserdata(L, -1))
    append(&renderer.layer_list, layer)

    return 0
}

@(private="file")
_clear :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    delete(renderer.layer_list)
    renderer.layer_list = make([dynamic]^Layer)

    return 0
}

@(private="file")
_setClearColor :: proc "c" (L: ^lua.State) -> i32 {
    r := u8(lua.tonumber(L, 1))
    g := u8(lua.tonumber(L, 2))
    b := u8(lua.tonumber(L, 3))
    a := u8(lua.tonumber(L, 4))

    renderer.clear_color = rl.Color{r, g, b, a}

    return 0
}
