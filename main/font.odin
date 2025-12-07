package main

get_ascii_font_texture_data :: proc(char: u8) -> TextureData {
    if (char >= 'A' && char <= 'Z') {
	// first row
	return {
	    base = {x = 8 * cast(f32)(char - 'A'), y = 0},
	    dim = {w = 8, h = 16},
	}
    }
    if (char >= '1' && char <= '9') {
	// second row
	return {
	    base = {x = 8 * cast(f32)(char - '1'), y = 16},
	    dim = {w = 8, h = 16},
	}
    }
    if (char == '0') {
	return {
	    base = {x = 8 * 9, y = 16},
	    dim = {w = 8, h = 16},
	}
    }
    unreachable()
}
