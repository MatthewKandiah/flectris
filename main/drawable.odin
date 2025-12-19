package main

import "core:fmt"
import "vendor:glfw"
import "vendor:vulkan"

BACKGROUND_Z :: 0
GRID_BACKGROUND_Z :: 0.1
GRID_CELL_Z :: 0.2
UI_TEXT_BACKGROUND_Z :: 0.8
UI_TEXT_Z :: 0.9

Drawable :: struct {
    pos:             Pos,
    z:               f32,
    dim:             Dim,
    texture_data:    TextureData,
    override_colour: bool,
    colour:          Colour,
}

Colour :: struct {
    r, g, b: f32,
}

RED :: Colour {
    r = 1,
    g = 0,
    b = 0,
}
GREEN :: Colour {
    r = 0,
    g = 1,
    b = 0,
}
BLUE :: Colour {
    r = 0,
    g = 0,
    b = 1,
}
BLACK :: Colour {
    r = 0,
    g = 0,
    b = 0,
}
WHITE :: Colour {
    r = 1,
    g = 1,
    b = 1,
}
GREY :: Colour {
    r = 0.3,
    g = 0.3,
    b = 0.3,
}

Pos :: struct {
    x, y: f32,
}

Dim :: struct {
    w, h: f32,
}

extent_to_dim :: proc(extent: vulkan.Extent2D) -> Dim {
    return Dim{w = cast(f32)extent.width, h = cast(f32)extent.height}
}

TextureData :: struct {
    base: Pos,
    dim:  Dim,
}

draw_entities :: proc() {
    for entity in ENTITY_BUFFER[:ENTITY_COUNT] {
        draw_entity(entity)
    }
}

draw_entity :: proc(entity: Entity) {
    switch entity.type {
    case .Button:
        draw_button(entity)
    case .Grid:
        draw_grid(entity)
    }
}

draw_button :: proc(entity: Entity) {
    data := entity.data.(ButtonEntityData)
    colour := RED if data.hovered else BLUE
    draw_rect(colour, entity.pos, entity.dim, UI_TEXT_BACKGROUND_Z)
    draw_string(data.str, entity.pos, entity.dim, UI_TEXT_Z)
}

draw_grid :: proc(entity: Entity) {
    // draw background
    draw_rect(GREEN, entity.pos, entity.dim, GRID_BACKGROUND_Z)
    // draw filled cells
    data := entity.data.(GridEntityData)
    cell_dim := Dim {
        w = entity.dim.w / GRID_WIDTH,
        h = entity.dim.h / GRID_HEIGHT,
    }
    filled_colour := RED
    empty_colour := BLUE
    for filled, idx in data.cells {
        col_idx := idx % GRID_WIDTH
        row_idx := idx / GRID_WIDTH
        cell_pos := Pos {
            x = entity.pos.x + cast(f32)col_idx * cell_dim.w,
            y = entity.pos.y + cast(f32)row_idx * cell_dim.h,
        }
	draw_rect(filled_colour if filled else empty_colour, cell_pos, cell_dim, GRID_CELL_Z)
    }
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
