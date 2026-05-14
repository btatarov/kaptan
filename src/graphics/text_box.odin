package graphics

import "core:c"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:strings"

import lua "vendor:lua/5.4"
import rl "vendor:raylib"

import "../core"

TextBoxAlignment :: enum u32 {
    Left,
    Center,
    Right,
}

TextBoxLine :: struct {
    c_content: cstring,
    width:     f32,
}

TextBox :: struct {
    using transform: Transform,
    font:            ^FontResource,
    c_content:       cstring,
    lines:           [dynamic]TextBoxLine,
    font_size:       f32,
    spacing:         f32,
    line_spacing:    f32,
    size:            linalg.Vector2f32,
    color:           rl.Color,
    alignment:       TextBoxAlignment,
    refs:            int,
    visible:         bool,
    is_gone:         bool,

    draw:            proc(text_box: ^TextBox),
    set_content:     proc(text_box: ^TextBox, content: cstring),
    relayout:        proc(text_box: ^TextBox),
}

InitTextBox :: proc(text_box: ^TextBox, font: ^FontResource, content: cstring, font_size, width, height: f32) {
    log.debugf("KaptanTextBox: Init")

    InitTransform(&text_box.transform)

    text_box.font         = font
    text_box.lines        = make([dynamic]TextBoxLine)
    text_box.font_size    = font_size
    text_box.spacing      = 1
    text_box.line_spacing = font_size
    text_box.size         = linalg.Vector2f32{width, height}
    text_box.color        = rl.WHITE
    text_box.alignment    = .Left
    text_box.refs         = 0
    text_box.visible      = true
    text_box.is_gone      = false

    text_box.draw        = text_box_draw
    text_box.set_content = text_box_set_content
    text_box.relayout    = text_box_relayout

    text_box->set_content(content)
}

DestroyTextBox :: proc(text_box: ^TextBox) {
    if text_box == nil {
        return
    }

    log.debugf("KaptanTextBox: Destroy")

    clear_lines(text_box)
    delete(text_box.lines)
    FontDestroy(text_box.font)
    delete(text_box.c_content)
    text_box.is_gone = true
    free(text_box)
}

TextBoxAddRef :: proc(text_box: ^TextBox) {
    text_box.refs += 1
}

TextBoxReleaseRef :: proc(text_box: ^TextBox) {
    text_box.refs -= 1

    if text_box.is_gone && text_box.refs == 0 {
        DestroyTextBox(text_box)
    }
}

TextBoxFromLua :: proc "contextless" (L: ^lua.State, idx: i32) -> ^TextBox {
    return (^TextBox)(core.LuaUserdataHandle(L, idx, "KaptanTextBoxMT"))
}

TextBoxLuaBind :: proc(L: ^lua.State) {
    @static static_reg_table: []lua.L_Reg = {
        { "new", _new },
        { nil, nil },
    }

    @static instance_reg_table: []lua.L_Reg = {
        { "getAlignment", _get_alignment },
        { "getPiv",       _get_piv },
        { "getPos",       _get_pos },
        { "getRot",       _get_rot },
        { "getScl",       _get_scl },
        { "getSize",      _get_size },
        { "isVisible",    _get_visible },
        { "setAlignment", _set_alignment },
        { "setColor",     _set_color },
        { "setPiv",       _set_piv },
        { "setPos",       _set_pos },
        { "setRot",       _set_rot },
        { "setScl",       _set_scl },
        { "setSize",      _set_size },
        { "setText",      _set_text },
        { "setVisible",   _set_visible },
        { nil, nil },
    }

    constants := make(map[string]u32, allocator = context.temp_allocator)
    constants["ALIGN_LEFT"] = u32(TextBoxAlignment.Left)
    constants["ALIGN_CENTER"] = u32(TextBoxAlignment.Center)
    constants["ALIGN_RIGHT"] = u32(TextBoxAlignment.Right)

    core.LuaBindClass(L, "KaptanTextBox", &static_reg_table, &instance_reg_table, &constants, __gc)
}

TextBoxLuaUnbind :: proc(L: ^lua.State) {
    // nothing to do
}

