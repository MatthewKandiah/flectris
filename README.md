# Flectris
Tetris but you can pick your tileset.

## Plan
- load a sprite map with multiple sprites in it, and set up our texture map so we can easily draw quads using different textures (maybe we do a font first, we'll need text for our UI)
- could we delete our blending setup and just disable it, since we're achieving window transparency by discarding fragments

## Short term plan
- should drawables be in units of actual pixels instead of [-1, +1] screen coordinates so we can draw actually square squares? Should we invert the y-axis so it's [0, 1] increasing from bottom to top to make it simpler to reason about as well?
