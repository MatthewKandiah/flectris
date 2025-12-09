package main

Game :: struct {
    screen: Screen,
}

init_game :: proc() -> Game {
    return Game {
	screen = .MAIN_MENU
    }
}

Screen :: enum {
    MAIN_MENU,
    GAME,
}
