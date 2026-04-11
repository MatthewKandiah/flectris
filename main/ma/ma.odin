package ma

import "core:fmt"
import "vendor:miniaudio"

fatal :: proc(args: ..any) {
    fmt.eprintln(..args)
    panic("ma fatal")
}

is_success :: proc(res: miniaudio.result) -> bool {
    return res == .SUCCESS
}

is_not_success :: proc(res: miniaudio.result) -> bool {
    return res != .SUCCESS
}
