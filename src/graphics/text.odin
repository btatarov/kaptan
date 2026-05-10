package graphics

import "core:log"
import "core:strings"

import lua "vendor:lua/5.4"
import rl "vendor:raylib"

import "../core"

Text :: struct {
    using transform: Transform,
    font:            ^FontResource,
    c_content:       cstring,
    font_size:       f32,
    spacing:         f32,
    size:            rl.Vector2,
    color:           rl.Color,
    refs:            int,
    visible:         bool,
    is_gone:         bool,

    draw:            proc(text: ^Text),
    set_content:     proc(text: ^Text, content: cstring),
}

InitText :: proc(text: ^Text, font: ^FontResource, content: cstring, font_size: f32) {
    log.debugf("KaptanText: Init")

    InitTransform(&text.transform)

    text.font      = font
    text.font_size = font_size
    text.spacing   = 1
    text.color     = rl.WHITE
    text.refs      = 0
    text.visible   = true
    text.is_gone   = false

    text.draw        = text_draw
    text.set_content = text_set_content

    text->set_content(content)
}

DestroyText :: proc(text: ^Text) {
    if text == nil {
        return
    }

    log.debugf("KaptanText: Destroy")

    FontDestroy(text.font)
    delete(text.c_content)
    text.is_gone = true
    free(text)
}

TextAddRef :: proc(text: ^Text) {
    text.refs += 1
}

TextReleaseRef :: proc(text: ^Text) {
    text.refs -= 1

    if text.is_gone && text.refs == 0 {
        DestroyText(text)
    }
}

TextFromLua :: proc "contextless" (L: ^lua.State, idx: i32) -> ^Text {
    return (^Text)(core.LuaUserdataHandle(L, idx, "KaptanTextMT"))
}

TextLuaBind :: proc(L: ^lua.State) {
    @static static_reg_table: []lua.L_Reg = {
        { "new", _new },
        { nil, nil },
    }

    @static instance_reg_table: []lua.L_Reg = {
        { "getPiv",     _get_piv },
        { "getPos",     _get_pos },
        { "getRot",     _get_rot },
        { "getScl",     _get_scl },
        { "getSize",    _get_size },
        { "isVisible",  _get_visible },
        { "setColor",   _set_color },
        { "setPiv",     _set_piv },
        { "setPos",     _set_pos },
        { "setRot",     _set_rot },
        { "setScl",     _set_scl },
        { "setText",    _set_text },
        { "setVisible", _set_visible },
        { nil, nil },
    }

    core.LuaBindClass(L, "KaptanText", &static_reg_table, &instance_reg_table, __gc)
}

TextLuaUnbind :: proc(L: ^lua.State) {
    // nothing to do
}

@(private="file")
text_draw :: proc(text: ^Text) {
    if text.is_gone || !text.visible {
        return
    }

    scale := text.scale.x
    position := rl.Vector2{text.position.x + text.pivot.x, text.position.y + text.pivot.y}
    origin := rl.Vector2{
        (text.size.x * 0.5 + text.pivot.x) * scale,
        (text.size.y * 0.5 + text.pivot.y) * scale,
    }

    // DrawTextPro only supports uniform scale via font size/spacing. Switch to
    // drawing text through a texture with DrawTexturePro if scale_y is needed.

    rl.DrawTextPro(
        text.font.font,
        text.c_content,
        position,
        origin,
        text.rotation,
        text.font_size * scale,
        text.spacing * scale,
        text.color,
    )
}

@(private="file")
text_set_content :: proc(text: ^Text, content: cstring) {
    if text.c_content != nil {
        delete(text.c_content)
    }

    text.c_content = strings.clone_to_cstring(string(content))
    text.size = rl.MeasureTextEx(text.font.font, text.c_content, text.font_size, text.spacing)
}

