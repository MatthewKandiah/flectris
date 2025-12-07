package main

import "core:math/linalg/glsl"
import "vendor:vulkan"

Vertex :: struct {
    pos:       glsl.vec3,
    colour:    glsl.vec4,
    tex_coord: glsl.vec2,
}

vertex_input_binding_description := vulkan.VertexInputBindingDescription {
    binding   = 0,
    stride    = size_of(Vertex),
    inputRate = .VERTEX,
}

vertex_input_attribute_descriptions := []vulkan.VertexInputAttributeDescription {
    vulkan.VertexInputAttributeDescription {
        location = 0,
        binding = 0,
        format = .R32G32B32_SFLOAT,
        offset = cast(u32)offset_of(Vertex, pos),
    },
    vulkan.VertexInputAttributeDescription {
        location = 1,
        binding = 0,
        format = .R32G32B32A32_SFLOAT,
        offset = cast(u32)offset_of(Vertex, colour),
    },
    vulkan.VertexInputAttributeDescription {
	location = 2,
	binding = 0,
	format = .R32G32_SFLOAT,
	offset = cast(u32)offset_of(Vertex, tex_coord),
    }
}
