#pragma once

#include <array>
#include <cstddef>

namespace nexus::renderer {

struct MeshBounds;

// View-frustum extraction + AABB intersection (column-major view-projection).
class Frustum {
public:
  [[nodiscard]] static auto fromViewProjection(const std::array<float, 16>& viewProjection) -> Frustum;
  [[nodiscard]] auto intersectsAabb(const std::array<float, 3>& worldMin,
                                    const std::array<float, 3>& worldMax) const -> bool;
  [[nodiscard]] auto intersectsBounds(const std::array<float, 16>& modelMatrix,
                                      const MeshBounds& localBounds) const -> bool;

private:
  std::array<std::array<float, 4>, 6> m_planes{};
};

[[nodiscard]] auto transformBounds(const std::array<float, 16>& modelMatrix, const MeshBounds& localBounds)
    -> MeshBounds;

} // namespace nexus::renderer
