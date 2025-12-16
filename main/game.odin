package main

Game :: struct {
    screen: Screen,
    state:  union {
        MainMenuState,
        GameState,
    },
}

MainMenuState :: struct {
    start_button_clicked: bool,
}

initial_main_menu_state :: MainMenuState {
    start_button_clicked = false,
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

overlaps_start_button :: proc(pos: Pos) -> bool {
    button_pos := Pos {
        x = 100,
        y = 100,
    }
    button_dim := Dim {
        w = 120,
        h = 120,
    }
    return(
        !(pos.x < button_pos.x ||
            pos.x > button_pos.x + button_dim.w ||
            pos.y < button_pos.y ||
            pos.y > button_pos.y + button_dim.h) \
    )
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
                    if (mouse_event.button == .Left &&
                           mouse_event.type == .Press &&
                        overlaps_start_button(mouse_event.pos)) {
			game.screen = .GAME
			game.state = initial_game_state
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
