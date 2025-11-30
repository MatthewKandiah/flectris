# Flectris
Tetris but you can pick your tileset.

## Plan
- build script to build shaders as well
- add z dimension to our vertices, overlap a second quad over the first
- enable z-depth comparisons
- refactor check - tidying vulkan calls, identify repeated blocks to pull out, etc
- load a sprite map with multiple sprites in it, and set up our texture map so we can easily draw quads using different textures (maybe we do a font first, we'll need text for our UI)
