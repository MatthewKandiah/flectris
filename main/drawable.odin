package main

Drawable :: struct {
    pos:             Pos, // is this going to be centre position, or corner position?
    z:               f32,
    dim:             Dim,
    texture_data:    TextureData,
    override_colour: bool,
    colour:          Colour,
}

Colour :: struct {
    r, g, b: f32,
}

RED :: Colour {
    r = 1,
    g = 0,
    b = 0,
}
GREEN :: Colour {
    r = 0,
    g = 1,
    b = 0,
}
BLUE :: Colour {
    r = 0,
    g = 0,
    b = 1,
}
BLACK :: Colour {
    r = 0,
    g = 0,
    b = 0,
}
WHITE :: Colour {
    r = 1,
    g = 1,
    b = 1,
}

Pos :: struct {
    x, y: f32,
}

Dim :: struct {
    w, h: f32,
}

TextureData :: struct {
    base: Pos,
    dim:  Dim,
}
