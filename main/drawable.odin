package main

import "core:fmt"
import "vendor:vulkan"
import "vendor:glfw"

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

draw_game :: proc(game: Game) {
    switch game.screen {
    case .MAIN_MENU:
        {
            draw_menu()
        }
    case .GAME:
        {
            draw_game_screen()
        }
    }
}

draw_menu :: proc() {
    draw_rect(
        GREY,
        {x = 0, y = 0},
        {w = extent_to_dim(gc.surface_extent).w, h = extent_to_dim(gc.surface_extent).h},
        0,
    )
    str := "START"
    button_pos := Pos {
        x = 100,
        y = 100,
    }
    str_pos := Pos {
        x = 115,
        y = 110,
    }
    button_dim := Dim {
        w = 120,
        h = 120,
    }
    str_dim := Dim {
        w = 100,
        h = 100,
    }
    button_hovered := rect_hovered(button_pos, button_dim, gc.cursor_pos)
    mouse_button := glfw.GetMouseButton(gc.window, glfw.MOUSE_BUTTON_LEFT)
    if (mouse_button == glfw.PRESS && button_hovered) {
	fmt.println("clicked")
    }
    draw_rect(RED if button_hovered else BLUE, button_pos, button_dim, 0.1)
    draw_string(transmute([]u8)str, str_pos, str_dim, 0.5)
}

// TODO - refactor out `Rect` and move logic somewhere else
rect_hovered :: proc(p: Pos, d: Dim, cursor_pos: Pos) -> bool {
    if (cursor_pos.x > p.x + d.w || cursor_pos.x < p.x) {return false}
    if (cursor_pos.y > p.y + d.h || cursor_pos.y < p.y) {return false}
    return true
}

draw_game_screen :: proc() {
    draw_rect(
        GREY,
        {x = 0, y = 0},
        {w = extent_to_dim(gc.surface_extent).w, h = extent_to_dim(gc.surface_extent).h},
        0,
    )
    str := "GAME"
    draw_string(transmute([]u8)str, {x = 50, y = 100}, {w = 320, h = 50}, 0.5)
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
