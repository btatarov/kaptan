package graphics

import "core:fmt"
import "core:log"

import lua "vendor:lua/5.4"
import rl "vendor:raylib"

import "../core"
import "../physics"

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
    profile_enabled := core.FrameProfilerIsEnabled()
    profile_render_start: core.FrameProfilerTick
    if profile_enabled {
        profile_render_start = core.FrameProfilerNow()
    }

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
            if profile_enabled {
                core.FrameProfilerCountLayerItemVisited()
            }

            switch item.kind {
            case .Sprite:
                if profile_enabled {
                    if item.sprite.is_gone || ! item.sprite.visible {
                        core.FrameProfilerCountSpriteSkipped()
                    } else {
                        core.FrameProfilerCountSpriteDrawn()
                    }
                }
                item.sprite->draw()
            case .DrawShape:
                if profile_enabled {
                    if item.shape.is_gone || ! item.shape.visible {
                        core.FrameProfilerCountDrawShapeSkipped()
                    } else {
                        core.FrameProfilerCountDrawShapeDrawn()
                    }
                }
                item.shape->draw()
            case .Text:
                if profile_enabled {
                    if item.text.is_gone || ! item.text.visible {
                        core.FrameProfilerCountTextSkipped()
                    } else {
                        core.FrameProfilerCountTextDrawn()
                    }
                }
                item.text->draw()
            case .TextBox:
                if profile_enabled {
                    if item.text_box.is_gone || ! item.text_box.visible {
                        core.FrameProfilerCountTextBoxSkipped()
                    } else {
                        core.FrameProfilerCountTextBoxDrawn()
                    }
                }
                item.text_box->draw()
            }
        }
    }

    if active_mode != .None {
        rl.EndMode2D()
    }

    when ODIN_DEBUG {
        if physics.PhysicsSystemIsDebugDraw() {
            rl.BeginMode2D(GetCamera()^)
            physics.PhysicsSystemDebugDraw()
            rl.EndMode2D()
        }
    }

    if core.EnvironmentIsFPSCounterEnabled() {
        fps_text := fmt.ctprintf("FPS: %v", rl.GetFPS())
        text_size := rl.MeasureTextEx(rl.GetFontDefault(), fps_text, 20, 1)
        rl.DrawText(fps_text, rl.GetScreenWidth() - i32(text_size.x) - 20, 10, 20, rl.WHITE)
    }

    if profile_enabled {
        core.FrameProfilerAddRender(profile_render_start)
        profile_end_drawing_start := core.FrameProfilerNow()
        rl.EndDrawing()
        core.FrameProfilerAddEndDrawing(profile_end_drawing_start)
    } else {
        rl.EndDrawing()
    }
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
        { "remove",        _remove },
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
renderer_contains_layer :: proc(layer: ^Layer) -> bool {
    for existing in renderer.layer_list {
        if existing == layer {
            return true
        }
    }

    return false
}

@(private="file")
_add :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    layer := LayerFromLua(L, 1)

    if renderer_contains_layer(layer) {
        lua.pushboolean(L, false)

        return 1
    }

    LayerAddRef(layer)
    append(&renderer.layer_list, layer)

    lua.pushboolean(L, true)

    return 1
}

@(private="file")
_clear :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    RendererClearLayers()

    return 0
}

@(private="file")
_remove :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    layer := LayerFromLua(L, 1)

    for existing, index in renderer.layer_list {
        if existing == layer {
            LayerReleaseRef(existing)
            ordered_remove(&renderer.layer_list, index)

            lua.pushboolean(L, true)

            return 1
        }
    }

    lua.pushboolean(L, false)

    return 1
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
