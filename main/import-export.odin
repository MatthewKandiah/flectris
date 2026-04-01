package main

import "core:fmt"
import "core:math"
import "core:mem"
import "core:testing"

CONFIG_STRING_LENGTH :: 6

// multiple returns to indicate success/failure
decode_string_to_piece_config :: proc(input: [CONFIG_STRING_LENGTH * MAX_PIECES]u8) -> [MAX_PIECES]Piece {
    encoded_pieces: [MAX_PIECES]u32
    buf: [CONFIG_STRING_LENGTH]u8
    for i in 0 ..< MAX_PIECES {
        for j in 0 ..< CONFIG_STRING_LENGTH {
            buf[j] = input[i * CONFIG_STRING_LENGTH + j]
        }
        encoded_pieces[i] = string_to_encoded_piece(buf)
    }
    return decode_piece_config(encoded_pieces)
}

encode_piece_config_to_string :: proc(input: [MAX_PIECES]Piece) -> (output: [CONFIG_STRING_LENGTH * MAX_PIECES]u8) {
    pieces := encode_piece_config(input)
    for piece, idx in pieces {
        chars := encoded_piece_to_string(piece)
        for c, c_idx in chars {
            output[idx * CONFIG_STRING_LENGTH + c_idx] = c
        }
    }
    return
}

pow :: proc(input: u32, exponent: u32) -> (result: u32) {
    result = 1
    exponent := exponent
    for exponent > 0 {
        result *= input
        exponent -= 1
    }
    return
}

string_to_encoded_piece :: proc(input: [CONFIG_STRING_LENGTH]u8) -> (output: u32) {
    for digit, idx in input {
	digit_val := ascii_char_to_value(digit)
        output += cast(u32)digit_val * pow(36, cast(u32)(len(input) - 1 - idx))
    }
    return
}

ascii_char_to_value :: proc(c: u8) -> u32 {
    switch c {
    case '0'..='9':
	return cast(u32)(c - '0')
    case 'A'..='Z':
	return cast(u32)(c - 'A' + 10)
    case:
	panic("Unexpected value c out of range")
    }
}

encoded_piece_to_string :: proc(input: u32) -> (output: [CONFIG_STRING_LENGTH]u8) {
    // max u32 = 4,294,967,295
    // 36 ^ 0 = 1
    // 36 ^ 1 = 36
    // 36 ^ 2 = 1,296
    // 36 ^ 3 = 46,656
    // 36 ^ 4 = 1,679,616
    // 36 ^ 5 = 60,466,176
    // 36 ^ 6 = 2,176,782,336
    // 36 ^ 7 = 78,364,164,096

    base_36_digit_to_char :: proc(digit: u32) -> u8 {
        switch digit {
        case 0 ..= 9:
            return cast(u8)(digit + '0')
        case 10 ..= 35:
            return cast(u8)(digit - 10 + 'A')
        case:
            panic("Unexpected digit > 35")
        }
    }

    numerator := input
    for i in 0 ..< len(output) {
        output_digit_exponent := cast(u32)(len(output) - 1 - i)
        output_digit_val := pow(36, output_digit_exponent)
        output[i] = base_36_digit_to_char(numerator / output_digit_val)
        numerator %= output_digit_val
    }
    return
}

decode_piece_config :: proc(inputs: [MAX_PIECES]u32) -> (pieces: [MAX_PIECES]Piece) {
    for input, idx in inputs {
        rot_centre_x := (input & 0b111_000_00000_00000_00000_00000_00000) >> 28
        assert(rot_centre_x >= 0 && rot_centre_x < 6, fmt.tprintf("Unexpected decoded x value: %d", rot_centre_x))
        rot_centre_y := (input & 0b000_111_00000_00000_00000_00000_00000) >> 25
        assert(rot_centre_y >= 0 && rot_centre_y < 6, fmt.tprintf("Unexpected decoded y value: %d", rot_centre_y))
        filled := input & 0b000_000_11111_11111_11111_11111_11111

        pieces[idx].rot_centre = GridPos {
            x = cast(i32)rot_centre_x,
            y = cast(i32)rot_centre_y,
        }

        padded_filled_bools := piece_u32_to_binary(filled)
        filled_bools := padded_filled_bools[6:]
        for b, filled_idx in filled_bools {
            if !b {continue}
            pieces[idx].filled[filled_idx] = idx + 1
        }
    }
    return
}

encode_piece_config :: proc(pieces: [MAX_PIECES]Piece) -> (output: [MAX_PIECES]u32) {
    for piece, idx in pieces {
        binary_rep := piece_binary_representation(piece)
        value := piece_binary_to_u32(binary_rep)
        output[idx] = value
    }
    return
}

piece_binary_representation :: proc(piece: Piece) -> (output: [31]bool) {
    // encode piece.rot_centre.x | 3 bits
    assert(piece.rot_centre.x >= 0 && piece.rot_centre.x < 6, "Require value [0,5] or encoding strategy breaks")
    encoded_x := rot_centre_pos_binary_representation(piece.rot_centre.x)
    for i in 0 ..< 3 {
        output[i] = encoded_x[i]
    }

    // encode piece.rot_centre.y | 3 bits
    assert(piece.rot_centre.y >= 0 && piece.rot_centre.y < 6, "Require value [0,5] or encoding strategy breaks")
    encoded_y := rot_centre_pos_binary_representation(piece.rot_centre.y)
    for i in 0 ..< 3 {
        output[i + 3] = encoded_y[i]
    }

    // encode piece.filled | 25 bits
    encoded_filled := piece_filled_binary_representation(piece.filled)
    for i in 0 ..< 25 {
        output[i + 6] = encoded_filled[i]
    }

    return
}

