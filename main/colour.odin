package main

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

GREY :: Colour {
    r = 0.3,
    g = 0.3,
    b = 0.3,
}

DARK_GREY :: Colour {
    r = 0.1,
    g = 0.1,
    b = 0.1,
}
