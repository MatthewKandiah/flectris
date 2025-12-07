package main

Drawable :: struct {
    pos: Pos, // is this going to be centre position, or corner position?
    z: f32,
    dim: Dim,
    texture_data: TextureData,
}

Pos :: struct {
    x, y: f32
}

Dim :: struct {
    w, h: f32
}

TextureData :: struct {
    base: Pos,
    dim: Dim,
}
