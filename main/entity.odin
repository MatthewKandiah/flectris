package main

import "core:fmt"

ENTITY_BUFFER_SIZE :: 1000
ENTITY_BUFFER := [ENTITY_BUFFER_SIZE]Entity{}
ENTITY_COUNT := 0

Entity :: struct {
    pos:       Pos,
    dim:       Dim,
    clickable: bool,
    right_clickable: bool,
    on_click:  proc(^Game),
    type:      EntityType,
    data:      EntityData,
}

EntityType :: enum {
    InvisibleClickHandler,
    TextButton,
    PieceButton,
    PieceButtonSelectedBox,
    Grid,
    GamePanel,
    EditGrid,
    Text,
}

EntityData :: union {
    InvisibleClickHandlerEntityData,
    TextButtonEntityData,
    PieceButtonEntityData,
    GridEntityData,
    GamePanelEntityData,
    EditGridEntityData,
    TextEntityData,
}

entity_push :: proc(entity: Entity) {
    ENTITY_BUFFER[ENTITY_COUNT] = entity
    ENTITY_COUNT += 1
}

is_hovered :: proc(pos: Pos, dim: Dim) -> bool {
    return(
        !(gc.cursor_pos.x < pos.x ||
            gc.cursor_pos.x > pos.x + dim.w ||
            gc.cursor_pos.y < pos.y ||
            gc.cursor_pos.y > pos.y + dim.h) \
    )
}
