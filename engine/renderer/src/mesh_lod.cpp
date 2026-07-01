#include "nexus/renderer/mesh_lod.h"

#include "nexus/assets/asset_manifest.h"

#include <algorithm>
#include <cstdlib>
#include <filesystem>

namespace nexus::renderer {

auto distanceLodEnabled() -> bool {
  return nexus::assets::distanceLodEnabled();
}

auto MeshLodSelector::selectProfile(float cameraDistanceMeters) const -> MeshProfileChoice {
  if (cameraDistanceMeters >= m_policy.lod1DistanceMeters) {
    return MeshProfileChoice::kMobile;
  }
  return MeshProfileChoice::kDesktop;
}

auto MeshLodSelector::selectProfileName(float cameraDistanceMeters) const -> const char* {
  return selectProfile(cameraDistanceMeters) == MeshProfileChoice::kMobile ? "mobile" : "desktop";
}

auto selectLodIndex(float cameraDistanceMeters, const MeshLodPolicy& policy) -> int {
  if (cameraDistanceMeters >= policy.lod1DistanceMeters) {
    return 1;
  }
  return 0;
}

auto parseLodDescriptors(const nlohmann::json& meshJson, const std::string& meshDirectory)
    -> std::vector<MeshLodDescriptor> {
  std::vector<MeshLodDescriptor> descriptors;
  if (!meshJson.contains("lods") || !meshJson["lods"].is_array()) {
    return descriptors;
  }

  for (const auto& lodJson : meshJson["lods"]) {
    MeshLodDescriptor descriptor{};
    descriptor.level = lodJson.value("level", static_cast<int>(descriptors.size() + 1));
    descriptor.maxDistanceMeters = lodJson.value("max_distance", 0.0F);

    if (lodJson.contains("mesh") && lodJson["mesh"].is_string()) {
      const std::string relativePath = lodJson["mesh"].get<std::string>();
      if (relativePath.find('/') != std::string::npos ||
          relativePath.find('\\') != std::string::npos) {
        descriptor.meshPath = relativePath;
      } else {
        descriptor.meshPath = (std::filesystem::path(meshDirectory) / relativePath).string();
      }
      descriptors.push_back(std::move(descriptor));
    }
  }

  std::sort(descriptors.begin(), descriptors.end(), [](const MeshLodDescriptor& a, const MeshLodDescriptor& b) {
    return a.level < b.level;
  });
  return descriptors;
}

} // namespace nexus::renderer
