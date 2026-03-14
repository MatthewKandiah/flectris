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
    global: GlobalState,
}

MAX_PIECES :: 8
GlobalState :: struct {
    piece_buffer: [MAX_PIECES]Piece,
}

MainMenuState :: struct {}

initial_main_menu_state :: MainMenuState{}

EditState :: struct {
    piece_buffer:     [MAX_PIECES]Piece,
    active_piece_idx: int,
}

initial_edit_state :: proc(game: Game) -> EditState {
    return EditState{piece_buffer = game.global.piece_buffer, active_piece_idx = 0}
}

LINES_PER_LEVEL :: 20
GridData :: [GRID_WIDTH * GRID_HEIGHT]int
GameState :: struct {
    has_lost:              bool,
    grid:                  GridData,
    piece_buffer:          [MAX_PIECES]GamePiece,
    piece_count:           int,
    active_piece:          GamePiece,
    next_piece:            GamePiece,
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
    filled:     PieceData,
    rot_centre: GridPos,
}

GamePiece :: struct {
    using piece:  Piece,
    bounding_dim: GridDim,
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
    rot_centre = {x = 4, y = 1},
}

initial_game_state :: proc(game: Game) -> GameState {
    piece_buffer, piece_count := get_game_pieces_from_global_state(game.global)
    return GameState {
        grid = {},
        active_piece = {},
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
    }
}

get_game_pieces_from_global_state :: proc(
    global: GlobalState,
) -> (
    piece_buffer: [MAX_PIECES]GamePiece,
    piece_count: int,
) {
    for global_piece in global.piece_buffer {
        if piece_is_empty(global_piece) {continue}
        piece_buffer[piece_count] = game_piece_from_piece(global_piece)
        piece_count += 1
    }
    if piece_count == 0 {panic("Cannot start a game with no pieces")}
    return
}

game_piece_from_piece :: proc(piece: Piece) -> (game_piece: GamePiece) {
    bounding_box_pos, bounding_box_dim := get_piece_bounding_box(piece)
    game_piece.bounding_dim = bounding_box_dim
    game_piece.rot_centre = {
        x = piece.rot_centre.x - bounding_box_pos.x,
        y = piece.rot_centre.y - bounding_box_pos.y,
    }
    for &cell, idx in game_piece.filled {
        idx_in_original_piece := cast(i32)idx + bounding_box_pos.x + (bounding_box_pos.y * PIECE_WIDTH)
        if idx_in_original_piece >= PIECE_WIDTH * PIECE_HEIGHT {continue}
        cell = piece.filled[idx_in_original_piece]
    }
    return
}

get_piece_bounding_box :: proc(piece: Piece) -> (pos: GridPos, dim: GridDim) {
    x_min, y_min, x_max, y_max: int
    x_min = max(int)
    y_min = max(int)
    for cell, idx in piece.filled {
        if cell == 0 {continue}
        x_cell := idx % PIECE_WIDTH
        y_cell := idx / PIECE_WIDTH

        x_min = min(x_min, x_cell)
        x_max = max(x_max, x_cell)
        y_min = min(y_min, y_cell)
        y_max = max(y_max, y_cell)
    }

    pos = GridPos {
        x = cast(i32)x_min,
        y = cast(i32)y_min,
    }
    dim = GridDim {
        w = cast(i32)(x_max - x_min + 1),
        h = cast(i32)(y_max - y_min + 1),
    }
    return
}

piece_is_empty :: proc(piece: Piece) -> bool {
    for cell in piece.filled {
        if cell != 0 {return false}
    }
    return true
}

