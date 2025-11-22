# Flectris
Tetris but you can pick your tileset.

## Plan - Medium Term
- add texture image and sampling
- enable blending (so we can have transparent bits on our sprites)

## Plan - Short Term
- just realised after stopping recording, I think our image is really a R8G8B8A8, but we've made a resource that's R32G32B32A32, that's why our image allocation is 4 times bigger than we expected. So it probably works, but nice to update the image format if possible
- refactor resource memory allocation and binding and mapping and copying (done in buffer creation and image creation)
- refactor image layout transitions (done in texture image creation and swapchain image setup)
- create image view, bind it to the graphics pipeline, check in renderdoc that we've got the whole image
- maybe embed the image data into the executable, instead of reading from file at runtime?
