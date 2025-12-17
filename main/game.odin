package main

import "core:fmt"

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
    count: int,
}

initial_game_state :: GameState {
    count = 3,
}

init_game :: proc() -> Game {
    return Game{screen = .MAIN_MENU, state = initial_main_menu_state}
}

game_populate_entities :: proc(game: Game) {
    ENTITY_COUNT = 0
    switch game.screen {
    case .GAME:
        return
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
                        entity.on_click()
                    }
                }
            }
        }
    case .GAME:
        {
            switch event.type {
            case .Keyboard:
                {
                    key_event := event.data.(KeyboardEvent)
                    if (key_event.type == .Press && key_event.char == .Space) {
                        (&game.state.(GameState)).count -= 1
                        if game.state.(GameState).count <= 0 {
                            game.screen = .MAIN_MENU
                            game.state = initial_main_menu_state
                        }
                    }
                }
            case .Mouse:
                {
                    return
                }
            }
        }
    }
}

Screen :: enum {
    MAIN_MENU,
    GAME,
}

start_game_on_click :: proc() {
    fmt.println("start")
}

exit_on_click :: proc() {
    fmt.println("exit")
}
