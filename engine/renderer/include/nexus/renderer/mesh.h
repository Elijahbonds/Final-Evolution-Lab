#pragma once

#include <cstdint>
#include <vector>

namespace nexus::renderer {

struct MeshVertex {
  float position[3];
  float color[3];
};

using SceneVertex = MeshVertex;

// CPU-side mesh with indexed triangles (uploaded to GPU by VulkanRenderer).
class Mesh {
public:
  std::vector<MeshVertex> vertices;
  std::vector<std::uint32_t> indices;

  static auto createUnitCube(float halfExtent, float red, float green, float blue) -> Mesh;
  static auto createPlane(float halfExtent,
                          float y,
                          float red,
                          float green,
                          float blue) -> Mesh;
};

} // namespace nexus::renderer
