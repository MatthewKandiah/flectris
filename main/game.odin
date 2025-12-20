package main

import "core:fmt"
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

GameState :: struct {
    grid:                  [GRID_WIDTH * GRID_HEIGHT]bool,
    active_piece:          Piece,
    active_piece_position: GridPos,
    has_active_piece:      bool,
    ticks_until_drop:      int,
    ticks_per_drop:        int,
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
}

initial_game_state :: GameState {
    grid = {},
    active_piece = Piece {
        filled = {
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
            true,
            true,
            true,
            false,
            false, //
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
        },
        bounding_dim = {w = 3, h = 5},
    },
    active_piece_position = {x = 3, y = 10},
    has_active_piece = true,
    ticks_per_drop = 60,
    ticks_until_drop = 60,
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

update_active_piece_position :: proc(gs: ^GameState, delta_x, delta_y: i32) {
    assert(abs(delta_x) <= 1 && abs(delta_y) <= 1, "larger jumps not currently supported")
    updated_pos := GridPos {
        x = gs.active_piece_position.x + delta_x,
        y = gs.active_piece_position.y + delta_y,
    }
    if updated_pos.x < 0 {updated_pos.x = 0}
    if updated_pos.x + gs.active_piece.bounding_dim.w >
       GRID_WIDTH {updated_pos.x = GRID_WIDTH - gs.active_piece.bounding_dim.w}
    if updated_pos.y < 0 {updated_pos.y = 0}
    gs.active_piece_position = updated_pos
}

game_update :: proc(game: ^Game) {
    switch game.screen {
    case .MAIN_MENU:
        {}
    case .GAME:
        {
	    game_state := &game.state.(GameState)
	    game_state.ticks_until_drop -= 1
	    if game_state.ticks_until_drop <= 0 {
		update_active_piece_position(game_state, 0, -1)
		game_state.ticks_until_drop = game_state.ticks_per_drop
	    }
        }
    }
}
