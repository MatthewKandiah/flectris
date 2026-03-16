package main

InvisibleClickHandlerEntityData :: struct {}

invisible_click_handler_entity :: proc(pos: Pos, dim: Dim, on_click: proc(_: ^Game)) -> Entity {
    return Entity {
        pos = pos,
        dim = dim,
        clickable = true,
        type = .InvisibleClickHandler,
        on_click = on_click,
        data = InvisibleClickHandlerEntityData{},
    }
}

