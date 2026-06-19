#pragma once

#include "nexus/renderer/mesh.h"
#include "nexus/renderer/scene.h"

#include <array>
#include <vector>

namespace nexus::renderer {

constexpr int kArenaGridRadius = 2;
constexpr int kArenaFloorHalfExtent = 10;

[[nodiscard]] auto arenaColumnHeightAt(int gridX, int gridZ) -> int;

// Legacy helpers retained for tests and voxel seeding parity checks.
auto buildArenaMeshVertices() -> std::vector<SceneVertex>;
auto computeArenaMvp(float orbitRadians, float aspectRatio) -> std::array<float, 16>;

} // namespace nexus::renderer
