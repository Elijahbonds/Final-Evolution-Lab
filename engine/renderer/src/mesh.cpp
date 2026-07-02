#include "nexus/renderer/mesh.h"

#include <algorithm>
#include <limits>

namespace nexus::renderer {

namespace {

auto pushTriangle(std::vector<MeshVertex>& vertices,
                  std::vector<std::uint32_t>& indices,
                  MeshVertex a,
                  MeshVertex b,
                  MeshVertex c) -> void {
  const std::uint32_t base = static_cast<std::uint32_t>(vertices.size());
  vertices.push_back(a);
  vertices.push_back(b);
  vertices.push_back(c);
  indices.push_back(base);
  indices.push_back(base + 1);
  indices.push_back(base + 2);
}

auto appendQuad(std::vector<MeshVertex>& vertices,
                std::vector<std::uint32_t>& indices,
                MeshVertex v0,
                MeshVertex v1,
                MeshVertex v2,
                MeshVertex v3) -> void {
  pushTriangle(vertices, indices, v0, v1, v2);
  pushTriangle(vertices, indices, v0, v2, v3);
}

auto appendUnitCube(std::vector<MeshVertex>& vertices,
                    std::vector<std::uint32_t>& indices,
                    float centerX,
                    float centerY,
                    float centerZ,
                    float halfExtent,
                    float red,
                    float green,
                    float blue) -> void {
  const float x0 = centerX - halfExtent;
  const float x1 = centerX + halfExtent;
  const float y0 = centerY - halfExtent;
  const float y1 = centerY + halfExtent;
  const float z0 = centerZ - halfExtent;
  const float z1 = centerZ + halfExtent;

  const MeshVertex nx0y0z0{
      {x0, y0, z0}, {-1.0F, 0.0F, 0.0F}, {red * 0.75F, green * 0.75F, blue * 0.75F}, {0.0F, 0.0F}};
  const MeshVertex nx0y0z1{
      {x0, y0, z1}, {-1.0F, 0.0F, 0.0F}, {red * 0.8F, green * 0.8F, blue * 0.8F}, {0.0F, 0.0F}};
  const MeshVertex nx0y1z0{
      {x0, y1, z0}, {-1.0F, 0.0F, 0.0F}, {red * 0.9F, green * 0.9F, blue * 0.9F}, {0.0F, 0.0F}};
  const MeshVertex nx0y1z1{
      {x0, y1, z1}, {-1.0F, 0.0F, 0.0F}, {red * 0.85F, green * 0.85F, blue * 0.85F}, {0.0F, 0.0F}};
  const MeshVertex nx1y0z0{
      {x1, y0, z0}, {1.0F, 0.0F, 0.0F}, {red * 0.95F, green * 0.95F, blue * 0.95F}, {0.0F, 0.0F}};
  const MeshVertex nx1y0z1{{x1, y0, z1}, {1.0F, 0.0F, 0.0F}, {red, green, blue}, {0.0F, 0.0F}};
  const MeshVertex nx1y1z0{
      {x1, y1, z0}, {1.0F, 0.0F, 0.0F}, {red * 1.05F, green * 1.05F, blue * 1.05F}, {0.0F, 0.0F}};
  const MeshVertex nx1y1z1{
      {x1, y1, z1}, {1.0F, 0.0F, 0.0F}, {red * 1.1F, green * 1.1F, blue * 1.1F}, {0.0F, 0.0F}};

  appendQuad(vertices, indices, nx0y0z1, nx1y0z1, nx1y1z1, nx0y1z1);
  appendQuad(vertices, indices, nx1y0z0, nx0y0z0, nx0y1z0, nx1y1z0);
  appendQuad(vertices, indices, nx0y0z0, nx0y0z1, nx0y1z1, nx0y1z0);
  appendQuad(vertices, indices, nx1y0z1, nx1y0z0, nx1y1z0, nx1y1z1);
  appendQuad(vertices, indices, nx0y1z1, nx1y1z1, nx1y1z0, nx0y1z0);
  appendQuad(vertices, indices, nx0y0z0, nx1y0z0, nx1y0z1, nx0y0z1);
}

} // namespace

auto Mesh::createUnitCube(float halfExtent, float red, float green, float blue) -> Mesh {
  Mesh mesh;
  mesh.vertices.reserve(24);
  mesh.indices.reserve(36);
  appendUnitCube(mesh.vertices, mesh.indices, 0.0F, 0.0F, 0.0F, halfExtent, red, green, blue);
  mesh.hasPbrChannels = true;
  return mesh;
}

auto Mesh::createPlane(float halfExtent, float y, float red, float green, float blue) -> Mesh {
  Mesh mesh;
  const MeshVertex v0{{-halfExtent, y, -halfExtent}, {0.0F, 1.0F, 0.0F}, {red, green, blue}, {0.0F, 0.0F}};
  const MeshVertex v1{{halfExtent, y, -halfExtent}, {0.0F, 1.0F, 0.0F}, {red, green, blue}, {0.0F, 1.0F}};
  const MeshVertex v2{
      {halfExtent, y, halfExtent}, {0.0F, 1.0F, 0.0F}, {red * 1.2F, green * 1.2F, blue * 1.2F}, {1.0F, 1.0F}};
  const MeshVertex v3{
      {-halfExtent, y, halfExtent}, {0.0F, 1.0F, 0.0F}, {red * 1.2F, green * 1.2F, blue * 1.2F}, {0.0F, 1.0F}};
  appendQuad(mesh.vertices, mesh.indices, v0, v1, v2, v3);
  mesh.hasPbrChannels = true;
  return mesh;
}

auto Mesh::computeBounds() const -> MeshBounds {
  MeshBounds bounds{};
  if (vertices.empty()) {
    return bounds;
  }

  bounds.min = {vertices.front().position[0],
                vertices.front().position[1],
                vertices.front().position[2]};
  bounds.max = bounds.min;

  for (const MeshVertex& vertex : vertices) {
    for (int axis = 0; axis < 3; ++axis) {
      bounds.min[static_cast<std::size_t>(axis)] =
          std::min(bounds.min[static_cast<std::size_t>(axis)], vertex.position[axis]);
      bounds.max[static_cast<std::size_t>(axis)] =
          std::max(bounds.max[static_cast<std::size_t>(axis)], vertex.position[axis]);
    }
  }

  for (int axis = 0; axis < 3; ++axis) {
    bounds.center[static_cast<std::size_t>(axis)] =
        (bounds.min[static_cast<std::size_t>(axis)] + bounds.max[static_cast<std::size_t>(axis)]) *
        0.5F;
    bounds.extent[static_cast<std::size_t>(axis)] =
        bounds.max[static_cast<std::size_t>(axis)] - bounds.min[static_cast<std::size_t>(axis)];
  }
  return bounds;
}

auto Mesh::decimateToVertexBudget(std::size_t maxVertices) -> void {
  if (maxVertices == 0 || vertices.size() <= maxVertices || indices.size() < 3) {
    return;
  }

  const std::size_t triangleCount = indices.size() / 3;
  const float ratio =
      static_cast<float>(maxVertices) / static_cast<float>(vertices.size());
  const std::size_t targetTriangles =
      std::max<std::size_t>(1, static_cast<std::size_t>(static_cast<float>(triangleCount) * ratio));
  if (triangleCount <= targetTriangles) {
    return;
  }

  const std::size_t stride = (triangleCount + targetTriangles - 1) / targetTriangles;
  std::vector<std::uint32_t> decimatedIndices;
  decimatedIndices.reserve(targetTriangles * 3);

  for (std::size_t triangleIndex = 0; triangleIndex < triangleCount; triangleIndex += stride) {
    const std::size_t base = triangleIndex * 3;
    decimatedIndices.push_back(indices[base]);
    decimatedIndices.push_back(indices[base + 1]);
    decimatedIndices.push_back(indices[base + 2]);
  }

  indices = std::move(decimatedIndices);

  std::vector<MeshVertex> compactVertices;
  compactVertices.reserve(vertices.size());
  std::vector<std::uint32_t> remap(vertices.size(), std::numeric_limits<std::uint32_t>::max());

  for (std::uint32_t& index : indices) {
    if (remap[index] == std::numeric_limits<std::uint32_t>::max()) {
      remap[index] = static_cast<std::uint32_t>(compactVertices.size());
      compactVertices.push_back(vertices[index]);
    }
    index = remap[index];
  }

  vertices = std::move(compactVertices);
}

auto Mesh::createFallbackPlaceholder() -> Mesh {
  return createUnitCube(0.75F, 0.95F, 0.15F, 0.55F);
}

auto Mesh::ensureValidGeometry(const Mesh& mesh) -> Mesh {
  if (!mesh.vertices.empty() && !mesh.indices.empty()) {
    return mesh;
  }
  return createFallbackPlaceholder();
}

} // namespace nexus::renderer
