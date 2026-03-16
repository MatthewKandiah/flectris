package main

TextButtonEntityData :: struct {
    str:     []u8,
    hovered: bool,
}

text_button_entity :: proc(pos: Pos, dim: Dim, str: []u8, hovered: bool, on_click: proc(_: ^Game)) -> Entity {
    return Entity {
        pos = pos,
        dim = dim,
        clickable = true,
        type = .TextButton,
        on_click = on_click,
        data = TextButtonEntityData{str = str, hovered = hovered},
    }
}

draw_text_button :: proc(entity: Entity) {
    data := entity.data.(TextButtonEntityData)
    colour := RED if data.hovered else BLUE
    draw_rect(colour, entity.pos, entity.dim, UI_TEXT_BACKGROUND_Z)
    draw_string(data.str, entity.pos, entity.dim, UI_TEXT_Z)
}

