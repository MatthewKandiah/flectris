package main

InvisibleClickHandlerEntityData :: struct {}

invisible_click_handler_entity :: proc(
    pos: Pos,
    dim: Dim,
    on_click: proc(_: ^Game),
    mouse_button: MouseButton,
) -> Entity {
    return Entity {
        pos = pos,
        dim = dim,
        clickable = mouse_button == .Left,
        right_clickable = mouse_button == .Right,
        type = .InvisibleClickHandler,
        on_click = on_click,
        data = InvisibleClickHandlerEntityData{},
    }
}
