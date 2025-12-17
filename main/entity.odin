package main

ENTITY_BUFFER_SIZE :: 1000
ENTITY_BUFFER := [ENTITY_BUFFER_SIZE]Entity{}
ENTITY_COUNT := 0

Entity :: struct {
    pos:       Pos,
    dim:       Dim,
    clickable: bool,
    on_click:  proc(^Game),
    type:      EntityType,
    data:      EntityData,
}

EntityType :: enum {
    Button,
}

EntityData :: union {
    ButtonEntityData,
}

ButtonEntityData :: struct {
    str: []u8,
    hovered: bool,
}

entity_push :: proc(entity: Entity) {
    ENTITY_BUFFER[ENTITY_COUNT] = entity
    ENTITY_COUNT += 1
}

button_entity :: proc(pos: Pos, dim: Dim, str: []u8, hovered: bool, on_click: proc(^Game)) -> Entity {
    return Entity{pos = pos, dim = dim, clickable = true, type = .Button, on_click = on_click, data = ButtonEntityData{str = str, hovered = hovered},}
}

is_hovered :: proc(pos: Pos, dim: Dim) -> bool {
    return(
        !(gc.cursor_pos.x < pos.x ||
            gc.cursor_pos.x > pos.x + dim.w ||
            gc.cursor_pos.y < pos.y ||
            gc.cursor_pos.y > pos.y + dim.h) \
    )
}