@(private="file")
text_box_draw :: proc(text_box: ^TextBox) {
    if text_box.is_gone || ! text_box.visible {
        return
    }

    scale := text_box.scale.x
    line_height := text_box.line_spacing * scale
    if line_height <= 0 {
        return
    }

    max_lines := int(math.floor((text_box.size.y * scale) / line_height))
    if max_lines <= 0 {
        return
    }

    for line, index in text_box.lines {
        if index >= max_lines {
            break
        }

        x := -text_box.size.x * 0.5
        switch text_box.alignment {
        case .Left:
        case .Center:
            x = -line.width * 0.5
        case .Right:
            x = text_box.size.x * 0.5 - line.width
        }

        y := -text_box.size.y * 0.5 + f32(index) * text_box.line_spacing
        position := transform_text_box_point(text_box, linalg.Vector2f32{x, y})

        rl.DrawTextPro(
            text_box.font.font,
            line.c_content,
            position,
            {},
            text_box.rotation,
            text_box.font_size * scale,
            text_box.spacing * scale,
            text_box.color,
        )
    }
}

@(private="file")
text_box_set_content :: proc(text_box: ^TextBox, content: cstring) {
    if text_box.c_content != nil {
        delete(text_box.c_content)
    }

    text_box.c_content = strings.clone_to_cstring(string(content))
    text_box->relayout()
}

@(private="file")
text_box_relayout :: proc(text_box: ^TextBox) {
    clear_lines(text_box)

    if text_box.c_content == nil || text_box.size.x <= 0 || text_box.size.y <= 0 {
        return
    }

    source := string(text_box.c_content)
    line_builder := strings.builder_make(allocator = context.temp_allocator)
    word_builder := strings.builder_make(allocator = context.temp_allocator)
    space_builder := strings.builder_make(allocator = context.temp_allocator)

    for r in source {
        switch r {
        case '\n':
            flush_word(text_box, &line_builder, &word_builder, &space_builder)
            add_line(text_box, strings.to_string(line_builder))
            strings.builder_reset(&line_builder)
            strings.builder_reset(&space_builder)
        case ' ', '\t', '\r':
            if strings.builder_len(word_builder) > 0 {
                flush_word(text_box, &line_builder, &word_builder, &space_builder)
            }
            if strings.builder_len(line_builder) > 0 {
                _, _ = strings.write_rune(&space_builder, r)
            }
        case:
            _, _ = strings.write_rune(&word_builder, r)
        }
    }

    flush_word(text_box, &line_builder, &word_builder, &space_builder)
    if strings.builder_len(line_builder) > 0 || len(source) == 0 || source[len(source) - 1] == '\n' {
        add_line(text_box, strings.to_string(line_builder))
    }
}

@(private="file")
flush_word :: proc(text_box: ^TextBox, line_builder, word_builder, space_builder: ^strings.Builder) {
    if strings.builder_len(word_builder^) == 0 {
        return
    }

    word := strings.to_string(word_builder^)
    space := strings.to_string(space_builder^)

    if strings.builder_len(line_builder^) == 0 {
        append_word_to_empty_line(text_box, line_builder, word)
    } else {
        candidate_builder := strings.builder_make(allocator = context.temp_allocator)
        _ = strings.write_string(&candidate_builder, strings.to_string(line_builder^))
        _ = strings.write_string(&candidate_builder, space)
        _ = strings.write_string(&candidate_builder, word)

        if measure_text_box_line(text_box, strings.to_string(candidate_builder)) <= text_box.size.x {
            _ = strings.write_string(line_builder, space)
            _ = strings.write_string(line_builder, word)
        } else {
            add_line(text_box, strings.to_string(line_builder^))
            strings.builder_reset(line_builder)
            append_word_to_empty_line(text_box, line_builder, word)
        }
    }

    strings.builder_reset(word_builder)
    strings.builder_reset(space_builder)
}

