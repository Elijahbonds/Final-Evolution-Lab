#pragma once

#include "nexus/core/result.h"

#include <cstdint>
#include <nlohmann/json.hpp>
#include <unordered_map>
#include <vector>

namespace nexus::creative {

struct Vec3i {
  int x{0};
  int y{0};
  int z{0};
};

struct Voxel {
  std::uint16_t material{0};
  bool solid{false};

  NLOHMANN_DEFINE_TYPE_INTRUSIVE(Voxel, material, solid)
};

struct VoxelEdit {
  Vec3i position;
  Voxel voxel;
};

class VoxelWorld {
public:
  static constexpr int kChunkEdge = 32;

  auto setVoxel(Vec3i position, Voxel voxel) -> Result<void>;
  [[nodiscard]] auto voxelAt(Vec3i position) const -> Voxel;
  [[nodiscard]] auto dirtyChunkCount() const -> std::size_t;
  [[nodiscard]] auto serializeDirtyChunks(std::size_t maxChunks) -> nlohmann::json;
  void clear();

private:
  struct ChunkCoord {
    int x{0};
    int y{0};
    int z{0};

    auto operator==(const ChunkCoord& other) const -> bool {
      return x == other.x && y == other.y && z == other.z;
    }
  };

  struct ChunkCoordHash {
    auto operator()(const ChunkCoord& coord) const -> std::size_t;
  };

  struct Chunk {
    std::vector<Voxel> voxels;
    bool dirty{false};
  };

  [[nodiscard]] static auto chunkFor(Vec3i position) -> ChunkCoord;
  [[nodiscard]] static auto localIndex(Vec3i position) -> std::size_t;
  auto getOrCreateChunk(ChunkCoord coord) -> Chunk&;
  void markDirty(ChunkCoord coord);

  std::unordered_map<ChunkCoord, Chunk, ChunkCoordHash> m_chunks;
};

} // namespace nexus::creative
