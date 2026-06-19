#include "nexus/generative/environment_chunk_index.h"

#include <algorithm>
#include <cmath>

namespace nexus::generative {

EnvironmentChunkIndex::EnvironmentChunkIndex(int chunkEdge) : m_chunkEdge(std::max(1, chunkEdge)) {}

auto EnvironmentChunkIndex::floorDiv(float value, int edge) -> int {
  return static_cast<int>(std::floor(value / static_cast<float>(edge)));
}

auto EnvironmentChunkIndex::worldToChunk(float x, float y, float z) const -> EnvironmentChunkCoord {
  return {
      floorDiv(x, m_chunkEdge),
      floorDiv(y, m_chunkEdge),
      floorDiv(z, m_chunkEdge),
  };
}

auto EnvironmentChunkIndex::chunkOrigin(const EnvironmentChunkCoord& coord) const -> EnvironmentBounds {
  const float edge = static_cast<float>(m_chunkEdge);
  EnvironmentBounds bounds{};
  bounds.min[0] = static_cast<float>(coord.x) * edge;
  bounds.min[1] = static_cast<float>(coord.y) * edge;
  bounds.min[2] = static_cast<float>(coord.z) * edge;
  bounds.max[0] = bounds.min[0] + edge;
  bounds.max[1] = bounds.min[1] + edge;
  bounds.max[2] = bounds.min[2] + edge;
  return bounds;
}

auto EnvironmentChunkIndex::enumerateChunksInBounds(const EnvironmentBounds& bounds) const
    -> std::vector<EnvironmentChunkCoord> {
  const EnvironmentChunkCoord minChunk =
      worldToChunk(bounds.min[0], bounds.min[1], bounds.min[2]);
  const EnvironmentChunkCoord maxChunk =
      worldToChunk(bounds.max[0] - 0.001F, bounds.max[1] - 0.001F, bounds.max[2] - 0.001F);

  std::vector<EnvironmentChunkCoord> chunks;
  for (int x = minChunk.x; x <= maxChunk.x; ++x) {
    for (int y = minChunk.y; y <= maxChunk.y; ++y) {
      for (int z = minChunk.z; z <= maxChunk.z; ++z) {
        chunks.push_back({x, y, z});
      }
    }
  }
  return chunks;
}

} // namespace nexus::generative
