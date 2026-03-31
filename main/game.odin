package main

import "core:fmt"
import "core:math/rand"
import "core:strings"
import "vendor:glfw"

GRID_WIDTH :: 10
GRID_HEIGHT :: 20

PIECE_WIDTH :: 5
PIECE_HEIGHT :: 5
MAX_PIECES :: 8

LINES_PER_LEVEL :: 20

SIDE_PANEL_WIDTH :: 400

GridData :: [GRID_WIDTH * GRID_HEIGHT]int
PieceData :: [PIECE_WIDTH * PIECE_HEIGHT]int

Game :: struct {
    screen: Screen,
    state:  union {
        GameState,
        EditState,
        MainMenuState,
    },
    global: GlobalState,
}

Screen :: enum {
    MAIN_MENU,
    GAME,
    EDIT,
}

init_game :: proc() -> Game {
    initial_pieces := [MAX_PIECES]Piece{piece1, piece2, piece3, piece4, piece5, piece6, piece7, {}}
    return Game{screen = .MAIN_MENU, state = main_menu_state(initial_pieces), global = {piece_buffer = initial_pieces}}
}

game_populate_entities :: proc(game: ^Game) {
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

game_screen_populate_entities :: proc(game: ^Game) {
    game_state := game.state.(GameState)

    panel_dim := Dim {
        w = SIDE_PANEL_WIDTH,
        h = cast(f32)(gc.surface_extent.height),
    }
    panel_pos := Pos {
        x = cast(f32)(gc.surface_extent.width) - panel_dim.w,
        y = 0,
    }

    entity_push(
        game_panel_entity(panel_pos, panel_dim, game_state.score, game_state.next_piece, game_state.saved_piece),
    )

    grid_pos, grid_dim := get_fitted_grid_pos_dim(GridDim{w = GRID_WIDTH, h = GRID_HEIGHT}, panel_dim.w)
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

main_menu_screen_populate_entities :: proc(game: ^Game) {
    start_str := "START"
    surface_dim := extent_to_dim(gc.surface_extent)
    state := &game.state.(MainMenuState)

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

    import_str := "IMPORT"
    export_str := "EXPORT"
    import_button_pos := Pos {
        x = edit_button_pos.x - button_dim.w / 2 - 10,
        y = start_button_pos.y - 4.5 * button_dim.h,
    }
    export_button_pos := Pos {
        x = edit_button_pos.x + button_dim.w / 2 + 10,
        y = start_button_pos.y - 4.5 * button_dim.h,
    }

    piece_config_str_pos := Pos {
        x = 20,
        y = 20,
    }
    piece_config_str_dim := Dim {
        w = surface_dim.w - 40,
        h = 20,
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
    entity_push(
        text_button_entity(
            import_button_pos,
            button_dim,
            transmute([]u8)import_str,
            is_hovered(import_button_pos, button_dim),
            import_on_click,
        ),
    )
    entity_push(
        text_button_entity(
            export_button_pos,
            button_dim,
            transmute([]u8)export_str,
            is_hovered(export_button_pos, button_dim),
            export_on_click,
        ),
    )
    entity_push(text_entity(piece_config_str_pos, piece_config_str_dim, state.piece_config_string[:]))
}

edit_screen_populate_entities :: proc(game: ^Game) {
    surface_dim := extent_to_dim(gc.surface_extent)
    state := game.state.(EditState)
    {     // side panel
        vertical_gap: f32 = 10
        horizontal_gap: f32 = 5

        piece_button_dim := Dim {
            w = (SIDE_PANEL_WIDTH - (3 * horizontal_gap)) / 2,
            h = (surface_dim.h - (7 * vertical_gap)) / 6,
        }
        text_button_dim := Dim {
            w = piece_button_dim.w * 2 + horizontal_gap,
            h = piece_button_dim.h,
        }

        exit_str := "EXIT"
        exit_button_pos := Pos {
            x = surface_dim.w - SIDE_PANEL_WIDTH + horizontal_gap,
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
        grid_pos, grid_dim := get_fitted_grid_pos_dim(GridDim{w = PIECE_WIDTH, h = PIECE_HEIGHT}, SIDE_PANEL_WIDTH)
        active_piece := state.piece_buffer[state.active_piece_idx]
        entity_push(edit_grid_entity(grid_pos, grid_dim, active_piece.filled, active_piece.rot_centre))
        click_handler_dim := Dim {
            w = grid_dim.w / PIECE_WIDTH,
            h = grid_dim.h / PIECE_HEIGHT,
        }
        {     // left clickable invisible entities
            for col in 0 ..= 4 {
                for row in 0 ..= 4 {
                    click_handler_pos := Pos {
                        x = grid_pos.x + (cast(f32)col * click_handler_dim.w),
                        y = grid_pos.y + (cast(f32)row * click_handler_dim.h),
                    }
                    click_handler_idx := col + row * PIECE_WIDTH
                    entity_push(
                        invisible_click_handler_entity(
                            click_handler_pos,
                            click_handler_dim,
                            edit_grid_button_on_clicks[click_handler_idx],
                            .Left,
                        ),
                    )
                }
            }
        }
        {     // right clickable invisible entities
            for col in 0 ..= 5 {
                for row in 0 ..= 5 {
                    click_handler_pos := Pos {
                        x = grid_pos.x + (cast(f32)col * click_handler_dim.w) - click_handler_dim.w / 2,
                        y = grid_pos.y + (cast(f32)row * click_handler_dim.h) - click_handler_dim.h / 2,
                    }
                    click_handler_idx := col + row * (PIECE_WIDTH + 1)
                    entity_push(
                        invisible_click_handler_entity(
                            click_handler_pos,
                            click_handler_dim,
                            edit_grid_intersection_on_clicks[click_handler_idx],
                            .Right,
                        ),
                    )
                }
            }
        }
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

main_menu_screen_handle_event :: proc(game: ^Game, event: Event) {
    switch event.source {
    case .Keyboard:
        return

    case .Mouse:
        handle_mouse_event(game, event.data.(MouseEvent))
    }
}

edit_screen_handle_event :: proc(game: ^Game, event: Event) {
    switch event.source {
    case .Keyboard:
        return
    case .Mouse:
        handle_mouse_event(game, event.data.(MouseEvent))
    }
}

game_screen_handle_event :: proc(game: ^Game, event: Event) {
    game_state := &game.state.(GameState)
    switch event.source {
    case .Keyboard:
        {
            key_event := event.data.(KeyboardEvent)
            if (key_event.type == .Press && key_event.char == .Space) {
                if game_state.can_save_piece {
                    save_piece(game_state)
                }
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
        if mouse_event.button == .Left && !entity.clickable {continue}
        if mouse_event.button == .Right && !entity.right_clickable {continue}
        if !is_hovered(entity.pos, entity.dim) {continue}
        if entity.on_click == nil {unreachable()}
        entity.on_click(game)
    }
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

import_on_click :: proc(game: ^Game) {
    str := glfw.GetClipboardString(gc.window)
    assert(len(str) == CONFIG_STRING_LENGTH * MAX_PIECES)
    bytes := transmute([]u8)str
    buf := [CONFIG_STRING_LENGTH * MAX_PIECES]u8{}
    for b, idx in bytes {
	buf[idx] = b
    }
    state := &game.state.(MainMenuState)
    // TODO-NEXT: handle bad imports gracefully
    pieces := decode_string_to_piece_config(buf)
    state.piece_config_string = buf
    game.global.piece_buffer = pieces
}

export_on_click :: proc(game: ^Game) {
    str := string((&game.state.(MainMenuState)).piece_config_string[:])
    cstr := strings.clone_to_cstring(str)
    defer {delete(cstr)}
    glfw.SetClipboardString(gc.window, cstr)
}

edit_cancel_on_click :: proc(game: ^Game) {
    game.screen = .MAIN_MENU    
    game.state = main_menu_state(game.global.piece_buffer)
}

edit_exit_on_click :: proc(game: ^Game) {
    piece_buffer := game.state.(EditState).piece_buffer
    game.global.piece_buffer = piece_buffer
    game.screen = .MAIN_MENU
    game.state = main_menu_state(piece_buffer)
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

edit_grid_intersection_on_click :: proc(game: ^Game, n: i32) {
    state := &game.state.(EditState)
    new_value := GridPos {
        x = n % (PIECE_WIDTH + 1),
        y = n / (PIECE_WIDTH + 1),
    }
    state.piece_buffer[state.active_piece_idx].rot_centre = new_value
}
edit_grid_intersection0_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 0)}
edit_grid_intersection1_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 1)}
edit_grid_intersection2_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 2)}
edit_grid_intersection3_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 3)}
edit_grid_intersection4_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 4)}
edit_grid_intersection5_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 5)}
edit_grid_intersection6_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 6)}
edit_grid_intersection7_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 7)}
edit_grid_intersection8_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 8)}
edit_grid_intersection9_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 9)}
edit_grid_intersection10_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 10)}
edit_grid_intersection11_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 11)}
edit_grid_intersection12_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 12)}
edit_grid_intersection13_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 13)}
edit_grid_intersection14_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 14)}
edit_grid_intersection15_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 15)}
edit_grid_intersection16_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 16)}
edit_grid_intersection17_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 17)}
edit_grid_intersection18_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 18)}
edit_grid_intersection19_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 19)}
edit_grid_intersection20_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 20)}
edit_grid_intersection21_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 21)}
edit_grid_intersection22_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 22)}
edit_grid_intersection23_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 23)}
edit_grid_intersection24_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 24)}
edit_grid_intersection25_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 25)}
edit_grid_intersection26_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 26)}
edit_grid_intersection27_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 27)}
edit_grid_intersection28_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 28)}
edit_grid_intersection29_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 29)}
edit_grid_intersection30_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 30)}
edit_grid_intersection31_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 31)}
edit_grid_intersection32_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 32)}
edit_grid_intersection33_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 33)}
edit_grid_intersection34_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 34)}
edit_grid_intersection35_on_click :: proc(game: ^Game) {edit_grid_intersection_on_click(game, 35)}
edit_grid_intersection_on_clicks := []proc(_: ^Game) {
    edit_grid_intersection0_on_click,
    edit_grid_intersection1_on_click,
    edit_grid_intersection2_on_click,
    edit_grid_intersection3_on_click,
    edit_grid_intersection4_on_click,
    edit_grid_intersection5_on_click,
    edit_grid_intersection6_on_click,
    edit_grid_intersection7_on_click,
    edit_grid_intersection8_on_click,
    edit_grid_intersection9_on_click,
    edit_grid_intersection10_on_click,
    edit_grid_intersection11_on_click,
    edit_grid_intersection12_on_click,
    edit_grid_intersection13_on_click,
    edit_grid_intersection14_on_click,
    edit_grid_intersection15_on_click,
    edit_grid_intersection16_on_click,
    edit_grid_intersection17_on_click,
    edit_grid_intersection18_on_click,
    edit_grid_intersection19_on_click,
    edit_grid_intersection20_on_click,
    edit_grid_intersection21_on_click,
    edit_grid_intersection22_on_click,
    edit_grid_intersection23_on_click,
    edit_grid_intersection24_on_click,
    edit_grid_intersection25_on_click,
    edit_grid_intersection26_on_click,
    edit_grid_intersection27_on_click,
    edit_grid_intersection28_on_click,
    edit_grid_intersection29_on_click,
    edit_grid_intersection30_on_click,
    edit_grid_intersection31_on_click,
    edit_grid_intersection32_on_click,
    edit_grid_intersection33_on_click,
    edit_grid_intersection34_on_click,
    edit_grid_intersection35_on_click,
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
                replace_active_piece_with_next(game_state)
                game_state.active_piece_position = GridPos {
                    x = GRID_WIDTH / 2 - 1,
                    y = GRID_HEIGHT,
                }
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