init_game :: proc() -> Game {
    return Game {
        screen = .MAIN_MENU,
        state = initial_main_menu_state,
        global = {piece_buffer = [MAX_PIECES]Piece{piece1, piece2, piece3, {}, {}, {}, {}, {}}},
    }
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
    state := game.state.(EditState)
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
                piece_data := game.state.(EditState).piece_buffer[piece_idx].filled
		rot_centre := game.state.(EditState).piece_buffer[piece_idx].rot_centre
                entity_push(
                    piece_button_entity(
                        piece_button_pos,
                        piece_button_dim,
                        piece_data,
			rot_centre,
                        edit_piece_on_clicks[piece_idx],
                    ),
                )
                if state.active_piece_idx == piece_idx {
                    entity_push(
                        piece_button_selected_box_entity(
                            Pos{x = piece_button_pos.x - horizontal_gap, y = piece_button_pos.y - vertical_gap},
                            Dim {
                                w = piece_button_dim.w + (2 * horizontal_gap),
                                h = piece_button_dim.h + (2 * vertical_gap),
                            },
                        ),
                    )
                }
            }
        }
    }

    {     // main grid
        grid_pos := Pos {
            x = 0,
            y = 0,
        }
        grid_dim := Dim {
            w = 400,
            h = 400,
        }
	active_piece := state.piece_buffer[state.active_piece_idx]
        entity_push(edit_grid_entity(grid_pos, grid_dim, active_piece.filled, active_piece.rot_centre))
        click_handler_dim := Dim {
            w = grid_dim.w / 5,
            h = grid_dim.h / 5,
        }
        for col in 0 ..= 4 {
            for row in 0 ..= 4 {
                click_handler_pos := Pos {
                    x = grid_pos.x + (cast(f32)col * click_handler_dim.w),
                    y = grid_pos.y + (cast(f32)row * click_handler_dim.h),
                }
                click_handler_idx := col + row * 5
                entity_push(
                    invisible_click_handler_entity(
                        click_handler_pos,
                        click_handler_dim,
                        edit_grid_button_on_clicks[click_handler_idx],
                    ),
                )
            }
        }
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
            } else if (key_event.type == .Press && key_event.char == .Escape) {
                exit_to_menu(game)
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
    game_state := initial_game_state(game^)
    game_state.next_piece = game_state.piece_buffer[rand.int_max(game_state.piece_count)]
    game.state = game_state
}

exit_on_click :: proc(_: ^Game) {
    glfw.SetWindowShouldClose(gc.window, true)
}

exit_to_menu :: proc(game: ^Game) {
    game.screen = .MAIN_MENU
}

edit_on_click :: proc(game: ^Game) {
    game.screen = .EDIT
    game.state = initial_edit_state(game^)
}

edit_cancel_on_click :: proc(game: ^Game) {
    game.screen = .MAIN_MENU
}

edit_exit_on_click :: proc(game: ^Game) {
    edit_state := game.state.(EditState)
    game.global.piece_buffer = edit_state.piece_buffer
    game.screen = .MAIN_MENU
}

edit_piece_on_click :: proc(game: ^Game, n: int) {
    (&game.state.(EditState)).active_piece_idx = n
}
edit_piece0_on_click :: proc(game: ^Game) {edit_piece_on_click(game, 0)}
edit_piece1_on_click :: proc(game: ^Game) {edit_piece_on_click(game, 1)}
edit_piece2_on_click :: proc(game: ^Game) {edit_piece_on_click(game, 2)}
edit_piece3_on_click :: proc(game: ^Game) {edit_piece_on_click(game, 3)}
edit_piece4_on_click :: proc(game: ^Game) {edit_piece_on_click(game, 4)}
edit_piece5_on_click :: proc(game: ^Game) {edit_piece_on_click(game, 5)}
edit_piece6_on_click :: proc(game: ^Game) {edit_piece_on_click(game, 6)}
edit_piece7_on_click :: proc(game: ^Game) {edit_piece_on_click(game, 7)}
edit_piece_on_clicks := []proc(game: ^Game) {
    edit_piece0_on_click,
    edit_piece1_on_click,
    edit_piece2_on_click,
    edit_piece3_on_click,
    edit_piece4_on_click,
    edit_piece5_on_click,
    edit_piece6_on_click,
    edit_piece7_on_click,
}

