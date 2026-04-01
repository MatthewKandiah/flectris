package main

import "core:fmt"
import "core:math/rand"
import "core:mem"

GlobalState :: struct {
    piece_buffer: [MAX_PIECES]Piece,
}

MAX_ERR_STR_LENGTH :: 64

MainMenuState :: struct {
    piece_config_string: [CONFIG_STRING_LENGTH * MAX_PIECES]u8,
    error_string_buf: [MAX_ERR_STR_LENGTH]u8,
    error_string: []u8
}

main_menu_state :: proc(pieces: [MAX_PIECES]Piece) -> MainMenuState {
    result := MainMenuState{
	piece_config_string = encode_piece_config_to_string(pieces),
	error_string_buf = {},
	error_string = nil,
    }
    return result   
}

set_main_menu_error :: proc(state: ^MainMenuState, str: []u8) {
    if len(str) > len(state.error_string_buf) {
	panic("String too long, main main state buffer")
    }
    
    mem.copy_non_overlapping(&state.error_string_buf, raw_data(str), len(str))
    state.error_string = state.error_string_buf[0:len(str)]
}

EditState :: struct {
    piece_buffer:     [MAX_PIECES]Piece,
    active_piece_idx: int,
}

initial_edit_state :: proc(game: Game) -> EditState {
    return EditState{piece_buffer = game.global.piece_buffer, active_piece_idx = 0}
}

GameState :: struct {
    has_lost:              bool,
    grid:                  GridData,
    piece_buffer:          [MAX_PIECES]GamePiece,
    piece_count:           int,
    active_piece:          GamePiece,
    next_piece:            GamePiece,
    saved_piece:           GamePiece,
    active_piece_position: GridPos,
    has_active_piece:      bool,
    has_saved_piece:       bool,
    can_save_piece:        bool,
    ticks_until_drop:      int,
    ticks_per_drop:        int,
    score:                 int,
    level_lines_cleared:   int,
}

initial_game_state :: proc(game: Game) -> GameState {
    piece_buffer, piece_count := game_pieces_from_pieces(game.global.piece_buffer)
    return GameState {
        grid = {},
        active_piece = {},
        saved_piece = {},
        has_saved_piece = false,
        piece_buffer = piece_buffer,
        piece_count = piece_count,
        next_piece = {},
        active_piece_position = {},
        has_active_piece = false,
        ticks_per_drop = 60,
        ticks_until_drop = 60,
        has_lost = false,
        score = 0,
        level_lines_cleared = 0,
        can_save_piece = true,
    }
}

rotate_active_piece :: proc(gs: ^GameState, dir: Dir) {
    updated_piece := GamePiece {
        bounding_dim = GridDim{w = gs.active_piece.bounding_dim.h, h = gs.active_piece.bounding_dim.w},
    }
    switch dir {
    case .CLOCKWISE:
        {
            updated_piece.filled = get_clockwise_rotated_filled_array(gs.active_piece)
        }
    case .ANTICLOCKWISE:
        {
            updated_piece.filled = get_anticlockwise_rotated_filled_array(gs.active_piece)
        }
    }

    updated_position: GridPos
    switch dir {
    case .CLOCKWISE:
        {
            updated_position = GridPos {
                x = gs.active_piece_position.x + gs.active_piece.rot_centre.x - gs.active_piece.rot_centre.y,
                y = gs.active_piece_position.y + gs.active_piece.rot_centre.x + gs.active_piece.rot_centre.y - gs.active_piece.bounding_dim.w,
            }
        }
    case .ANTICLOCKWISE:
        {
            updated_position = GridPos {
                x = gs.active_piece_position.x + gs.active_piece.rot_centre.x + gs.active_piece.rot_centre.y - gs.active_piece.bounding_dim.h,
                y = gs.active_piece_position.y + gs.active_piece.rot_centre.y - gs.active_piece.rot_centre.x,
            }
        }
    }
    updated_piece.rot_centre = GridPos {
        x = gs.active_piece_position.x + gs.active_piece.rot_centre.x - updated_position.x,
        y = gs.active_piece_position.y + gs.active_piece.rot_centre.y - updated_position.y,
    }

    // rotation centre should not be displaced by rotation
    assert(
        gs.active_piece_position.x + gs.active_piece.rot_centre.x == updated_position.x + updated_piece.rot_centre.x,
    )
    assert(
        gs.active_piece_position.y + gs.active_piece.rot_centre.y == updated_position.y + updated_piece.rot_centre.y,
    )

    // check you stay in grid
    if updated_position.x < 0 {updated_position.x = 0}
    if updated_position.x + updated_piece.bounding_dim.w >
       GRID_WIDTH {updated_position.x = GRID_WIDTH - updated_piece.bounding_dim.w}
    if updated_position.y < 0 {
        updated_position.y = 0
    }
    // check you don't overlap existing pieces
    for val, idx in updated_piece.filled {
        if val == 0 {continue}
        x := updated_position.x + (cast(i32)idx % PIECE_WIDTH)
        y := updated_position.y + (cast(i32)idx / PIECE_WIDTH)
        if y >= GRID_HEIGHT {continue}

        if gs.grid[y * GRID_WIDTH + x] != 0 {
            return // don't update
        }
    }

    gs.active_piece = updated_piece
    gs.active_piece_position = updated_position
}

