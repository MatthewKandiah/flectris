package main

import "core:fmt"
import "core:math/rand"
import "vendor:glfw"

Game :: struct {
    screen: Screen,
    state:  union {
        MainMenuState,
        GameState,
        EditState,
    },
}

MainMenuState :: struct {}

initial_main_menu_state :: MainMenuState{}

EditState :: struct {}

initial_edit_state :: EditState{}

LINES_PER_LEVEL :: 20
MAX_PIECES :: 8
PIECE_BUFFER := [MAX_PIECES]Piece{}
PIECE_COUNT := 0
GameState :: struct {
    has_lost:              bool,
    grid:                  [GRID_WIDTH * GRID_HEIGHT]int,
    piece_buffer:          [MAX_PIECES]Piece,
    piece_count:           int,
    active_piece:          Piece,
    next_piece:            Piece,
    active_piece_position: GridPos,
    has_active_piece:      bool,
    ticks_until_drop:      int,
    ticks_per_drop:        int,
    score:                 int,
    level_lines_cleared:   int,
}

GridPos :: struct {
    x: i32,
    y: i32,
}

GridDim :: struct {
    w: i32,
    h: i32,
}

PieceData :: [PIECE_WIDTH * PIECE_HEIGHT]int

Piece :: struct {
    filled:       PieceData,
    bounding_dim: GridDim,
    rot_centre:   GridPos,
}

piece2 :: Piece {
    filled = {
        2,
        2,
        0,
        0,
        0, //
        2,
        2,
        0,
        0,
        0, //
        2,
        2,
        0,
        0,
        0, //
        0,
        0,
        0,
        0,
        0, //
        0,
        0,
        0,
        0,
        0, //
    },
    bounding_dim = {w = 2, h = 3},
    rot_centre = {x = 0, y = 0},
}

piece1 :: Piece {
    filled = {
        1,
        1,
        1,
        1,
        1, //
        1,
        1,
        1,
        1,
        1, //
        1,
        1,
        1,
        1,
        0, //
        0,
        0,
        0,
        0,
        0, //
        0,
        0,
        0,
        0,
        0, //
    },
    bounding_dim = {w = 5, h = 3},
    rot_centre = {x = 1, y = 2},
}

piece3 :: Piece {
    filled = {
        3,
        3,
        3,
        0,
        0, //
        3,
        3,
        3,
        0,
        0, //
        3,
        3,
        3,
        0,
        0, //
        0,
        0,
        0,
        0,
        0, //
        0,
        0,
        0,
        0,
        0, //
    },
    bounding_dim = {w = 3, h = 3},
    rot_centre = {x = 4, y = 1},
}

initial_game_state :: GameState {
    grid = {},
    active_piece = {},
    next_piece = {},
    active_piece_position = {x = 3, y = 10},
    has_active_piece = false,
    ticks_per_drop = 60,
    ticks_until_drop = 60,
    has_lost = false,
    piece_buffer = [MAX_PIECES]Piece{piece1, piece2, piece3, {}, {}, {}, {}, {}},
    piece_count = 3,
    score = 0,
    level_lines_cleared = 0,
}

init_game :: proc() -> Game {
    return Game{screen = .MAIN_MENU, state = initial_main_menu_state}
}

