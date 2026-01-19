package main

import "core:fmt"
import "core:math/rand"
import "vendor:glfw"

Game :: struct {
    screen: Screen,
    state:  union {
        MainMenuState,
        GameState,
    },
}

MainMenuState :: struct {}

initial_main_menu_state :: MainMenuState{}

generate_main_menu_entities :: proc() {
    ENTITY_COUNT = 0

}

MAX_PIECES :: 8
PIECE_BUFFER := [MAX_PIECES]Piece{}
PIECE_COUNT := 0
GameState :: struct {
    has_lost:              bool,
    grid:                  [GRID_WIDTH * GRID_HEIGHT]bool,
    piece_buffer:          [MAX_PIECES]Piece,
    piece_count:           int,
    active_piece:          Piece,
    active_piece_position: GridPos,
    has_active_piece:      bool,
    ticks_until_drop:      int,
    ticks_per_drop:        int,
    score:                 int,
}

GridPos :: struct {
    x: i32,
    y: i32,
}

GridDim :: struct {
    w: i32,
    h: i32,
}

Piece :: struct {
    filled:       [PIECE_WIDTH * PIECE_HEIGHT]bool,
    bounding_dim: GridDim,
    rot_centre:   GridPos,
}

piece2 :: Piece {
    filled = {
        true,
        true,
        false,
        false,
        false, //
        true,
        false,
        false,
        false,
        false, //
        true,
        false,
        false,
        false,
        false, //
        false,
        false,
        false,
        false,
        false, //
        false,
        false,
        false,
        false,
        false, //
    },
    bounding_dim = {w = 2, h = 3},
    rot_centre = {x = 0, y = 0},
}

piece1 :: Piece {
    filled = {
        true,
        true,
        true,
        true,
        true, //
        false,
        false,
        true,
        true,
        true, //
        false,
        false,
        true,
        true,
        false, //
        false,
        false,
        false,
        false,
        false, //
        false,
        false,
        false,
        false,
        false, //
    },
    bounding_dim = {w = 5, h = 3},
    rot_centre = {x = 1, y = 2},
}

piece3 :: Piece {
    filled = {
        true,
        true,
        true,
        false,
        false, //
        true,
        true,
        true,
        false,
        false, //
        true,
        true,
        true,
        false,
        false, //
        false,
        false,
        false,
        false,
        false, //
        false,
        false,
        false,
        false,
        false, //
    },
    bounding_dim = {w = 3, h = 3},
    rot_centre = {x = 4, y = 1},
}

initial_game_state :: GameState {
    grid = {},
    active_piece = {},
    active_piece_position = {x = 3, y = 10},
    has_active_piece = false,
    ticks_per_drop = 60,
    ticks_until_drop = 60,
    has_lost = false,
    piece_buffer = [MAX_PIECES]Piece{piece1, piece2, piece3, {}, {}, {}, {}, {}},
    piece_count = 3,
    score = 0,
}

init_game :: proc() -> Game {
    return Game{screen = .MAIN_MENU, state = initial_main_menu_state}
}

game_populate_entities :: proc(game: Game) {
    ENTITY_COUNT = 0
    switch game.screen {
    case .GAME:
        {
            game_state := game.state.(GameState)

            grid_pos := Pos {
                x = 50,
                y = 50,
            }
            grid_dim := Dim {
                w = 200,
                h = 400,
            }
            entity_push(
                grid_entity(
                    grid_pos,
                    grid_dim,
                    game_state.grid,
                    game_state.has_active_piece,
                    game_state.active_piece_position,
                    game_state.active_piece,
                ),
            )
        }
    case .MAIN_MENU:
        {
            start_str := "START"
            surface_dim := extent_to_dim(gc.surface_extent)
            start_button_dim := Dim {
                w = 200,
                h = 100,
            }
            start_button_pos := Pos {
                x = surface_dim.w / 2 - start_button_dim.w / 2,
                y = surface_dim.h / 2 - start_button_dim.h / 2,
            }
            exit_str := "EXIT"
            exit_button_dim := Dim {
                w = 200,
                h = 100,
            }
            exit_button_pos := Pos {
                x = start_button_pos.x,
                y = start_button_pos.y - 1.5 * start_button_dim.h,
            }
            entity_push(
                button_entity(
                    start_button_pos,
                    start_button_dim,
                    transmute([]u8)start_str,
                    is_hovered(start_button_pos, start_button_dim),
                    start_game_on_click,
                ),
            )
            entity_push(
                button_entity(
                    exit_button_pos,
                    exit_button_dim,
                    transmute([]u8)exit_str,
                    is_hovered(exit_button_pos, exit_button_dim),
                    exit_on_click,
                ),
            )
        }
    }
}