save_piece :: proc(gs: ^GameState) {
    if (gs.has_saved_piece) {
        tmp_piece := gs.saved_piece
        gs.saved_piece = gs.active_piece
        gs.active_piece = tmp_piece
    } else {
        gs.saved_piece = gs.active_piece
	replace_active_piece_with_next(gs)
    }
    gs.active_piece_position.y = GRID_HEIGHT
    gs.ticks_until_drop = gs.ticks_per_drop
    gs.has_saved_piece = true
    gs.can_save_piece = false
}

replace_active_piece_with_next :: proc(gs: ^GameState) {
    gs.active_piece = gs.next_piece
    gs.next_piece = gs.piece_buffer[rand.int_max(gs.piece_count)]
    gs.has_active_piece = true
    gs.can_save_piece = true
}

update_active_piece_position :: proc(gs: ^GameState, delta_x, delta_y: i32) -> (collided_bottom: bool) {
    assert(abs(delta_x) <= 1 && abs(delta_y) <= 1, "larger jumps not currently supported")
    if !gs.has_active_piece {return}

    updated_pos := GridPos {
        x = gs.active_piece_position.x + delta_x,
        y = gs.active_piece_position.y + delta_y,
    }

    // check you stay in grid
    if updated_pos.x < 0 {updated_pos.x = 0}
    if updated_pos.x + gs.active_piece.bounding_dim.w >
       GRID_WIDTH {updated_pos.x = GRID_WIDTH - gs.active_piece.bounding_dim.w}
    if updated_pos.y < 0 {
        updated_pos.y = 0
        collided_bottom = true
    }

    // check you don't overlap existing pieces
    for val, idx in gs.active_piece.filled {
        if val == 0 {continue}
        x := updated_pos.x + (cast(i32)idx % PIECE_WIDTH)
        y := updated_pos.y + (cast(i32)idx / PIECE_WIDTH)
        if y >= GRID_HEIGHT {continue}

        if gs.grid[y * GRID_WIDTH + x] != 0 {
            updated_pos = gs.active_piece_position
            if delta_y < 0 {
                collided_bottom = true
            }
        }
    }

    gs.active_piece_position = updated_pos
    return collided_bottom
}

deactivate_piece :: proc(gs: ^GameState) {
    gs.has_active_piece = false
    for val, idx in gs.active_piece.filled {
        if val == 0 {continue}
        x := gs.active_piece_position.x + (cast(i32)idx % PIECE_WIDTH)
        y := gs.active_piece_position.y + (cast(i32)idx / PIECE_WIDTH)
        if y >= GRID_HEIGHT {
            gs.has_lost = true
        } else {
            gs.grid[y * GRID_WIDTH + x] = val
        }
    }
}

update_score :: proc(gs: ^GameState, filled_line_count: int) {
    switch filled_line_count {
    case min(int) ..= 0:
        fallthrough
    case 6 ..= max(int):
        return
    case 1:
        gs.score += 1
    case 2:
        gs.score += 2
    case 3:
        gs.score += 5
    case 4:
        gs.score += 20
    case 5:
        gs.score += 100
    }
}

grid_row_is_filled :: proc(gs: ^GameState, row_idx: int) -> bool {
    assert(row_idx >= 0 || row_idx < GRID_HEIGHT, "row must be inside grid")
    grid_idx := row_idx * GRID_WIDTH
    row := gs.grid[grid_idx:grid_idx + GRID_WIDTH]
    for val in row {
        if val == 0 {return false}
    }
    return true
}
