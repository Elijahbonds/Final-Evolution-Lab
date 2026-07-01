#pragma once

#include <array>
#include <cstdint>
#include <vector>

namespace nexus::renderer {

struct MeshVertex {
  float position[3];
  float normal[3]{0.0F, 1.0F, 0.0F};
  float color[3];
  float uv[2]{0.0F, 0.0F};
};

using SceneVertex = MeshVertex;

struct MeshBounds {
  std::array<float, 3> min{0.0F, 0.0F, 0.0F};
  std::array<float, 3> max{0.0F, 0.0F, 0.0F};
  std::array<float, 3> center{0.0F, 0.0F, 0.0F};
  std::array<float, 3> extent{0.0F, 0.0F, 0.0F};
};

// CPU-side mesh with indexed triangles (uploaded to GPU by VulkanRenderer).
class Mesh {
public:
  std::vector<MeshVertex> vertices;
  std::vector<std::uint32_t> indices;
  bool hasPbrChannels{false};

  [[nodiscard]] auto computeBounds() const -> MeshBounds;
  [[nodiscard]] auto triangleCount() const -> std::size_t { return indices.size() / 3; }
  [[nodiscard]] auto vertexCount() const -> std::size_t { return vertices.size(); }

  /// Uniform stride decimation hook (spec §4.8 mobile vertex budget).
  auto decimateToVertexBudget(std::size_t maxVertices) -> void;

  static auto createUnitCube(float halfExtent, float red, float green, float blue) -> Mesh;
  static auto createPlane(float halfExtent,
                          float y,
                          float red,
                          float green,
                          float blue) -> Mesh;

  /// Visible placeholder when import/upload fails (magenta-tinted unit cube).
  static auto createFallbackPlaceholder() -> Mesh;

  /// Returns fallback when vertices or indices are empty.
  [[nodiscard]] static auto ensureValidGeometry(const Mesh& mesh) -> Mesh;
};

} // namespace nexus::renderer
