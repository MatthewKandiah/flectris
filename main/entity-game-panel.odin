package main

GamePanelEntityData :: struct {
    score:       int,
    next_piece:  Piece,
    saved_piece: Piece,
}

game_panel_entity :: proc(pos: Pos, dim: Dim, score: int, next_piece: Piece, saved_piece: Piece) -> Entity {
    data := GamePanelEntityData {
        score       = score,
        next_piece  = next_piece,
        saved_piece = saved_piece,
    }
    return Entity{pos = pos, dim = dim, type = .GamePanel, data = data}
}

draw_game_panel :: proc(entity: Entity) {
    draw_rect(DARK_GREY, entity.pos, entity.dim, GAME_PANEL_Z)

    data := entity.data.(GamePanelEntityData)
    panel_top_bot_margin :: 10
    panel_left_right_margin :: 10
    available_width := entity.dim.w - 2 * panel_left_right_margin
    available_height := entity.dim.h - 2 * panel_top_bot_margin

    score_dim := Dim {
        w = available_width,
        h = available_width / 5,
    }
    score_pos := Pos {
        x = entity.pos.x + panel_left_right_margin,
        y = entity.pos.y + entity.dim.h - panel_top_bot_margin - score_dim.h,
    }
    draw_number(data.score, 7, score_pos, score_dim, UI_TEXT_Z)

    available_grids_height := entity.dim.h - score_dim.h - (4 * panel_top_bot_margin)
    max_pieces_fit := available_grids_height >= available_width * 2
    piece_grid_size := available_width if max_pieces_fit else available_grids_height / 2
    piece_pos_x := entity.pos.x + panel_left_right_margin if max_pieces_fit else entity.pos.x + (entity.dim.w - piece_grid_size) / 2

    piece_dim := Dim {
        w = piece_grid_size,
        h = piece_grid_size,
    }
    next_piece_pos := Pos {
        x = piece_pos_x,
        y = score_pos.y - panel_top_bot_margin - piece_dim.h,
    }
    saved_piece_pos := Pos {
        x = piece_pos_x,
        y = next_piece_pos.y - panel_top_bot_margin - piece_dim.h,
    }
    draw_grid_cells(
        next_piece_pos,
        piece_dim,
        GridDim{w = PIECE_WIDTH, h = PIECE_HEIGHT},
        data.next_piece.filled[:],
        UI_TEXT_Z,
    )
    draw_grid_cells(
        saved_piece_pos,
        piece_dim,
        GridDim{w = PIECE_WIDTH, h = PIECE_HEIGHT},
        data.saved_piece.filled[:],
        UI_TEXT_Z,
    )
}
