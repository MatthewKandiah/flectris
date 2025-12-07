# Flectris
Tetris but you can pick your tileset.

## Plan
- load a sprite map with multiple sprites in it, and set up our texture map so we can easily draw quads using different textures (maybe we do a font first, we'll need text for our UI)
- could we delete our blending setup and just disable it, since we're achieving window transparency by discarding fragments

## Short term plan
- some way to draw without a texture, so just using a colour per vertex
- wrap that into a nicer interface
- think about how we want to lay things out on the screen
