#version 450

layout(location = 0) in vec3 fragColour;
layout(location = 1) in vec2 texCoord;

layout(binding = 0) uniform sampler2D texSampler;

layout(location = 0) out vec4 outColour;

const float inf = 1.0 / 0.0;

void main() {
  outColour = textureLod(texSampler, texCoord, 0);

  // TODO - wip hacky solution - manually tweak z buffer value if transparent, could support on/off transparency which is probably enough for what we are doing. Doesn't look right with the smiley texture we've been using so far. 
  float binaryOutColourA = int( outColour.a != 0 );
  gl_FragDepth = -inf * (1 - binaryOutColourA) + outColour.z * binaryOutColourA;
  //outColour = vec4(fragColour, 1.0);
}
