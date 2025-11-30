# Flectris
Tetris but you can pick your tileset.

## Notes
- need to experiment with more complex draws involving lots of overlapped quads to be sure this works for us

## Plan
- enable z-depth comparisons
- refactor check - tidying vulkan calls, identify repeated blocks to pull out, etc
- load a sprite map with multiple sprites in it, and set up our texture map so we can easily draw quads using different textures (maybe we do a font first, we'll need text for our UI)