edit_grid_button_on_click :: proc(game: ^Game, n: int) {
    state := &game.state.(EditState)
    old_value := state.piece_buffer[state.active_piece_idx].filled[n]
    new_value := 0 if old_value != 0 else state.active_piece_idx + 1
    state.piece_buffer[state.active_piece_idx].filled[n] = new_value
}
edit_grid_button0_on_click :: proc(game: ^Game) {edit_grid_button_on_click(game, 0)}
edit_grid_button1_on_click :: proc(game: ^Game) {edit_grid_button_on_click(game, 1)}
edit_grid_button2_on_click :: proc(game: ^Game) {edit_grid_button_on_click(game, 2)}
edit_grid_button3_on_click :: proc(game: ^Game) {edit_grid_button_on_click(game, 3)}
edit_grid_button4_on_click :: proc(game: ^Game) {edit_grid_button_on_click(game, 4)}
edit_grid_button5_on_click :: proc(game: ^Game) {edit_grid_button_on_click(game, 5)}
edit_grid_button6_on_click :: proc(game: ^Game) {edit_grid_button_on_click(game, 6)}
edit_grid_button7_on_click :: proc(game: ^Game) {edit_grid_button_on_click(game, 7)}
edit_grid_button8_on_click :: proc(game: ^Game) {edit_grid_button_on_click(game, 8)}
edit_grid_button9_on_click :: proc(game: ^Game) {edit_grid_button_on_click(game, 9)}
edit_grid_button10_on_click :: proc(game: ^Game) {edit_grid_button_on_click(game, 10)}
edit_grid_button11_on_click :: proc(game: ^Game) {edit_grid_button_on_click(game, 11)}
edit_grid_button12_on_click :: proc(game: ^Game) {edit_grid_button_on_click(game, 12)}
edit_grid_button13_on_click :: proc(game: ^Game) {edit_grid_button_on_click(game, 13)}
edit_grid_button14_on_click :: proc(game: ^Game) {edit_grid_button_on_click(game, 14)}
edit_grid_button15_on_click :: proc(game: ^Game) {edit_grid_button_on_click(game, 15)}
edit_grid_button16_on_click :: proc(game: ^Game) {edit_grid_button_on_click(game, 16)}
edit_grid_button17_on_click :: proc(game: ^Game) {edit_grid_button_on_click(game, 17)}
edit_grid_button18_on_click :: proc(game: ^Game) {edit_grid_button_on_click(game, 18)}
edit_grid_button19_on_click :: proc(game: ^Game) {edit_grid_button_on_click(game, 19)}
edit_grid_button20_on_click :: proc(game: ^Game) {edit_grid_button_on_click(game, 20)}
edit_grid_button21_on_click :: proc(game: ^Game) {edit_grid_button_on_click(game, 21)}
edit_grid_button22_on_click :: proc(game: ^Game) {edit_grid_button_on_click(game, 22)}
edit_grid_button23_on_click :: proc(game: ^Game) {edit_grid_button_on_click(game, 23)}
edit_grid_button24_on_click :: proc(game: ^Game) {edit_grid_button_on_click(game, 24)}
edit_grid_button_on_clicks := []proc(game: ^Game) {
    edit_grid_button0_on_click,
    edit_grid_button1_on_click,
    edit_grid_button2_on_click,
    edit_grid_button3_on_click,
    edit_grid_button4_on_click,
    edit_grid_button5_on_click,
    edit_grid_button6_on_click,
    edit_grid_button7_on_click,
    edit_grid_button8_on_click,
    edit_grid_button9_on_click,
    edit_grid_button10_on_click,
    edit_grid_button11_on_click,
    edit_grid_button12_on_click,
    edit_grid_button13_on_click,
    edit_grid_button14_on_click,
    edit_grid_button15_on_click,
    edit_grid_button16_on_click,
    edit_grid_button17_on_click,
    edit_grid_button18_on_click,
    edit_grid_button19_on_click,
    edit_grid_button20_on_click,
    edit_grid_button21_on_click,
    edit_grid_button22_on_click,
    edit_grid_button23_on_click,
    edit_grid_button24_on_click,
}

Dir :: enum {
    CLOCKWISE,
    ANTICLOCKWISE,
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

get_clockwise_rotated_filled_array :: proc(piece: GamePiece) -> (output: PieceData) {
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

get_anticlockwise_rotated_filled_array :: proc(piece: GamePiece) -> (output: PieceData) {
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
