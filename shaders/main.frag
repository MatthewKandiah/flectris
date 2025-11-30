#version 450

layout(location = 0) in vec3 fragColour;
layout(location = 1) in vec2 texCoord;

layout(binding = 0) uniform sampler2D texSampler;

layout(location = 0) out vec4 outColour;

const float inf = 1.0 / 0.0;

void main() {
  outColour = textureLod(texSampler, texCoord, 0);
  if (outColour.a < 1) {
    discard;
  }
}
