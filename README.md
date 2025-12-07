# Flectris
Tetris but you can pick your tileset.

## Plan
- load a sprite map with multiple sprites in it, and set up our texture map so we can easily draw quads using different textures (maybe we do a font first, we'll need text for our UI)
- could we delete our blending setup and just disable it, since we're achieving window transparency by discarding fragments

## Short term plan
- associate each letter in our font with a texture coordinate base + width + height
- game state with list of "drawables"
- function to populate vertex and index buffers from game state
- draw string function `draw_string("foobar", pos)`