@(private="file")
append_word_to_empty_line :: proc(text_box: ^TextBox, line_builder: ^strings.Builder, word: string) {
    if measure_text_box_line(text_box, word) <= text_box.size.x {
        _ = strings.write_string(line_builder, word)
        return
    }

    for r in word {
        rune_builder := strings.builder_make(allocator = context.temp_allocator)
        _, _ = strings.write_rune(&rune_builder, r)

        candidate_builder := strings.builder_make(allocator = context.temp_allocator)
        _ = strings.write_string(&candidate_builder, strings.to_string(line_builder^))
        _ = strings.write_string(&candidate_builder, strings.to_string(rune_builder))

        if strings.builder_len(line_builder^) > 0 && measure_text_box_line(text_box, strings.to_string(candidate_builder)) > text_box.size.x {
            add_line(text_box, strings.to_string(line_builder^))
            strings.builder_reset(line_builder)
        }

        _ = strings.write_string(line_builder, strings.to_string(rune_builder))
    }
}

@(private="file")
add_line :: proc(text_box: ^TextBox, line: string) {
    c_line := strings.clone_to_cstring(line)
    append(&text_box.lines, TextBoxLine{c_content = c_line, width = measure_text_box_line(text_box, line)})
}

@(private="file")
clear_lines :: proc(text_box: ^TextBox) {
    for line in text_box.lines {
        delete(line.c_content)
    }

    clear(&text_box.lines)
}

@(private="file")
measure_text_box_line :: proc(text_box: ^TextBox, line: string) -> f32 {
    c_line := strings.clone_to_cstring(line, context.temp_allocator)
    size := rl.MeasureTextEx(text_box.font.font, c_line, text_box.font_size, text_box.spacing)
    return size.x
}

@(private="file")
transform_text_box_point :: proc(text_box: ^TextBox, point: linalg.Vector2f32) -> rl.Vector2 {
    x := (point.x - text_box.pivot.x) * text_box.scale.x
    y := (point.y - text_box.pivot.y) * text_box.scale.y
    radians := math.to_radians(text_box.rotation)
    sin := math.sin(radians)
    cos := math.cos(radians)

    return rl.Vector2{
        text_box.position.x + text_box.pivot.x + x * cos - y * sin,
        text_box.position.y + text_box.pivot.y + x * sin + y * cos,
    }
}

@(private="file")
text_box_alignment_from_lua :: proc "contextless" (L: ^lua.State, idx: i32) -> TextBoxAlignment {
    alignment := TextBoxAlignment(lua.L_checkinteger(L, idx))
    if alignment < .Left || alignment > .Right {
        lua.L_argerror(L, c.int(idx), "KaptanTextBox.ALIGN_LEFT, KaptanTextBox.ALIGN_CENTER, or KaptanTextBox.ALIGN_RIGHT expected")
    }

    return alignment
}

@(private="file")
_new :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    handle := (^^TextBox)(lua.newuserdata(L, size_of(^TextBox)))
    path := lua.L_checkstring(L, 1)
    content := lua.L_checkstring(L, 2)
    font_size := f32(lua.L_checknumber(L, 3))
    width := f32(lua.L_checknumber(L, 4))
    height := f32(lua.L_checknumber(L, 5))

    text_box := new(TextBox)
    font := FontInit(path, i32(font_size))
    InitTextBox(text_box, font, content, font_size, width, height)
    handle^ = text_box

    core.LuaSetClassMetatable(L, "KaptanTextBox")

    return 1
}

@(private="file")
_get_alignment :: proc "c" (L: ^lua.State) -> i32 {
    text_box := TextBoxFromLua(L, 1)
    lua.pushinteger(L, lua.Integer(text_box.alignment))
    return 1
}

@(private="file")
_get_piv :: proc "c" (L: ^lua.State) -> i32 {
    text_box := TextBoxFromLua(L, 1)

    lua.pushnumber(L, lua.Number(text_box.pivot.x))
    lua.pushnumber(L, lua.Number(text_box.pivot.y))

    return 2
}

@(private="file")
_get_pos :: proc "c" (L: ^lua.State) -> i32 {
    text_box := TextBoxFromLua(L, 1)

    lua.pushnumber(L, lua.Number(text_box.position.x))
    lua.pushnumber(L, lua.Number(text_box.position.y))

    return 2
}