game_screen_populate_entities :: proc(game: Game) {
    game_state := game.state.(GameState)

    panel_dim := Dim {
        w = 480,
        h = cast(f32)(gc.surface_extent.height),
    }
    panel_pos := Pos {
        x = cast(f32)(gc.surface_extent.width) - panel_dim.w,
        y = 0,
    }

    entity_push(game_panel_entity(panel_pos, panel_dim, game_state.score, game_state.next_piece))

    grid_available_space := Dim {
        w = cast(f32)gc.surface_extent.width - panel_dim.w,
        h = cast(f32)gc.surface_extent.height,
    }
    grid_w_over_h := cast(f32)GRID_WIDTH / cast(f32)GRID_HEIGHT
    grid_available_space_w_over_h := grid_available_space.w / grid_available_space.h

    grid_pos: Pos
    grid_dim: Dim
    if (grid_w_over_h > grid_available_space_w_over_h) {
        // grid fills available width
        height := grid_available_space.w / grid_w_over_h
        grid_dim = {
            w = grid_available_space.w,
            h = height,
        }
        unfilled_height := grid_available_space.h - height
        grid_pos = {
            x = 0,
            y = unfilled_height / 2,
        }
    } else {
        // grid fills available height
        width := grid_available_space.h * grid_w_over_h
        grid_dim = {
            w = width,
            h = grid_available_space.h,
        }
        unfilled_width := grid_available_space.w - width
        grid_pos = {
            x = unfilled_width / 2,
            y = 0,
        }
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

main_menu_screen_populate_entities :: proc(game: Game) {
    start_str := "START"
    surface_dim := extent_to_dim(gc.surface_extent)
    button_dim := Dim {
        w = 200,
        h = 100,
    }
    start_button_pos := Pos {
        x = surface_dim.w / 2 - button_dim.w / 2,
        y = 2 * surface_dim.h / 3 - button_dim.h / 2,
    }
    exit_str := "EXIT"
    exit_button_pos := Pos {
        x = start_button_pos.x,
        y = start_button_pos.y - 1.5 * button_dim.h,
    }
    edit_str := "EDIT"
    edit_button_pos := Pos {
        x = start_button_pos.x,
        y = start_button_pos.y - 3 * button_dim.h,
    }
    entity_push(
        text_button_entity(
            start_button_pos,
            button_dim,
            transmute([]u8)start_str,
            is_hovered(start_button_pos, button_dim),
            start_game_on_click,
        ),
    )
    entity_push(
        text_button_entity(
            exit_button_pos,
            button_dim,
            transmute([]u8)exit_str,
            is_hovered(exit_button_pos, button_dim),
            exit_on_click,
        ),
    )
    entity_push(
        text_button_entity(
            edit_button_pos,
            button_dim,
            transmute([]u8)edit_str,
            is_hovered(edit_button_pos, button_dim),
            edit_on_click,
        ),
    )
}

edit_screen_populate_entities :: proc(game: Game) {
    surface_dim := extent_to_dim(gc.surface_extent)
    {     // side panel
        side_panel_width: f32 = 400
        vertical_gap: f32 = 10
        horizontal_gap: f32 = 5

        piece_button_dim := Dim {
            w = (side_panel_width - (3 * horizontal_gap)) / 2,
            h = (surface_dim.h - (7 * vertical_gap)) / 6,
        }
        text_button_dim := Dim {
            w = piece_button_dim.w * 2 + horizontal_gap,
            h = piece_button_dim.h,
        }

        exit_str := "EXIT"
        exit_button_pos := Pos {
            x = surface_dim.w - side_panel_width + horizontal_gap,
            y = vertical_gap,
        }

        cancel_str := "CANCEL"
        cancel_button_pos := Pos {
            x = exit_button_pos.x,
            y = exit_button_pos.y + text_button_dim.h + vertical_gap,
        }

        entity_push(
            text_button_entity(exit_button_pos, text_button_dim, transmute([]u8)exit_str, false, edit_exit_on_click),
        )
        entity_push(
            text_button_entity(
                cancel_button_pos,
                text_button_dim,
                transmute([]u8)cancel_str,
                false,
                edit_cancel_on_click,
            ),
        )

        for col in 0 ..= 1 {
            for row in 0 ..= 3 {
                piece_idx := 6 - (2 * row) + col
                piece_button_pos := Pos {
                    x = cancel_button_pos.x + cast(f32)col * (piece_button_dim.w + horizontal_gap),
                    y = cancel_button_pos.y + text_button_dim.h + vertical_gap + cast(f32)row * (piece_button_dim.h + vertical_gap),
                }
                entity_push(
                    piece_button_entity(
                        piece_button_pos,
                        piece_button_dim,
                        piece1.filled,
                        edit_piece_on_clicks[piece_idx],
                    ),
                )
            }
        }
    }

    {     // main grid
    }
}

game_populate_entities :: proc(game: Game) {
    ENTITY_COUNT = 0
    switch game.screen {
    case .GAME:
        game_screen_populate_entities(game)
    case .MAIN_MENU:
        main_menu_screen_populate_entities(game)
    case .EDIT:
        edit_screen_populate_entities(game)
    }
}

main_menu_screen_handle_event :: proc(game: ^Game, event: Event) {
    switch event.type {
    case .Keyboard:
        return

    case .Mouse:
        handle_mouse_event(game, event.data.(MouseEvent))
    }
}

edit_screen_handle_event :: proc(game: ^Game, event: Event) {
    switch event.type {
    case .Keyboard:
        return
    case .Mouse:
        handle_mouse_event(game, event.data.(MouseEvent))
    }
}

game_screen_handle_event :: proc(game: ^Game, event: Event) {
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
                for !update_active_piece_position(game_state, 0, -1) {}
                deactivate_piece(game_state)
            } else if (key_event.type == .Press && key_event.char == .S) {
                rotate_active_piece(game_state, .ANTICLOCKWISE)
            } else if (key_event.type == .Press && key_event.char == .T) {
                rotate_active_piece(game_state, .CLOCKWISE)
            }
        }
    case .Mouse:
        handle_mouse_event(game, event.data.(MouseEvent))
    }
}

