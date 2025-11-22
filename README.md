# Flectris
Tetris but you can pick your tileset.

## Plan - Medium Term
- add texture image and sampling
- enable blending (so we can have transparent bits on our sprites)

## Plan - Short Term
- refactor resource memory allocation and binding and mapping and copying (done in buffer creation and image creation)
- refactor image layout transitions (done in texture image creation and swapchain image setup)
- create image view, bind it to the graphics pipeline, check in renderdoc that we've got the whole image
