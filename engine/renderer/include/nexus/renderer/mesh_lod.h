#pragma once

#include "nexus/renderer/mesh.h"

#include <nlohmann/json.hpp>

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace nexus::renderer {

/// Spec §4.8 Venice Beach runtime targets (≤50k verts hero, ≤25k LOD1).
struct MeshLodPolicy {
  std::size_t heroMaxVertices{50'000};
  std::size_t lod1MaxVertices{25'000};
  float lod1DistanceMeters{25.0F};
};

enum class MeshProfileChoice {
  kDesktop,
  kMobile,
};

/// Picks desktop vs mobile mesh sidecar from camera distance (Phase 3 hook).
class MeshLodSelector {
public:
  explicit MeshLodSelector(MeshLodPolicy policy = {}) : m_policy(policy) {}

  [[nodiscard]] auto policy() const -> const MeshLodPolicy& { return m_policy; }
  [[nodiscard]] auto selectProfile(float cameraDistanceMeters) const -> MeshProfileChoice;
  [[nodiscard]] auto selectProfileName(float cameraDistanceMeters) const -> const char*;

private:
  MeshLodPolicy m_policy{};
};

[[nodiscard]] auto distanceLodEnabled() -> bool;

struct MeshLodDescriptor {
  int level{0};
  float maxDistanceMeters{0.0F};
  std::string meshPath;
};

/// Selects a LOD index from camera distance; returns 0 when no alternate LOD applies.
[[nodiscard]] auto selectLodIndex(float cameraDistanceMeters, const MeshLodPolicy& policy) -> int;

/// Parses optional `"lods"` array from `.nexusmesh.json` sidecar metadata.
[[nodiscard]] auto parseLodDescriptors(const nlohmann::json& meshJson,
                                       const std::string& meshDirectory) -> std::vector<MeshLodDescriptor>;

} // namespace nexus::renderer
