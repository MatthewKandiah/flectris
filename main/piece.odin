package main

Piece :: struct {
    filled:     PieceData,
    rot_centre: GridPos,
}

GamePiece :: struct {
    using piece:  Piece,
    bounding_dim: GridDim,
}

Dir :: enum {
    CLOCKWISE,
    ANTICLOCKWISE,
}

piece1 :: Piece {
    filled = {
        1,
        1,
        1,
        1,
        1, //
        1,
        1,
        1,
        1,
        1, //
        1,
        1,
        1,
        1,
        0, //
        0,
        0,
        0,
        0,
        0, //
        0,
        0,
        0,
        0,
        0, //
    },
    rot_centre = {x = 1, y = 2},
}

piece2 :: Piece {
    filled = {
        2,
        2,
        0,
        0,
        0, //
        2,
        2,
        0,
        0,
        0, //
        2,
        2,
        0,
        0,
        0, //
        0,
        0,
        0,
        0,
        0, //
        0,
        0,
        0,
        0,
        0, //
    },
    rot_centre = {x = 0, y = 0},
}

piece3 :: Piece {
    filled = {
        3,
        3,
        3,
        0,
        0, //
        3,
        3,
        3,
        0,
        0, //
        3,
        3,
        3,
        0,
        0, //
        0,
        0,
        0,
        0,
        0, //
        0,
        0,
        0,
        0,
        0, //
    },
    rot_centre = {x = 4, y = 1},
}

game_pieces_from_pieces :: proc(
    global_piece_buffer: [MAX_PIECES]Piece,
) -> (
    piece_buffer: [MAX_PIECES]GamePiece,
    piece_count: int,
) {
    for global_piece in global_piece_buffer {
        if piece_is_empty(global_piece) {continue}
        piece_buffer[piece_count] = game_piece_from_piece(global_piece)
        piece_count += 1
    }
    if piece_count == 0 {panic("Cannot start a game with no pieces")}
    return
}

game_piece_from_piece :: proc(piece: Piece) -> (game_piece: GamePiece) {
    bounding_box_pos, bounding_box_dim := get_piece_bounding_box(piece)
    game_piece.bounding_dim = bounding_box_dim
    game_piece.rot_centre = {
        x = piece.rot_centre.x - bounding_box_pos.x,
        y = piece.rot_centre.y - bounding_box_pos.y,
    }
    for &cell, idx in game_piece.filled {
        idx_in_original_piece := cast(i32)idx + bounding_box_pos.x + (bounding_box_pos.y * PIECE_WIDTH)
        if idx_in_original_piece >= PIECE_WIDTH * PIECE_HEIGHT {continue}
        cell = piece.filled[idx_in_original_piece]
    }
    return
}

get_piece_bounding_box :: proc(piece: Piece) -> (pos: GridPos, dim: GridDim) {
    x_min, y_min, x_max, y_max: int
    x_min = max(int)
    y_min = max(int)
    for cell, idx in piece.filled {
        if cell == 0 {continue}
        x_cell := idx % PIECE_WIDTH
        y_cell := idx / PIECE_WIDTH

        x_min = min(x_min, x_cell)
        x_max = max(x_max, x_cell)
        y_min = min(y_min, y_cell)
        y_max = max(y_max, y_cell)
    }

    pos = GridPos {
        x = cast(i32)x_min,
        y = cast(i32)y_min,
    }
    dim = GridDim {
        w = cast(i32)(x_max - x_min + 1),
        h = cast(i32)(y_max - y_min + 1),
    }
    return
}

piece_is_empty :: proc(piece: Piece) -> bool {
    for cell in piece.filled {
        if cell != 0 {return false}
    }
    return true
}
get_clockwise_rotated_filled_array :: proc(piece: GamePiece) -> (output: PieceData) {
    // assumes zero initialised output == empty
    for j in 0 ..< piece.bounding_dim.h {
        write_col_idx := j
        for i in 0 ..< piece.bounding_dim.w {
            val := piece.filled[i + j * PIECE_WIDTH]
            write_row_idx := piece.bounding_dim.w - 1 - i
            output[write_col_idx + write_row_idx * PIECE_WIDTH] = val
        }
    }
    return
}

get_anticlockwise_rotated_filled_array :: proc(piece: GamePiece) -> (output: PieceData) {
    // assumes zero initialised output == empty
    for j in 0 ..< piece.bounding_dim.h {
        write_col_idx := piece.bounding_dim.h - 1 - j
        for i in 0 ..< piece.bounding_dim.w {
            val := piece.filled[i + j * PIECE_WIDTH]
            write_row_idx := i
            output[write_col_idx + write_row_idx * PIECE_WIDTH] = val
        }
    }
    return
}

