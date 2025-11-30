# Flectris
Tetris but you can pick your tileset.

## Notes
- found a possible solution for the depth buffer issue. If outputColour.a != 1 then `discard` [glsl docs (page 115/199)](https://registry.khronos.org/OpenGL/specs/gl/GLSLangSpec.4.30.pdf)
- discard effectively drops the current fragment, so no output colour gets written the the colour attachment, and no update gets written to the depth attachment
- an early return might do the same? Or it might still update the depth buffer (because the z-coord is already known and set in a gl_blah variable)
- need to experiment with more complex draws involving lots of overlapped quads to be sure this works for us
- TODO: decide if this is actually an improvement, or if we should just do ordered draws! If we do this workaround to make transparency on/off, probably makes sense to assert that our alpha channels are 0 or 1 and not intermediate values when we load the data from file

## Plan
- add z dimension to our vertices, overlap a second quad over the first
- enable z-depth comparisons
- refactor check - tidying vulkan calls, identify repeated blocks to pull out, etc
- load a sprite map with multiple sprites in it, and set up our texture map so we can easily draw quads using different textures (maybe we do a font first, we'll need text for our UI)
