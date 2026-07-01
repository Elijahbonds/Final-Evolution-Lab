#pragma once

#include "nexus/generative/environment_scan_types.h"

#include <vector>

namespace nexus::generative {

/// Spatial index for environment tiles aligned with VoxelWorld chunk size (default 32).
class EnvironmentChunkIndex {
public:
  explicit EnvironmentChunkIndex(int chunkEdge = 32);

  [[nodiscard]] auto chunkEdge() const -> int { return m_chunkEdge; }

  [[nodiscard]] auto worldToChunk(float x, float y, float z) const -> EnvironmentChunkCoord;
  [[nodiscard]] auto chunkOrigin(const EnvironmentChunkCoord& coord) const -> EnvironmentBounds;
  [[nodiscard]] auto enumerateChunksInBounds(const EnvironmentBounds& bounds) const
      -> std::vector<EnvironmentChunkCoord>;

private:
  [[nodiscard]] static auto floorDiv(float value, int edge) -> int;

  int m_chunkEdge;
};

} // namespace nexus::generative
