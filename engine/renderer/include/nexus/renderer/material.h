#pragma once

#include "nexus/core/result.h"

#include <array>
#include <cstdint>
#include <string>

namespace nexus::renderer {

/// PBR material descriptor (textures optional; solid factors always valid).
struct PbrMaterial {
  std::array<float, 3> albedo{0.8F, 0.8F, 0.82F};
  float metallic{0.0F};
  float roughness{0.65F};
  float ao{1.0F};
  std::string albedoTexturePath;
  std::string normalTexturePath;
  std::string roughnessAoTexturePath;
  bool hasTextures{false};
};

/// std140 UBO tail packed after viewProj (mat4) in arena.vert / arena.frag.
struct MaterialUniformBlock {
  std::array<float, 16> viewProj{};
  std::array<float, 4> albedoMetallic{}; // rgb + metallic
  std::array<float, 4> roughnessAo{};    // roughness, ao, pad, pad
};

[[nodiscard]] auto packMaterialUniform(const PbrMaterial& material,
                                       const std::array<float, 16>& viewProj)
    -> MaterialUniformBlock;

class MaterialLibrary {
public:
  [[nodiscard]] auto defaultVenueMaterial() const -> PbrMaterial;
  [[nodiscard]] auto find(std::string_view materialId) const -> PbrMaterial;
  [[nodiscard]] auto loadFromManifestEntry(const std::string& manifestPath,
                                           std::string_view assetId) -> Result<PbrMaterial>;
};

/// CPU-side shading helper matching arena.frag stub.
[[nodiscard]] auto shadePbr(const PbrMaterial& material,
                            const std::array<float, 3>& normal,
                            const std::array<float, 3>& lightDirection) -> std::array<float, 3>;

} // namespace nexus::renderer
