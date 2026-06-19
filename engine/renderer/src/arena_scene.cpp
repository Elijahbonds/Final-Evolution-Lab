#include "nexus/renderer/arena_scene.h"

#include "nexus/renderer/scene.h"

#include <cmath>
#include <cstdlib>

namespace nexus::renderer {

namespace {

auto arenaColumnHeight(int gridX, int gridZ) -> int {
  const int manhattan = std::abs(gridX) + std::abs(gridZ);
  return 1 + (manhattan % 3);
}

} // namespace

auto arenaColumnHeightAt(int gridX, int gridZ) -> int {
  return arenaColumnHeight(gridX, gridZ);
}

auto buildArenaMeshVertices() -> std::vector<SceneVertex> {
  std::vector<SceneVertex> flattened;
  const RenderScene scene = RenderScene::createDefaultArena();
  for (const RenderScene::DrawCommand& command : scene.collectDrawCommands()) {
    const Mesh& mesh = scene.mesh(command.meshIndex);
    for (std::size_t index = 0; index < mesh.indices.size(); index += 3) {
      for (int corner = 0; corner < 3; ++corner) {
        const MeshVertex& source = mesh.vertices[mesh.indices[index + static_cast<std::size_t>(corner)]];
        SceneVertex transformed{};
        const float x = source.position[0];
        const float y = source.position[1];
        const float z = source.position[2];
        const auto& m = command.modelMatrix;
        transformed.position[0] = m[0] * x + m[4] * y + m[8] * z + m[12];
        transformed.position[1] = m[1] * x + m[5] * y + m[9] * z + m[13];
        transformed.position[2] = m[2] * x + m[6] * y + m[10] * z + m[14];
        transformed.color[0] = source.color[0];
        transformed.color[1] = source.color[1];
        transformed.color[2] = source.color[2];
        flattened.push_back(transformed);
      }
    }
  }
  return flattened;
}

auto computeArenaMvp(float orbitRadians, float aspectRatio) -> std::array<float, 16> {
  Camera camera;
  camera.setOrbitTarget(0.0F, 1.5F, 0.0F);
  camera.setOrbit(12.0F, 6.5F, orbitRadians);
  camera.setPerspective(50.0F, aspectRatio, 0.1F, 100.0F);
  return camera.viewProjectionMatrix();
}

} // namespace nexus::renderer
