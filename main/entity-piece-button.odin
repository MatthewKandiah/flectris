package main

PieceButtonEntityData :: struct {
    piece_data: PieceData,
    rot_centre: GridPos,
}

piece_button_entity :: proc(pos: Pos, dim: Dim, piece_data: PieceData, rot_centre: GridPos, on_click: proc(_: ^Game)) -> Entity {
    return Entity {
        pos = pos,
        dim = dim,
        clickable = true,
        on_click = on_click,
        type = .PieceButton,
        data = PieceButtonEntityData{piece_data = piece_data, rot_centre = rot_centre},
    }
}

piece_button_selected_box_entity :: proc(pos: Pos, dim: Dim) -> Entity {
    return Entity{pos = pos, dim = dim, clickable = false, on_click = nil, type = .PieceButtonSelectedBox, data = {}}
}

draw_piece_button :: proc(entity: Entity) {
    data := entity.data.(PieceButtonEntityData)
    grid_dim := GridDim{w = PIECE_WIDTH, h = PIECE_HEIGHT}
    draw_grid_cells(entity.pos, entity.dim, grid_dim, data.piece_data[:], PIECE_BUTTON_Z)
    draw_grid_rot_centre(entity.pos, entity.dim, data.rot_centre, grid_dim)
}

draw_piece_button_selected_box :: proc(entity: Entity) {
    draw_rect(GREY, entity.pos, entity.dim, PIECE_BUTTON_SELECTED_BOX_Z)
}

