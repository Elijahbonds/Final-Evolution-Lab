#include "nexus/creative/voxel_world.h"

#include <algorithm>
#include <cmath>
#include <string>

namespace nexus::creative {

namespace {

auto floorDiv(int value, int divisor) -> int {
  int quotient = value / divisor;
  const int remainder = value % divisor;
  if (remainder != 0 && ((remainder < 0) != (divisor < 0))) {
    --quotient;
  }
  return quotient;
}

auto positiveModulo(int value, int divisor) -> int {
  const int remainder = value % divisor;
  return remainder < 0 ? remainder + divisor : remainder;
}

} // namespace

auto VoxelWorld::ChunkCoordHash::operator()(const ChunkCoord& coord) const -> std::size_t {
  const auto x = static_cast<std::size_t>(coord.x) * 73856093U;
  const auto y = static_cast<std::size_t>(coord.y) * 19349663U;
  const auto z = static_cast<std::size_t>(coord.z) * 83492791U;
  return x ^ y ^ z;
}

auto VoxelWorld::setVoxel(Vec3i position, Voxel voxel) -> Result<void> {
  auto coord = chunkFor(position);
  auto& chunk = getOrCreateChunk(coord);
  chunk.voxels[localIndex(position)] = voxel;
  markDirty(coord);

  if (positiveModulo(position.x, kChunkEdge) == 0) {
    markDirty({coord.x - 1, coord.y, coord.z});
  }
  if (positiveModulo(position.y, kChunkEdge) == 0) {
    markDirty({coord.x, coord.y - 1, coord.z});
  }
  if (positiveModulo(position.z, kChunkEdge) == 0) {
    markDirty({coord.x, coord.y, coord.z - 1});
  }
  return Result<void>::ok();
}

auto VoxelWorld::voxelAt(Vec3i position) const -> Voxel {
  const auto coord = chunkFor(position);
  const auto found = m_chunks.find(coord);
  if (found == m_chunks.end()) {
    return {};
  }
  return found->second.voxels[localIndex(position)];
}

auto VoxelWorld::dirtyChunkCount() const -> std::size_t {
  return static_cast<std::size_t>(
      std::count_if(m_chunks.begin(), m_chunks.end(), [](const auto& entry) {
        return entry.second.dirty;
      }));
}

auto VoxelWorld::serializeDirtyChunks(std::size_t maxChunks) -> nlohmann::json {
  nlohmann::json chunks = nlohmann::json::array();
  for (auto& [coord, chunk] : m_chunks) {
    if (!chunk.dirty || chunks.size() >= maxChunks) {
      continue;
    }
    chunks.push_back({{"coord", {coord.x, coord.y, coord.z}}});
    chunk.dirty = false;
  }
  return chunks;
}

void VoxelWorld::clear() {
  m_chunks.clear();
  m_environmentChunks.clear();
}

auto VoxelWorld::environmentChunkCount() const -> std::size_t {
  return m_environmentChunks.size();
}

auto VoxelWorld::serializeEnvironmentChunks() const -> nlohmann::json {
  nlohmann::json chunks = nlohmann::json::array();
  for (const auto& [coord, ref] : m_environmentChunks) {
    chunks.push_back({
        {"coord", {coord.x, coord.y, coord.z}},
        {"mesh", ref.meshPath},
    });
  }
  return chunks;
}

auto VoxelWorld::registerEnvironmentChunk(Vec3i chunkCoord, std::string_view meshPath)
    -> Result<void> {
  if (meshPath.empty()) {
    return Result<void>::err("environment chunk requires mesh path");
  }
  const ChunkCoord coord{chunkCoord.x, chunkCoord.y, chunkCoord.z};
  m_environmentChunks[coord] = EnvironmentChunkRef{std::string(meshPath)};
  markDirty(coord);
  return Result<void>::ok();
}

auto VoxelWorld::chunkFor(Vec3i position) -> ChunkCoord {
  return {
      floorDiv(position.x, kChunkEdge),
      floorDiv(position.y, kChunkEdge),
      floorDiv(position.z, kChunkEdge),
  };
}

auto VoxelWorld::localIndex(Vec3i position) -> std::size_t {
  const int x = positiveModulo(position.x, kChunkEdge);
  const int y = positiveModulo(position.y, kChunkEdge);
  const int z = positiveModulo(position.z, kChunkEdge);
  return static_cast<std::size_t>(x + (y * kChunkEdge) + (z * kChunkEdge * kChunkEdge));
}

auto VoxelWorld::getOrCreateChunk(ChunkCoord coord) -> Chunk& {
  auto& chunk = m_chunks[coord];
  if (chunk.voxels.empty()) {
    chunk.voxels.resize(kChunkEdge * kChunkEdge * kChunkEdge);
  }
  return chunk;
}

void VoxelWorld::markDirty(ChunkCoord coord) {
  auto& chunk = getOrCreateChunk(coord);
  chunk.dirty = true;
}

} // namespace nexus::creative