piece_binary_to_u32 :: proc(input: [31]bool) -> (output: u32) {
    for digit_is_one in input {
        output *= 2
        if digit_is_one {output += 1}
    }
    return
}

piece_u32_to_binary :: proc(input: u32) -> (output: [31]bool) {
    input := input
    for i in 0 ..< 31 {
        write_index := 30 - i
        current_value := input % 2 == 1
        output[write_index] = current_value
        input /= 2
    }
    return
}

rot_centre_pos_binary_representation :: proc(p: i32) -> (digits: [3]bool) {
    p := p
    digits_written := 0
    for (p > 0) {
        digits[2 - digits_written] = p % 2 == 1
        digits_written += 1
        p /= 2
    }
    return
}

piece_filled_binary_representation :: proc(filled: PieceData) -> (out: [25]bool) {
    for cell, idx in filled {
        out[idx] = cell != 0
    }
    return
}

test_make_piece :: proc(idx: int = 1) -> Piece {
    return Piece {
        rot_centre = GridPos{x = 2, y = 3},
        filled = [PIECE_HEIGHT * PIECE_WIDTH]int {
            0,
            0,
            idx,
            0,
            0,
            0,
            0,
            0,
            idx,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            idx,
            idx,
            idx,
            0,
            0,
            0,
            0,
            idx,
            0,
        },
    }
}

@(test)
rot_centre_binary_values :: proc(t: ^testing.T) {
    inputs := []i32{0, 1, 3, 5}
    expecteds := [][3]bool {
        [3]bool{false, false, false},
        [3]bool{false, false, true},
        [3]bool{false, true, true},
        [3]bool{true, false, true},
    }

    for i in 0 ..< len(inputs) {
        input := inputs[i]
        expected := expecteds[i]
        testing.expect_value(t, rot_centre_pos_binary_representation(input), expected)
    }
}

@(test)
piece_filled_binary_value :: proc(t: ^testing.T) {
    filled := test_make_piece().filled
    expected := [25]bool {
        false,
        false,
        true,
        false,
        false,
        false,
        false,
        false,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        true,
        true,
        false,
        false,
        false,
        false,
        true,
        false,
    }

    testing.expect_value(t, piece_filled_binary_representation(filled), expected)
}

@(test)
piece_binary_value :: proc(t: ^testing.T) {
    piece := test_make_piece()

    output := piece_binary_representation(piece)
    expected := [31]bool {
        // x_pos = 2
        false,
        true,
        false,
        // y_pos = 3
        false,
        true,
        true,
        // filled
        false,
        false,
        true,
        false,
        false,
        false,
        false,
        false,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        true,
        true,
        false,
        false,
        false,
        false,
        true,
        false,
    }


    testing.expect_value(t, output, expected)
}

@(test)
piece_binary_to_u32_val :: proc(t: ^testing.T) {
    piece := test_make_piece()
    binary := piece_binary_representation(piece)
    value := piece_binary_to_u32(binary)

    expected :: 641794498

    testing.expect_value(t, value, expected)
}

piece_u32_to_binary_val :: proc(t: ^testing.T) {
    input :: 641794498

    value := piece_u32_to_binary(input)
    expected := piece_binary_representation(test_make_piece())
    testing.expect_value(t, value, expected)
}

@(test)
import_export_round_trip_first_piece :: proc(t: ^testing.T) {
    piece := test_make_piece()
    pieces: [MAX_PIECES]Piece = {piece, {}, {}, {}, {}, {}, {}, {}}

    encoded := encode_piece_config(pieces)
    decoded := decode_piece_config(encoded)

    for i in 0 ..< MAX_PIECES {
        testing.expect_value(t, decoded[i], pieces[i])
    }
}

@(test)
import_export_round_trip_last_piece :: proc(t: ^testing.T) {
    piece := test_make_piece(8)
    pieces: [MAX_PIECES]Piece = {{}, {}, {}, {}, {}, {}, {}, piece}

    encoded := encode_piece_config(pieces)
    decoded := decode_piece_config(encoded)

    for i in 0 ..< MAX_PIECES {
        testing.expect_value(t, decoded[i], pieces[i])
    }
}

@(test)
import_export_round_trip_middle_piece :: proc(t: ^testing.T) {
    piece := test_make_piece(5)
    pieces: [MAX_PIECES]Piece = {{}, {}, {}, {}, piece, {}, {}, {}}

    encoded := encode_piece_config(pieces)
    decoded := decode_piece_config(encoded)

    for i in 0 ..< MAX_PIECES {
        testing.expect_value(t, decoded[i], pieces[i])
    }
}

@(test)
import_export_round_trip_multiple_pieces :: proc(t: ^testing.T) {
    pieces: [MAX_PIECES]Piece = {
        test_make_piece(1),
        test_make_piece(2),
        test_make_piece(3),
        test_make_piece(4),
        test_make_piece(5),
        test_make_piece(6),
        test_make_piece(7),
        test_make_piece(8),
    }

    encoded := encode_piece_config(pieces)
    decoded := decode_piece_config(encoded)

    for i in 0 ..< MAX_PIECES {
        testing.expect_value(t, decoded[i], pieces[i])
    }
}

@(test)
import_export_string_round_trip :: proc(t: ^testing.T) {
    pieces: [MAX_PIECES]Piece = {
        test_make_piece(1),
        test_make_piece(2),
        test_make_piece(3),
        test_make_piece(4),
        test_make_piece(5),
        test_make_piece(6),
        {},
        test_make_piece(8),
    }

    encoded := encode_piece_config_to_string(pieces)
    decoded := decode_string_to_piece_config(encoded)

    for i in 0 ..< MAX_PIECES {
	testing.expect_value(t, decoded[i], pieces[i])
    }
}