game_handle_event :: proc(game: ^Game, event: Event) {
    switch game.screen {
    case .MAIN_MENU:
        {
            switch event.type {
            case .Keyboard:
                {
                    return
                }
            case .Mouse:
                {
                    mouse_event := event.data.(MouseEvent)
                    if mouse_event.type != .Press {return}
                    for entity in ENTITY_BUFFER[:ENTITY_COUNT] {
                        if !entity.clickable {continue}
                        if !is_hovered(entity.pos, entity.dim) {continue}
                        if entity.on_click == nil {unreachable()}
                        entity.on_click(game)
                    }
                }
            }
        }
    case .GAME:
        {
            game_state := &game.state.(GameState)
            switch event.type {
            case .Keyboard:
                {
                    key_event := event.data.(KeyboardEvent)
                    if (key_event.type == .Press && key_event.char == .Space) {
                        exit_on_click(game)
                    } else if (key_event.type == .Press && key_event.char == .Left) {
                        update_active_piece_position(game_state, -1, 0)
                    } else if (key_event.type == .Press && key_event.char == .Right) {
                        update_active_piece_position(game_state, 1, 0)
                    } else if (key_event.type == .Press && key_event.char == .Down) {
                        update_active_piece_position(game_state, 0, -1)
                    } else if (key_event.type == .Press && key_event.char == .Up) {
                        update_active_piece_position(game_state, 0, 1)
                    } else if (key_event.type == .Press && key_event.char == .S) {
                        rotate_active_piece(game_state, .ANTICLOCKWISE)
                    } else if (key_event.type == .Press && key_event.char == .T) {
                        rotate_active_piece(game_state, .CLOCKWISE)
                    }
                }
            case .Mouse:
                {
                    mouse_event := event.data.(MouseEvent)
                    if mouse_event.type != .Press {return}
                    for entity in ENTITY_BUFFER[:ENTITY_COUNT] {
                        if !entity.clickable {continue}
                        if !is_hovered(entity.pos, entity.dim) {continue}
                        if entity.on_click == nil {unreachable()}
                        entity.on_click(game)
                    }
                }
            }
        }
    }
}

Screen :: enum {
    MAIN_MENU,
    GAME,
}

start_game_on_click :: proc(game: ^Game) {
    game.screen = .GAME
    game.state = initial_game_state
}

exit_on_click :: proc(_: ^Game) {
    glfw.SetWindowShouldClose(gc.window, true)
}

Dir :: enum {
    CLOCKWISE,
    ANTICLOCKWISE,
}

rotate_active_piece :: proc(gs: ^GameState, dir: Dir) {
    updated_piece := Piece {
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
        if !val {continue}
        x := updated_position.x + (cast(i32)idx % PIECE_WIDTH)
        y := updated_position.y + (cast(i32)idx / PIECE_WIDTH)
        if y >= GRID_HEIGHT {continue}

        if gs.grid[y * GRID_WIDTH + x] == true {
            return // don't update
        }
    }

    gs.active_piece = updated_piece
    gs.active_piece_position = updated_position
}

get_clockwise_rotated_filled_array :: proc(piece: Piece) -> (output: [PIECE_WIDTH * PIECE_HEIGHT]bool) {
    // assumes zero initialised output == empty
    for j in 0 ..< piece.bounding_dim.h {
        write_col_idx := j
        for i in 0 ..< piece.bounding_dim.w {
            val := piece.filled[i + j * PIECE_WIDTH]
            write_row_idx := piece.bounding_dim.w - 1 - i
            output[write_col_idx + write_row_idx * PIECE_WIDTH] = val
        }
    }
    return
}

