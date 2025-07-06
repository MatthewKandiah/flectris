package main

import "core:math/linalg/glsl"
import vk "vendor:vulkan"

Vertex :: struct {
  pos:    glsl.vec2,
  colour: glsl.vec3,
}

vertex_input_binding_description := vk.VertexInputBindingDescription {
  binding = 0,
  stride = size_of(Vertex),
  inputRate = .VERTEX,
}

vertex_input_attribute_descriptions := []vk.VertexInputAttributeDescription {
  vk.VertexInputAttributeDescription{
    location = 0,
    binding = 0,
    format = .R32G32_SFLOAT,
    offset = cast(u32)offset_of(Vertex, pos),
  },
  vk.VertexInputAttributeDescription{
    location = 1,
    binding = 0,
    format = .R32G32B32_SFLOAT,
    offset = cast(u32)offset_of(Vertex, colour),
  },
}

