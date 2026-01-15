package main

import "core:fmt"

ENTITY_BUFFER_SIZE :: 1000
ENTITY_BUFFER := [ENTITY_BUFFER_SIZE]Entity{}
ENTITY_COUNT := 0

GRID_WIDTH :: 10
GRID_HEIGHT :: 20
PIECE_WIDTH :: 5
PIECE_HEIGHT :: 5

Entity :: struct {
    pos:       Pos,
    dim:       Dim,
    clickable: bool,
    on_click:  proc(_: ^Game),
    type:      EntityType,
    data:      EntityData,
}

EntityType :: enum {
    Button,
    Grid,
}

EntityData :: union {
    ButtonEntityData,
    GridEntityData,
}

ButtonEntityData :: struct {
    str:     []u8,
    hovered: bool,
}

GridEntityData :: struct {
    cells: [GRID_WIDTH * GRID_HEIGHT]bool,
}

entity_push :: proc(entity: Entity) {
    ENTITY_BUFFER[ENTITY_COUNT] = entity
    ENTITY_COUNT += 1
}

button_entity :: proc(pos: Pos, dim: Dim, str: []u8, hovered: bool, on_click: proc(_: ^Game)) -> Entity {
    return Entity {
        pos = pos,
        dim = dim,
        clickable = true,
        type = .Button,
        on_click = on_click,
        data = ButtonEntityData{str = str, hovered = hovered},
    }
}

grid_entity :: proc(
    pos: Pos,
    dim: Dim,
    filled_grid: [GRID_WIDTH * GRID_HEIGHT]bool,
    has_active_piece: bool,
    active_piece_position: GridPos,
    active_piece: Piece,
) -> Entity {
    data := GridEntityData {
        cells = filled_grid,
    }
    if has_active_piece {
        for val, idx in active_piece.filled {
	    if !val {continue}
            grid_pos := GridPos {
                x = active_piece_position.x + cast(i32)idx % PIECE_WIDTH,
                y = active_piece_position.y + cast(i32)idx / PIECE_WIDTH,
            }
	    if grid_pos.y >= GRID_HEIGHT {continue}
            data.cells[GRID_WIDTH * grid_pos.y + grid_pos.x] = true
        }
    }
    return Entity{pos = pos, dim = dim, data = data, type = .Grid}
}

is_hovered :: proc(pos: Pos, dim: Dim) -> bool {
    return(
        !(gc.cursor_pos.x < pos.x ||
            gc.cursor_pos.x > pos.x + dim.w ||
            gc.cursor_pos.y < pos.y ||
            gc.cursor_pos.y > pos.y + dim.h) \
    )
}