@(private="file")
_new :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    handle := (^^Text)(lua.newuserdata(L, size_of(^Text)))
    path := lua.L_checkstring(L, 1)
    content := lua.L_checkstring(L, 2)
    font_size := f32(lua.L_checknumber(L, 3))

    text := new(Text)
    font := FontInit(path, i32(font_size))
    InitText(text, font, content, font_size)
    handle^ = text

    core.LuaSetClassMetatable(L, "KaptanText")

    return 1
}

@(private="file")
_get_piv :: proc "c" (L: ^lua.State) -> i32 {
    text := TextFromLua(L, 1)

    lua.pushnumber(L, lua.Number(text.pivot.x))
    lua.pushnumber(L, lua.Number(text.pivot.y))

    return 2
}

@(private="file")
_get_pos :: proc "c" (L: ^lua.State) -> i32 {
    text := TextFromLua(L, 1)

    lua.pushnumber(L, lua.Number(text.position.x))
    lua.pushnumber(L, lua.Number(text.position.y))

    return 2
}

@(private="file")
_get_rot :: proc "c" (L: ^lua.State) -> i32 {
    text := TextFromLua(L, 1)

    lua.pushnumber(L, lua.Number(text.rotation))

    return 1
}

@(private="file")
_get_scl :: proc "c" (L: ^lua.State) -> i32 {
    text := TextFromLua(L, 1)

    lua.pushnumber(L, lua.Number(text.scale.x))

    return 1
}

@(private="file")
_get_size :: proc "c" (L: ^lua.State) -> i32 {
    text := TextFromLua(L, 1)

    lua.pushnumber(L, lua.Number(text.size.x))
    lua.pushnumber(L, lua.Number(text.size.y))

    return 2
}

@(private="file")
_get_visible :: proc "c" (L: ^lua.State) -> i32 {
    text := TextFromLua(L, 1)

    lua.pushboolean(L, b32(text.visible))

    return 1
}

@(private="file")
_set_pos :: proc "c" (L: ^lua.State) -> i32 {
    text := TextFromLua(L, 1)

    text.position.x = f32(lua.L_checknumber(L, 2))
    text.position.y = f32(lua.L_checknumber(L, 3))

    return 0
}

@(private="file")
_set_piv :: proc "c" (L: ^lua.State) -> i32 {
    text := TextFromLua(L, 1)

    text.pivot.x = f32(lua.L_checknumber(L, 2))
    text.pivot.y = f32(lua.L_checknumber(L, 3))

    return 0
}

@(private="file")
_set_rot :: proc "c" (L: ^lua.State) -> i32 {
    text := TextFromLua(L, 1)

    text.rotation = f32(lua.L_checknumber(L, 2))

    return 0
}

@(private="file")
_set_scl :: proc "c" (L: ^lua.State) -> i32 {
    text := TextFromLua(L, 1)
    scale := f32(lua.L_checknumber(L, 2))

    text.scale.x = scale
    text.scale.y = scale

    return 0
}

@(private="file")
_set_color :: proc "c" (L: ^lua.State) -> i32 {
    text := TextFromLua(L, 1)

    r := u8(clamp(int(lua.L_checkinteger(L, 2)), 0, 255))
    g := u8(clamp(int(lua.L_checkinteger(L, 3)), 0, 255))
    b := u8(clamp(int(lua.L_checkinteger(L, 4)), 0, 255))
    a := u8(clamp(int(lua.L_checkinteger(L, 5)), 0, 255))

    text.color = rl.Color{r, g, b, a}

    return 0
}

@(private="file")
_set_visible :: proc "c" (L: ^lua.State) -> i32 {
    text := TextFromLua(L, 1)

    text.visible = bool(lua.toboolean(L, 2))

    return 0
}

@(private="file")
_set_text :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    text := TextFromLua(L, 1)
    content := lua.L_checkstring(L, 2)

    text->set_content(content)

    return 0
}

@(private="file")
__gc :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    text := TextFromLua(L, 1)

    if ! text.is_gone {
        text.is_gone = true

        if text.refs == 0 {
            DestroyText(text)
        }
    }

    return 0
}