handle_mouse_event :: proc(game: ^Game, mouse_event: MouseEvent) {
    if mouse_event.type != .Press {return}
    for entity in ENTITY_BUFFER[:ENTITY_COUNT] {
        if !entity.clickable {continue}
        if !is_hovered(entity.pos, entity.dim) {continue}
        if entity.on_click == nil {unreachable()}
        entity.on_click(game)
    }
}

game_handle_event :: proc(game: ^Game, event: Event) {
    switch game.screen {
    case .MAIN_MENU:
        main_menu_screen_handle_event(game, event)
    case .EDIT:
        edit_screen_handle_event(game, event)
    case .GAME:
        game_screen_handle_event(game, event)
    }
}

Screen :: enum {
    MAIN_MENU,
    GAME,
    EDIT,
}

start_game_on_click :: proc(game: ^Game) {
    game.screen = .GAME
    game_state := initial_game_state
    game_state.next_piece = game_state.piece_buffer[rand.int_max(game_state.piece_count)]
    game.state = game_state
}

exit_on_click :: proc(_: ^Game) {
    glfw.SetWindowShouldClose(gc.window, true)
}

edit_on_click :: proc(game: ^Game) {
    game.screen = .EDIT
    fmt.println("EDIT")
}

edit_cancel_on_click :: proc(_: ^Game) {
    fmt.println("edit cancel clicked")
}

edit_exit_on_click :: proc(_: ^Game) {
    fmt.println("edit exit clicked")
}

edit_piece_on_click :: proc(n: int) {
    fmt.println("edit piece clicked", n)
}
edit_piece0_on_click :: proc(_: ^Game) {edit_piece_on_click(0)}
edit_piece1_on_click :: proc(_: ^Game) {edit_piece_on_click(1)}
edit_piece2_on_click :: proc(_: ^Game) {edit_piece_on_click(2)}
edit_piece3_on_click :: proc(_: ^Game) {edit_piece_on_click(3)}
edit_piece4_on_click :: proc(_: ^Game) {edit_piece_on_click(4)}
edit_piece5_on_click :: proc(_: ^Game) {edit_piece_on_click(5)}
edit_piece6_on_click :: proc(_: ^Game) {edit_piece_on_click(6)}
edit_piece7_on_click :: proc(_: ^Game) {edit_piece_on_click(7)}
edit_piece_on_clicks := []proc(_: ^Game) {
    edit_piece0_on_click,
    edit_piece1_on_click,
    edit_piece2_on_click,
    edit_piece3_on_click,
    edit_piece4_on_click,
    edit_piece5_on_click,
    edit_piece6_on_click,
    edit_piece7_on_click,
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

get_clockwise_rotated_filled_array :: proc(piece: Piece) -> (output: PieceData) {
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

get_anticlockwise_rotated_filled_array :: proc(piece: Piece) -> (output: PieceData) {
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

game_update :: proc(game: ^Game) {
    switch game.screen {
    case .MAIN_MENU:
        {}
    case .EDIT:
        {}
    case .GAME:
        {
            game_state := &game.state.(GameState)

            // spawn piece if needed
            if !game_state.has_lost && !game_state.has_active_piece {
                game_state.active_piece = game_state.next_piece
                game_state.next_piece = game_state.piece_buffer[rand.int_max(game_state.piece_count)]
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
                    game_state.grid[row_idx * GRID_WIDTH + col_idx] = 0
                }
            }

            update_score(game_state, filled_line_count)

            // check for level up
            game_state.level_lines_cleared += filled_line_count
            if game_state.level_lines_cleared >= LINES_PER_LEVEL {
                game_state.level_lines_cleared = 0
                game_state.ticks_per_drop = max(1, game_state.ticks_per_drop - 10)
                game_state.ticks_until_drop = game_state.ticks_per_drop
            }
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