@(private="file")
_get_rot :: proc "c" (L: ^lua.State) -> i32 {
    text_box := TextBoxFromLua(L, 1)

    lua.pushnumber(L, lua.Number(text_box.rotation))

    return 1
}

@(private="file")
_get_scl :: proc "c" (L: ^lua.State) -> i32 {
    text_box := TextBoxFromLua(L, 1)

    lua.pushnumber(L, lua.Number(text_box.scale.x))

    return 1
}

@(private="file")
_get_size :: proc "c" (L: ^lua.State) -> i32 {
    text_box := TextBoxFromLua(L, 1)

    lua.pushnumber(L, lua.Number(text_box.size.x))
    lua.pushnumber(L, lua.Number(text_box.size.y))

    return 2
}

@(private="file")
_get_visible :: proc "c" (L: ^lua.State) -> i32 {
    text_box := TextBoxFromLua(L, 1)

    lua.pushboolean(L, b32(text_box.visible))

    return 1
}

@(private="file")
_set_alignment :: proc "c" (L: ^lua.State) -> i32 {
    text_box := TextBoxFromLua(L, 1)
    text_box.alignment = text_box_alignment_from_lua(L, 2)

    return 0
}

@(private="file")
_set_pos :: proc "c" (L: ^lua.State) -> i32 {
    text_box := TextBoxFromLua(L, 1)

    text_box.position.x = f32(lua.L_checknumber(L, 2))
    text_box.position.y = f32(lua.L_checknumber(L, 3))

    return 0
}

@(private="file")
_set_piv :: proc "c" (L: ^lua.State) -> i32 {
    text_box := TextBoxFromLua(L, 1)

    text_box.pivot.x = f32(lua.L_checknumber(L, 2))
    text_box.pivot.y = f32(lua.L_checknumber(L, 3))

    return 0
}

@(private="file")
_set_rot :: proc "c" (L: ^lua.State) -> i32 {
    text_box := TextBoxFromLua(L, 1)

    text_box.rotation = f32(lua.L_checknumber(L, 2))

    return 0
}

@(private="file")
_set_scl :: proc "c" (L: ^lua.State) -> i32 {
    text_box := TextBoxFromLua(L, 1)
    scale := f32(lua.L_checknumber(L, 2))

    text_box.scale.x = scale
    text_box.scale.y = scale

    return 0
}

@(private="file")
_set_size :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    text_box := TextBoxFromLua(L, 1)
    text_box.size.x = f32(lua.L_checknumber(L, 2))
    text_box.size.y = f32(lua.L_checknumber(L, 3))
    text_box->relayout()

    return 0
}

@(private="file")
_set_color :: proc "c" (L: ^lua.State) -> i32 {
    text_box := TextBoxFromLua(L, 1)

    r := u8(clamp(int(lua.L_checkinteger(L, 2)), 0, 255))
    g := u8(clamp(int(lua.L_checkinteger(L, 3)), 0, 255))
    b := u8(clamp(int(lua.L_checkinteger(L, 4)), 0, 255))
    a := u8(clamp(int(lua.L_checkinteger(L, 5)), 0, 255))

    text_box.color = rl.Color{r, g, b, a}

    return 0
}

@(private="file")
_set_visible :: proc "c" (L: ^lua.State) -> i32 {
    text_box := TextBoxFromLua(L, 1)

    text_box.visible = bool(lua.toboolean(L, 2))

    return 0
}

@(private="file")
_set_text :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    text_box := TextBoxFromLua(L, 1)
    content := lua.L_checkstring(L, 2)

    text_box->set_content(content)

    return 0
}

@(private="file")
__gc :: proc "c" (L: ^lua.State) -> i32 {
    context = core.GetDefaultContext()

    text_box := TextBoxFromLua(L, 1)

    if ! text_box.is_gone {
        text_box.is_gone = true

        if text_box.refs == 0 {
            DestroyTextBox(text_box)
        }
    }

    return 0
}
