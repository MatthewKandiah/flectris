package main

import "vendor:vulkan"

Pos :: struct {
    x, y: f32,
}

Dim :: struct {
    w, h: f32,
}

GridPos :: struct {
    x: i32,
    y: i32,
}

GridDim :: struct {
    w: i32,
    h: i32,
}

extent_to_dim :: proc(extent: vulkan.Extent2D) -> Dim {
    return Dim{w = cast(f32)extent.width, h = cast(f32)extent.height}
}

