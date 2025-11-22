package img

import "core:fmt"
import "vendor:stb/image"

fatal :: proc(args: ..any) {
    fmt.eprintln(..args)
    panic("img fatal")
}

load :: proc(filepath: cstring, desired_channel_count: i32) -> (ok: bool, x, y, channels_in_file: i32, data: []u8) {
    tmp_data := image.load(filepath, &x, &y, &channels_in_file, desired_channel_count)
    if tmp_data == nil {
	ok = false
	return
    }
    byte_count := x * y * desired_channel_count
    data = tmp_data[:byte_count]
    ok = true
    return
}

free :: proc(data: []u8) {
    image.image_free(raw_data(data))
}
