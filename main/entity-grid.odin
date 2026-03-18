package main

import "core:fmt"

GridEntityData :: struct {
    cells:            GridData,
    rot_centre:       GridPos,
    has_active_piece: bool,
}

EditGridEntityData :: struct {
    piece_data: PieceData,
    rot_centre: GridPos,
}

grid_entity :: proc(
    pos: Pos,
    dim: Dim,
    filled_grid: [GRID_WIDTH * GRID_HEIGHT]int,
    has_active_piece: bool,
    active_piece_position: GridPos,
    active_piece: Piece,
) -> Entity {
    data := GridEntityData {
        cells = filled_grid,
        has_active_piece = has_active_piece,
        rot_centre = GridPos {
            x = active_piece_position.x + active_piece.rot_centre.x,
            y = active_piece_position.y + active_piece.rot_centre.y,
        },
    }
    if has_active_piece {
        for val, idx in active_piece.filled {
            if val == 0 {continue}
            grid_pos := GridPos {
                x = active_piece_position.x + cast(i32)idx % PIECE_WIDTH,
                y = active_piece_position.y + cast(i32)idx / PIECE_WIDTH,
            }
            if grid_pos.y >= GRID_HEIGHT {continue}
            data.cells[GRID_WIDTH * grid_pos.y + grid_pos.x] = val
        }
    }
    return Entity{pos = pos, dim = dim, data = data, type = .Grid}
}

edit_grid_entity :: proc(pos: Pos, dim: Dim, piece_data: PieceData, rot_centre: GridPos) -> Entity {
    data := EditGridEntityData {
        piece_data = piece_data,
        rot_centre = rot_centre,
    }
    return Entity{pos = pos, dim = dim, type = .EditGrid, data = data}
}

draw_grid :: proc(entity: Entity) {
    data := entity.data.(GridEntityData)
    draw_grid_cells(entity.pos, entity.dim, GridDim{w = GRID_WIDTH, h = GRID_HEIGHT}, data.cells[:], GRID_CELL_Z)
    if data.has_active_piece {
        draw_grid_rot_centre(entity.pos, entity.dim, data.rot_centre, GridDim{w = GRID_WIDTH, h = GRID_HEIGHT})
    }
}

draw_edit_grid :: proc(entity: Entity) {
    data := entity.data.(EditGridEntityData)

    grid_dim := GridDim {
        w = PIECE_WIDTH,
        h = PIECE_HEIGHT,
    }
    draw_grid_cells(entity.pos, entity.dim, grid_dim, data.piece_data[:], GRID_CELL_Z)
    draw_grid_rot_centre(entity.pos, entity.dim, data.rot_centre, grid_dim)
}


draw_grid_rot_centre :: proc(screen_pos: Pos, screen_dim: Dim, rot_centre: GridPos, grid_dim: GridDim) {
    if rot_centre.x > grid_dim.w {return}
    if rot_centre.x < 0 {return}
    if rot_centre.y > grid_dim.h {return}
    if rot_centre.y < 0 {return}

    cell_dim := Dim {
        w = screen_dim.w / cast(f32)grid_dim.w,
        h = screen_dim.h / cast(f32)grid_dim.h,
    }
    texture_data := get_cell_sprite_texture_data(5)
    rot_centre_scale: f32 = 5
    rot_centre_dim := Dim {
        w = cell_dim.w / rot_centre_scale,
        h = cell_dim.h / rot_centre_scale,
    }
    rot_centre_pos := Pos {
        x = screen_pos.x + (cast(f32)rot_centre.x * cell_dim.w) - (rot_centre_dim.w / 2),
        y = screen_pos.y + (cast(f32)rot_centre.y * cell_dim.h) - (rot_centre_dim.h / 2),
    }
    draw_sprite(texture_data, rot_centre_pos, rot_centre_dim, 1, false, {})
}

draw_grid_cells :: proc(screen_pos: Pos, screen_dim: Dim, grid_dim: GridDim, cells: []int, z: f32) {
    cell_dim := Dim {
        w = screen_dim.w / cast(f32)grid_dim.w,
        h = screen_dim.h / cast(f32)grid_dim.h,
    }
    empty_texture_data := get_cell_sprite_texture_data(6)
    empty_debug_colour := BLUE
    filled_texture_data := get_cell_sprite_texture_data(7)
    filled_debug_colour := RED
    for value, idx in cells {
        col_idx := idx % cast(int)grid_dim.w
        row_idx := idx / cast(int)grid_dim.w
        cell_pos := Pos {
            x = screen_pos.x + cast(f32)col_idx * cell_dim.w,
            y = screen_pos.y + cast(f32)row_idx * cell_dim.h,
        }
        draw_sprite(get_cell_sprite_texture_data(value), cell_pos, cell_dim, z, false, {})
    }
}

get_fitted_grid_pos_dim :: proc(input_grid_dim: GridDim, panel_width: f32) -> (pos: Pos, dim: Dim) {
    grid_available_space := Dim {
        w = cast(f32)gc.surface_extent.width - panel_width,
        h = cast(f32)gc.surface_extent.height,
    }
    grid_w_over_h := cast(f32)input_grid_dim.w / cast(f32)input_grid_dim.h
    grid_available_space_w_over_h := grid_available_space.w / grid_available_space.h
    if (grid_w_over_h > grid_available_space_w_over_h) {
        // grid fills available width
        height := grid_available_space.w / grid_w_over_h
        dim = {
            w = grid_available_space.w,
            h = height,
        }
        unfilled_height := grid_available_space.h - height
        pos = {
            x = 0,
            y = unfilled_height / 2,
        }
    } else {
        // grid fills available height
        width := grid_available_space.h * grid_w_over_h
        dim = {
            w = width,
            h = grid_available_space.h,
        }
        unfilled_width := grid_available_space.w - width
        pos = {
            x = unfilled_width / 2,
            y = 0,
        }
    }

    return
}
