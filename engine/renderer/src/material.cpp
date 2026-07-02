#include "nexus/renderer/material.h"

#include "nexus/assets/asset_manifest.h"
#include "nexus/core/log.h"

#include <nlohmann/json.hpp>

#include <algorithm>
#include <cmath>
#include <fstream>

namespace nexus::renderer {

namespace {

auto normalize(const std::array<float, 3>& v) -> std::array<float, 3> {
  const float len =
      std::sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
  if (len <= 1e-6F) {
    return {0.0F, 1.0F, 0.0F};
  }
  return {v[0] / len, v[1] / len, v[2] / len};
}

auto dot(const std::array<float, 3>& a, const std::array<float, 3>& b) -> float {
  return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}

} // namespace

auto MaterialLibrary::defaultVenueMaterial() const -> PbrMaterial {
  PbrMaterial material{};
  material.albedo = {0.72F, 0.74F, 0.78F};
  material.metallic = 0.05F;
  material.roughness = 0.72F;
  material.ao = 1.0F;
  return material;
}

auto MaterialLibrary::find(std::string_view materialId) const -> PbrMaterial {
  if (materialId == "venue_default" || materialId.empty()) {
    return defaultVenueMaterial();
  }
  PbrMaterial material = defaultVenueMaterial();
  if (materialId == "court_lines") {
    material.albedo = {0.95F, 0.95F, 0.98F};
    material.roughness = 0.35F;
  }
  return material;
}

namespace {

auto readManifestJson(const std::string& manifestPath) -> nlohmann::json {
  std::ifstream stream(manifestPath);
  return nlohmann::json::parse(stream);
}

auto parsePbrBlock(const nlohmann::json& pbrJson, PbrMaterial material) -> PbrMaterial {
  if (pbrJson.contains("albedo") && pbrJson["albedo"].is_array() &&
      pbrJson["albedo"].size() >= 3) {
    material.albedo = {pbrJson["albedo"][0].get<float>(),
                       pbrJson["albedo"][1].get<float>(),
                       pbrJson["albedo"][2].get<float>()};
  }
  if (pbrJson.contains("metallic")) {
    material.metallic = pbrJson["metallic"].get<float>();
  }
  if (pbrJson.contains("roughness")) {
    material.roughness = pbrJson["roughness"].get<float>();
  }
  if (pbrJson.contains("ao")) {
    material.ao = pbrJson["ao"].get<float>();
  }
  if (pbrJson.contains("albedo_texture")) {
    material.albedoTexturePath = pbrJson["albedo_texture"].get<std::string>();
    material.hasTextures = true;
  }
  if (pbrJson.contains("normal_texture")) {
    material.normalTexturePath = pbrJson["normal_texture"].get<std::string>();
    material.hasTextures = true;
  }
  if (pbrJson.contains("roughness_ao_texture")) {
    material.roughnessAoTexturePath = pbrJson["roughness_ao_texture"].get<std::string>();
    material.hasTextures = true;
  }
  return material;
}

} // namespace

auto MaterialLibrary::loadFromManifestEntry(const std::string& manifestPath,
                                            std::string_view assetId) -> Result<PbrMaterial> {
  const auto manifestResult = assets::AssetManifest::loadFromFile(manifestPath);
  if (manifestResult.isErr()) {
    return Result<PbrMaterial>::err(manifestResult.error());
  }
  const assets::AssetRecord* asset = manifestResult.value().findAsset(assetId);
  if (asset == nullptr) {
    return Result<PbrMaterial>::err("Asset not found: " + std::string(assetId));
  }

  PbrMaterial material = defaultVenueMaterial();
  try {
    const nlohmann::json manifestJson = readManifestJson(manifestPath);
    for (const auto& assetJson : manifestJson.at("assets")) {
      if (assetJson.at("id").get<std::string>() != assetId) {
        continue;
      }
      if (assetJson.contains("pbr") && assetJson["pbr"].is_object()) {
        material = parsePbrBlock(assetJson["pbr"], material);
      }
      break;
    }
  } catch (const std::exception& exception) {
    return Result<PbrMaterial>::err(std::string("Manifest PBR parse error: ") + exception.what());
  }

  if (material.hasTextures) {
    NEXUS_LOG_INFO(nexus::LogChannel::kRenderer,
                   "MaterialLibrary: texture sampling deferred (GLB/ASTC loader extension)");
  }
  (void)asset;
  return Result<PbrMaterial>::ok(material);
}

auto packMaterialUniform(const PbrMaterial& material,
                         const std::array<float, 16>& viewProj) -> MaterialUniformBlock {
  MaterialUniformBlock block{};
  block.viewProj = viewProj;
  block.albedoMetallic = {material.albedo[0],
                          material.albedo[1],
                          material.albedo[2],
                          material.metallic};
  block.roughnessAo = {material.roughness, material.ao, 0.0F, 0.0F};
  return block;
}

auto shadePbr(const PbrMaterial& material,
              const std::array<float, 3>& normal,
              const std::array<float, 3>& lightDirection) -> std::array<float, 3> {
  const auto n = normalize(normal);
  const auto l = normalize(lightDirection);
  const float ndotl = std::max(dot(n, l), 0.0F);
  const float diffuse = (1.0F - material.metallic) * ndotl;
  const float ambient = 0.18F * material.ao;
  const float spec = material.metallic * ndotl * (1.0F - material.roughness * 0.5F);
  const float intensity = ambient + diffuse + spec;
  return {material.albedo[0] * intensity,
          material.albedo[1] * intensity,
          material.albedo[2] * intensity};
}

} // namespace nexus::renderer
