package img

import "core:fmt"
import "vendor:stb/image"

fatal :: proc(args: ..any) {
    fmt.eprintln(..args)
    panic("img fatal")
}

load :: proc(filepath: cstring, desired_channel_count: i32) -> (ok: bool, x,y,channels_in_file: i32, data: [^]u8) {
    data = image.load(filepath, &x, &y, &channels_in_file, desired_channel_count)
    if data != nil {
	ok = true
    }
    return 
}
