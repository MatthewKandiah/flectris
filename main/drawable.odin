package main

import "core:fmt"
import "vendor:glfw"

BACKGROUND_Z :: 0
GRID_BACKGROUND_Z :: 0.1
PIECE_BUTTON_SELECTED_BOX_Z :: 0.19
PIECE_BUTTON_Z :: 0.2
GRID_CELL_Z :: 0.2
GAME_PANEL_Z :: 0.2
UI_PIECE_BACKGROUND_Z :: 0.8
UI_PIECE_Z :: 0.85
UI_TEXT_BACKGROUND_Z :: 0.9
UI_TEXT_Z :: 0.95

Drawable :: struct {
    pos:             Pos,
    z:               f32,
    dim:             Dim,
    texture_data:    TextureData,
    override_colour: bool,
    colour:          Colour,
}

TextureData :: struct {
    base:    Pos,
    dim:     Dim,
    tex_idx: i32,
}

draw_entities :: proc() {
    for entity in ENTITY_BUFFER[:ENTITY_COUNT] {
        draw_entity(entity)
    }
}

draw_entity :: proc(entity: Entity) {
    switch entity.type {
    case .InvisibleClickHandler:
	break
    case .TextButton:
        draw_text_button(entity)
    case .PieceButton:
	draw_piece_button(entity)
    case .PieceButtonSelectedBox:
	draw_piece_button_selected_box(entity)
    case .Grid:
        draw_grid(entity)
    case .GamePanel:
        draw_game_panel(entity)
    case .EditGrid:
	draw_edit_grid(entity)
    }
}

draw_number :: proc(n: int, min_drawn_digits: int, pos: Pos, dim: Dim, z: f32) {
    n := n
    char_buffer_size :: 32
    assert(min_drawn_digits <= char_buffer_size)
    char_buffer := [char_buffer_size]u8{}
    for &c in char_buffer {c = '0'}
    digit_count := 0

    for {
        digit := n % 10
        n /= 10
        char_buffer[char_buffer_size - 1 - digit_count] = cast(u8)digit + '0'
        digit_count += 1

        if n <= 0 {break}
        if digit_count >= char_buffer_size {break}
    }

    drawn_digit_count := max(digit_count, min_drawn_digits)
    draw_string(char_buffer[char_buffer_size - drawn_digit_count:], pos, dim, z)
}

draw_string :: proc(str: []u8, pos: Pos, dim: Dim, z: f32) {
    drawables_added := 0
    char_width: f32 = dim.w / cast(f32)len(str)
    for c, idx in str {
        if c == ' ' {
            continue
        }

        DRAWABLES[DRAWABLES_COUNT + drawables_added] = Drawable {
            pos = {x = pos.x + (cast(f32)idx * char_width), y = pos.y},
            z = z,
            dim = {w = char_width, h = dim.h},
            texture_data = get_ascii_font_texture_data(c),
            override_colour = false,
            colour = BLACK,
        }
        drawables_added += 1
    }

    DRAWABLES_COUNT += drawables_added
}

draw_rect :: proc(colour: Colour, pos: Pos, dim: Dim, z: f32) {
    DRAWABLES[DRAWABLES_COUNT] = Drawable {
        pos             = pos,
        z               = z,
        dim             = dim,
        texture_data    = {},
        override_colour = true,
        colour          = colour,
    }
    DRAWABLES_COUNT += 1
}

draw_sprite :: proc(texture_data: TextureData, pos: Pos, dim: Dim, z: f32, debug: bool, debugColour: Colour) {
    DRAWABLES[DRAWABLES_COUNT] = Drawable {
        pos             = pos,
        z               = z,
        dim             = dim,
        texture_data    = texture_data,
        override_colour = debug,
        colour          = debugColour,
    }
    DRAWABLES_COUNT += 1
}
