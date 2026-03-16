package main

GamePanelEntityData :: struct {
    score:      int,
    next_piece: Piece,
}

game_panel_entity :: proc(pos: Pos, dim: Dim, score: int, next_piece: Piece) -> Entity {
    data := GamePanelEntityData {
        score      = score,
        next_piece = next_piece,
    }
    return Entity{pos = pos, dim = dim, type = .GamePanel, data = data}
}

draw_game_panel :: proc(entity: Entity) {
    data := entity.data.(GamePanelEntityData)
    panel_top_bot_margin :: 10
    panel_left_right_margin :: 5

    score_dim := Dim {
        w = entity.dim.w - 2 * panel_left_right_margin,
        h = entity.dim.w / 5,
    }
    score_pos := Pos {
        x = entity.pos.x + panel_left_right_margin,
        y = entity.pos.y + entity.dim.h - panel_top_bot_margin - score_dim.h,
    }

    next_piece_size := entity.dim.w - 2 * panel_left_right_margin
    next_piece_dim := Dim {
        w = next_piece_size,
        h = next_piece_size,
    }
    next_piece_pos := Pos {
        x = entity.pos.x + panel_left_right_margin,
        y = score_pos.y - panel_top_bot_margin - next_piece_dim.h,
    }

    draw_rect(DARK_GREY, entity.pos, entity.dim, GAME_PANEL_Z)
    draw_number(data.score, 7, score_pos, score_dim, UI_TEXT_Z)
    draw_grid_cells(
        next_piece_pos,
        next_piece_dim,
        GridDim{w = PIECE_WIDTH, h = PIECE_HEIGHT},
        data.next_piece.filled[:],
        UI_TEXT_Z,
    )
}

