package main

get_cell_sprite_texture_data :: proc(n: int) -> TextureData {
    assert(n >= 0 && n < 8, "Check that you are referring to an actual sprite in the sheet")
    return TextureData {
	base = Pos{x = cast(f32)(n * 32), y = 32},
	dim = Dim{w = 32, h = 32},
	tex_idx = SPRITE_TEXTURE_INDEX,
    }
}