get_anticlockwise_rotated_filled_array :: proc(piece: Piece) -> (output: [PIECE_WIDTH * PIECE_HEIGHT]bool) {
    // assumes zero initialised output == empty
    for j in 0 ..< piece.bounding_dim.h {
        write_col_idx := piece.bounding_dim.h - 1 - j
        for i in 0 ..< piece.bounding_dim.w {
            val := piece.filled[i + j * PIECE_WIDTH]
            write_row_idx := i
            output[write_col_idx + write_row_idx * PIECE_WIDTH] = val
        }
    }
    return
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
        if !val {continue}
        x := updated_pos.x + (cast(i32)idx % PIECE_WIDTH)
        y := updated_pos.y + (cast(i32)idx / PIECE_WIDTH)
        if y >= GRID_HEIGHT {continue}

        if gs.grid[y * GRID_WIDTH + x] == true {
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
        if !val {continue}
        x := gs.active_piece_position.x + (cast(i32)idx % PIECE_WIDTH)
        y := gs.active_piece_position.y + (cast(i32)idx / PIECE_WIDTH)
        if y >= GRID_HEIGHT {
            gs.has_lost = true
        } else {
            gs.grid[y * GRID_WIDTH + x] = true
        }
    }
}

game_update :: proc(game: ^Game) {
    switch game.screen {
    case .MAIN_MENU:
        {}
    case .GAME:
        {
            game_state := &game.state.(GameState)

            // spawn piece if needed
            if !game_state.has_lost && !game_state.has_active_piece {
                game_state.active_piece = game_state.piece_buffer[rand.int_max(game_state.piece_count)]
                game_state.active_piece_position = GridPos {
                    x = GRID_WIDTH / 2 - 1,
                    y = GRID_HEIGHT,
                }
                game_state.has_active_piece = true
            }

            // automatically lower piece
            game_state.ticks_until_drop -= 1
            if game_state.ticks_until_drop <= 0 {
                game_state.ticks_until_drop = game_state.ticks_per_drop

                collided := update_active_piece_position(game_state, 0, -1)
                if collided {
                    deactivate_piece(game_state)
                }
            }

            // clear filled lines
            filled_line_idxs := [PIECE_HEIGHT]int{}
            filled_line_count := 0
            for row_idx in 0 ..< GRID_HEIGHT {
                if grid_row_is_filled(game_state, row_idx) {
                    filled_line_idxs[filled_line_count] = row_idx
                    filled_line_count += 1
                }
            }
            for row_idx in 0 ..< GRID_HEIGHT - filled_line_count {
                removed_row_count := grid_removed_row_count(row_idx, filled_line_idxs[:filled_line_count])
                if removed_row_count == 0 {
                    continue
                } else {
                    for col_idx in 0 ..< GRID_WIDTH {
                        write_idx := row_idx * GRID_WIDTH + col_idx
                        read_idx := (row_idx + removed_row_count) * GRID_WIDTH + col_idx
                        game_state.grid[write_idx] = game_state.grid[read_idx]
                    }
                }
            }
            for row_idx in GRID_HEIGHT - filled_line_count ..< GRID_HEIGHT {
                for col_idx in 0 ..< GRID_WIDTH {
                    game_state.grid[row_idx * GRID_WIDTH + col_idx] = false
                }
            }

            update_score(game_state, filled_line_count)
        }
    }
}

update_score :: proc(gs: ^GameState, filled_line_count: int) {
    switch filled_line_count {
    case min(int)..=0: fallthrough
    case 6..=max(int):
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
    for filled in row {
        if !filled {return false}
    }
    return true
}

grid_removed_row_count :: proc(row_idx: int, filled_line_idxs: []int) -> (rm_rows_count: int) {
    idx := 0
    if len(filled_line_idxs) == 0 {return}
    for idx < len(filled_line_idxs) {
        filled_line_idx := filled_line_idxs[idx]
        if filled_line_idx > row_idx {return}
        if filled_line_idx < row_idx {rm_rows_count += 1}
        if filled_line_idx == row_idx {
            rm_rows_count += 1
            // count contiguous filled rows above current row
            for j, count in idx + 1 ..< len(filled_line_idxs) {
                if filled_line_idxs[j] == row_idx + count + 1 {
                    rm_rows_count += 1
                } else {
                    return
                }
            }
        }
        idx += 1
    }
    return
}
