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
    InvisibleClickHandler,
    TextButton,
    PieceButton,
    PieceButtonSelectedBox,
    Grid,
    GamePanel,
    EditGrid,
}

EntityData :: union {
    InvisibleClickHandlerEntityData,
    TextButtonEntityData,
    PieceButtonEntityData,
    GridEntityData,
    GamePanelEntityData,
    EditGridEntityData,
}

InvisibleClickHandlerEntityData :: struct {}

TextButtonEntityData :: struct {
    str:     []u8,
    hovered: bool,
}

PieceButtonEntityData :: struct {
    piece_data: PieceData,
}

GridEntityData :: struct {
    cells:            GridData,
    rot_centre:       GridPos,
    has_active_piece: bool,
}

GamePanelEntityData :: struct {
    score:      int,
    next_piece: Piece,
}

EditGridEntityData :: struct {
    piece_data: PieceData,
}

entity_push :: proc(entity: Entity) {
    ENTITY_BUFFER[ENTITY_COUNT] = entity
    ENTITY_COUNT += 1
}

invisible_click_handler_entity :: proc(pos: Pos, dim: Dim, on_click: proc(_: ^Game)) -> Entity {
    return Entity {
        pos = pos,
        dim = dim,
        clickable = true,
        type = .InvisibleClickHandler,
        on_click = on_click,
        data = InvisibleClickHandlerEntityData{},
    }
}

text_button_entity :: proc(pos: Pos, dim: Dim, str: []u8, hovered: bool, on_click: proc(_: ^Game)) -> Entity {
    return Entity {
        pos = pos,
        dim = dim,
        clickable = true,
        type = .TextButton,
        on_click = on_click,
        data = TextButtonEntityData{str = str, hovered = hovered},
    }
}

piece_button_entity :: proc(pos: Pos, dim: Dim, piece_data: PieceData, on_click: proc(_: ^Game)) -> Entity {
    return Entity {
        pos = pos,
        dim = dim,
        clickable = true,
        on_click = on_click,
        type = .PieceButton,
        data = PieceButtonEntityData{piece_data = piece_data},
    }
}

piece_button_selected_box_entity :: proc(pos: Pos, dim: Dim) -> Entity {
    return Entity{pos = pos, dim = dim, clickable = false, on_click = nil, type = .PieceButtonSelectedBox, data = {}}
}

grid_entity :: proc(
    pos: Pos,
    dim: Dim,
    filled_grid: [GRID_WIDTH * GRID_HEIGHT]int,
    has_active_piece: bool,
    active_piece_position: GridPos,
    active_piece: Piece,
) -> Entity {
    data := GridEntityData {
        cells = filled_grid,
        has_active_piece = has_active_piece,
        rot_centre = GridPos {
            x = active_piece_position.x + active_piece.rot_centre.x,
            y = active_piece_position.y + active_piece.rot_centre.y,
        },
    }
    if has_active_piece {
        for val, idx in active_piece.filled {
            if val == 0 {continue}
            grid_pos := GridPos {
                x = active_piece_position.x + cast(i32)idx % PIECE_WIDTH,
                y = active_piece_position.y + cast(i32)idx / PIECE_WIDTH,
            }
            if grid_pos.y >= GRID_HEIGHT {continue}
            data.cells[GRID_WIDTH * grid_pos.y + grid_pos.x] = val
        }
    }
    return Entity{pos = pos, dim = dim, data = data, type = .Grid}
}

game_panel_entity :: proc(pos: Pos, dim: Dim, score: int, next_piece: Piece) -> Entity {
    data := GamePanelEntityData {
        score      = score,
        next_piece = next_piece,
    }
    return Entity{pos = pos, dim = dim, type = .GamePanel, data = data}
}

is_hovered :: proc(pos: Pos, dim: Dim) -> bool {
    return(
        !(gc.cursor_pos.x < pos.x ||
            gc.cursor_pos.x > pos.x + dim.w ||
            gc.cursor_pos.y < pos.y ||
            gc.cursor_pos.y > pos.y + dim.h) \
    )
}

edit_grid_entity :: proc(pos: Pos, dim: Dim, piece_data: PieceData) -> Entity {
    data := EditGridEntityData {
        piece_data = piece_data,
    }
    return Entity{pos = pos, dim = dim, type = .EditGrid, data = data}
}
