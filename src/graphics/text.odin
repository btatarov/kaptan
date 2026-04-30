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
        { "setPos",  _set_pos },
        { "setText", _set_text },
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

    position := rl.Vector2{
        text.position.x - text.size.x * 0.5,
        text.position.y - text.size.y * 0.5,
    }

    rl.DrawTextPro(
        text.font.font,
        text.c_content,
        position,
        rl.Vector2{0, 0},
        0,
        text.font_size,
        text.spacing,
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

    core.LuaBindClassMetatable(L, "KaptanText")

    return 1
}

@(private="file")
_set_pos :: proc "c" (L: ^lua.State) -> i32 {
    text := TextFromLua(L, 1)

    text.position.x = f32(lua.tonumber(L, 2))
    text.position.y = f32(lua.tonumber(L, 3))

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
