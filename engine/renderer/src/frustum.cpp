#include "nexus/renderer/frustum.h"

#include "nexus/renderer/mesh.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <limits>

namespace nexus::renderer {

namespace {

auto normalizePlane(std::array<float, 4> plane) -> std::array<float, 4> {
  const float length =
      std::sqrt(plane[0] * plane[0] + plane[1] * plane[1] + plane[2] * plane[2]);
  if (length <= std::numeric_limits<float>::epsilon()) {
    return plane;
  }
  plane[0] /= length;
  plane[1] /= length;
  plane[2] /= length;
  plane[3] /= length;
  return plane;
}

auto extractPlane(const std::array<float, 16>& matrix, int rowSign, int colOffset)
    -> std::array<float, 4> {
  return normalizePlane({
      matrix[colOffset + 0] + static_cast<float>(rowSign) * matrix[3 + 0],
      matrix[colOffset + 1] + static_cast<float>(rowSign) * matrix[3 + 1],
      matrix[colOffset + 2] + static_cast<float>(rowSign) * matrix[3 + 2],
      matrix[colOffset + 3] + static_cast<float>(rowSign) * matrix[3 + 3],
  });
}

} // namespace

auto Frustum::fromViewProjection(const std::array<float, 16>& viewProjection) -> Frustum {
  Frustum frustum{};
  frustum.m_planes[0] = extractPlane(viewProjection, 1, 0);  // left
  frustum.m_planes[1] = extractPlane(viewProjection, -1, 0); // right
  frustum.m_planes[2] = extractPlane(viewProjection, 1, 4);  // bottom
  frustum.m_planes[3] = extractPlane(viewProjection, -1, 4); // top
  frustum.m_planes[4] = extractPlane(viewProjection, 1, 8);  // near
  frustum.m_planes[5] = extractPlane(viewProjection, -1, 8); // far
  return frustum;
}

auto Frustum::intersectsAabb(const std::array<float, 3>& worldMin,
                             const std::array<float, 3>& worldMax) const -> bool {
  for (const auto& plane : m_planes) {
    const std::array<float, 3> positiveCorner{
        plane[0] >= 0.0F ? worldMax[0] : worldMin[0],
        plane[1] >= 0.0F ? worldMax[1] : worldMin[1],
        plane[2] >= 0.0F ? worldMax[2] : worldMin[2],
    };
    const float distance = plane[0] * positiveCorner[0] + plane[1] * positiveCorner[1] +
                           plane[2] * positiveCorner[2] + plane[3];
    if (distance < 0.0F) {
      return false;
    }
  }
  return true;
}

auto transformBounds(const std::array<float, 16>& modelMatrix, const MeshBounds& localBounds)
    -> MeshBounds {
  const std::array<std::array<float, 3>, 8> corners{{
      {localBounds.min[0], localBounds.min[1], localBounds.min[2]},
      {localBounds.max[0], localBounds.min[1], localBounds.min[2]},
      {localBounds.min[0], localBounds.max[1], localBounds.min[2]},
      {localBounds.max[0], localBounds.max[1], localBounds.min[2]},
      {localBounds.min[0], localBounds.min[1], localBounds.max[2]},
      {localBounds.max[0], localBounds.min[1], localBounds.max[2]},
      {localBounds.min[0], localBounds.max[1], localBounds.max[2]},
      {localBounds.max[0], localBounds.max[1], localBounds.max[2]},
  }};

  MeshBounds worldBounds{};
  worldBounds.min = {std::numeric_limits<float>::max(),
                     std::numeric_limits<float>::max(),
                     std::numeric_limits<float>::max()};
  worldBounds.max = {std::numeric_limits<float>::lowest(),
                     std::numeric_limits<float>::lowest(),
                     std::numeric_limits<float>::lowest()};

  for (const auto& corner : corners) {
    const float x = modelMatrix[0] * corner[0] + modelMatrix[4] * corner[1] +
                    modelMatrix[8] * corner[2] + modelMatrix[12];
    const float y = modelMatrix[1] * corner[0] + modelMatrix[5] * corner[1] +
                    modelMatrix[9] * corner[2] + modelMatrix[13];
    const float z = modelMatrix[2] * corner[0] + modelMatrix[6] * corner[1] +
                    modelMatrix[10] * corner[2] + modelMatrix[14];

    worldBounds.min[0] = std::min(worldBounds.min[0], x);
    worldBounds.min[1] = std::min(worldBounds.min[1], y);
    worldBounds.min[2] = std::min(worldBounds.min[2], z);
    worldBounds.max[0] = std::max(worldBounds.max[0], x);
    worldBounds.max[1] = std::max(worldBounds.max[1], y);
    worldBounds.max[2] = std::max(worldBounds.max[2], z);
  }

  for (int axis = 0; axis < 3; ++axis) {
    worldBounds.center[static_cast<std::size_t>(axis)] =
        (worldBounds.min[static_cast<std::size_t>(axis)] +
         worldBounds.max[static_cast<std::size_t>(axis)]) *
        0.5F;
    worldBounds.extent[static_cast<std::size_t>(axis)] =
        worldBounds.max[static_cast<std::size_t>(axis)] -
        worldBounds.min[static_cast<std::size_t>(axis)];
  }
  return worldBounds;
}

auto Frustum::intersectsBounds(const std::array<float, 16>& modelMatrix,
                               const MeshBounds& localBounds) const -> bool {
  const MeshBounds worldBounds = transformBounds(modelMatrix, localBounds);
  return intersectsAabb(worldBounds.min, worldBounds.max);
}

} // namespace nexus::renderer
