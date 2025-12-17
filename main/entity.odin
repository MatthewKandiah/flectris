package main

ENTITY_BUFFER_SIZE :: 1000
ENTITY_BUFFER := [ENTITY_BUFFER_SIZE]Entity{}
ENTITY_COUNT := 0

Entity :: struct {
    pos:       Pos,
    dim:       Dim,
    clickable: bool,
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

button_entity :: proc(pos: Pos, dim: Dim, str: []u8, hovered: bool) -> Entity {
    return Entity{pos = pos, dim = dim, clickable = true, type = .Button, data = ButtonEntityData{str = str, hovered = hovered},}
}
