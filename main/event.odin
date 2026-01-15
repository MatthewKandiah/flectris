package main

EVENT_BUFFER_SIZE :: 1_000
EVENT_BUFFER_COUNT := 0
EVENT_BUFFER := [EVENT_BUFFER_SIZE]Event{}

Event :: struct {
    type: EventSource,
    data: Foo
}

EventSource :: enum {
    Keyboard,
    Mouse
}

EventType :: enum {
    Press,
    Release
}

Foo :: union {
    KeyboardEvent,
    MouseEvent,
}

Key :: enum {
    Left,
    Right,
    Up,
    Down,
    Space,
    S,
    T,
}

KeyboardEvent :: struct {
    char: Key,
    type: EventType,
}

MouseButton :: enum {
    Left,
    Right,
}

MouseEvent :: struct {
    pos: Pos,
    type: EventType,
    button: MouseButton,
}
