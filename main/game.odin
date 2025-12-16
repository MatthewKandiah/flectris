package main

// TODO-MATT: think we want to make this a tagged union and have separate state structs for main menu, game, etc.
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
