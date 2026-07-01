#version 450

layout(binding = 0) uniform UniformBufferObject {
    mat4 viewProj;
    vec4 albedoMetallic;
    vec4 roughnessAo;
} ubo;

layout(location = 0) in vec3 fragColor;
layout(location = 1) in vec2 fragUv;
layout(location = 2) in vec3 fragNormal;

layout(location = 0) out vec4 outColor;

void main() {
    vec3 albedoFactor = ubo.albedoMetallic.rgb;
    float metallicFactor = ubo.albedoMetallic.a;
    float roughnessFactor = ubo.roughnessAo.x;
    float aoFactor = ubo.roughnessAo.y;

    vec3 baseColor = mix(fragColor, albedoFactor, 0.35);
    vec3 n = normalize(fragNormal);
    vec3 lightDir = normalize(vec3(-0.35, -1.0, -0.25));
    float ndotl = max(dot(n, lightDir), 0.0);
    float diffuse = (1.0 - metallicFactor) * ndotl;
    float ambient = 0.18 * aoFactor;
    float spec = metallicFactor * ndotl * (1.0 - roughnessFactor * 0.5);
    vec3 lit = baseColor * (ambient + diffuse + spec);
    outColor = vec4(lit, 1.0);
}
