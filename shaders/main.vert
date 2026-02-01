#version 450

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec4 inColour;
layout(location = 2) in vec2 inTexCoord;
layout(location = 3) in int inTexIdx;

layout(location = 0) out vec4 fragColour;
layout(location = 1) out vec2 texCoord;
layout(location = 2) out int texIdx;

void main() {
    gl_Position = vec4(inPosition, 1.0);
    fragColour = inColour;
    texCoord = inTexCoord;
    texIdx = inTexIdx;
}
