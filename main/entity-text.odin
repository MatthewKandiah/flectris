package main

import "core:fmt"

TextEntityData :: struct {
    str: []u8,
}

text_entity :: proc(pos: Pos, dim: Dim, str: []u8) -> Entity {
    return Entity {
	pos = pos,
	dim = dim,
	clickable = false,
	type = .Text,
	on_click = nil,
	data = TextEntityData{str = str}
    }
}

draw_text :: proc(entity: Entity) {
    data := entity.data.(TextEntityData)
    draw_rect(GREY, entity.pos, entity.dim, UI_TEXT_BACKGROUND_Z)
    draw_string(data.str, entity.pos, entity.dim, UI_TEXT_Z)
}

