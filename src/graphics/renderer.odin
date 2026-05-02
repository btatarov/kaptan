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

RenderCameraMode :: enum {
    None,
    World,
    Screen,
}

@(private="file") renderer: Renderer

InitRenderer :: proc() {
    log.debugf("KaptanRenderer: Init")

    renderer.layer_list = make([dynamic]^Layer)
    InitTextureCache()
    InitFontCache()
}

DestroyRenderer :: proc() {
    log.debugf("KaptanRenderer: Destroy")

    RendererClearLayers()
    DestroyFontCache()
    DestroyTextureCache()
    delete(renderer.layer_list)
}

RendererDraw :: proc() {
    remove_gone_layers()

    rl.BeginDrawing()

    rl.ClearBackground(renderer.clear_color)

    active_mode := RenderCameraMode.None

    for layer in renderer.layer_list {
        if ! layer.visible || layer.is_gone {
            continue
        }

        desired_mode: RenderCameraMode
        if layer.cam_attached {
            desired_mode = .World
        } else {
            desired_mode = .Screen
        }

        if active_mode != desired_mode {
            if active_mode != .None {
                rl.EndMode2D()
            }

            switch desired_mode {
            case .World:
                rl.BeginMode2D(GetCamera()^)
            case .Screen:
                rl.BeginMode2D(GetScreenCamera()^)
            case .None:
            }

            active_mode = desired_mode
        }

        layer->remove_gone()

        for item in layer.items {
            switch item.kind {
            case .Sprite:
                item.sprite->draw()
            case .DrawShape:
                item.shape->draw()
            case .Text:
                item.text->draw()
            }
        }
    }

    if active_mode != .None {
        rl.EndMode2D()
    }

    // FPS counter
    when ODIN_DEBUG {
        fps_text := fmt.ctprintf("FPS: %v", rl.GetFPS())
        text_size := rl.MeasureTextEx(rl.GetFontDefault(), fps_text, 20, 1)
        rl.DrawText(fps_text, rl.GetScreenWidth() - i32(text_size.x) - 20, 10, 20, rl.WHITE)
    }

    rl.EndDrawing()
}

RendererClearLayers :: proc() {
    for layer in renderer.layer_list {
        LayerReleaseRef(layer)
    }

    clear(&renderer.layer_list)
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
remove_gone_layers :: proc() {
    write := 0
    for layer in renderer.layer_list {
        if layer.is_gone {
            LayerReleaseRef(layer)
            continue
        }

        renderer.layer_list[write] = layer
        write += 1
    }

    resize(&renderer.layer_list, write)
}

@(private="file")
_add :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    layer := LayerFromLua(L, 1)
    LayerAddRef(layer)
    append(&renderer.layer_list, layer)

    return 0
}

@(private="file")
_clear :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    RendererClearLayers()

    return 0
}

@(private="file")
_setClearColor :: proc "c" (L: ^lua.State) -> i32 {
    r := u8(clamp(int(lua.L_checkinteger(L, 1)), 0, 255))
    g := u8(clamp(int(lua.L_checkinteger(L, 2)), 0, 255))
    b := u8(clamp(int(lua.L_checkinteger(L, 3)), 0, 255))
    a := u8(clamp(int(lua.L_checkinteger(L, 4)), 0, 255))

    renderer.clear_color = rl.Color{r, g, b, a}

    return 0
}
