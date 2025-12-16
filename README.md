# Flectris
Tetris but you can pick your tileset.

## Plan
- draw a menu with a button in it, when you click the button we open "the game", when you press escape it reopens the menu

## Short term plan
- flush event buffer which updates game state
- refactor game state to tagged union with separate `MenuState` and `GameState`
