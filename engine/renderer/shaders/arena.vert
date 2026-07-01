#version 450

layout(binding = 0) uniform UniformBufferObject {
    mat4 viewProj;
    vec4 albedoMetallic;
    vec4 roughnessAo;
} ubo;

layout(push_constant) uniform PushConstants {
    mat4 model;
} push;

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec3 inNormal;
layout(location = 2) in vec3 inColor;
layout(location = 3) in vec2 inUv;

layout(location = 0) out vec3 fragColor;
layout(location = 1) out vec2 fragUv;
layout(location = 2) out vec3 fragNormal;

void main() {
    vec4 worldPos = push.model * vec4(inPosition, 1.0);
    gl_Position = ubo.viewProj * worldPos;
    fragColor = inColor;
    fragUv = inUv;
    fragNormal = mat3(push.model) * inNormal;
}
