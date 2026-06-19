#include "nexus/ai/agent_server.h"
#include "nexus/ai/agent_transport.h"
#include "nexus/ai/command_router.h"
#include "nexus/core/engine.h"
#include "nexus/core/log.h"

#include <iostream>
#include "nexus/creative/voxel_world.h"
#include "nexus/creative/world_manipulator.h"
#include "nexus/gameplay/gameplay_application.h"
#include "nexus/generative/generative_pipeline.h"
#include "nexus/physics/physics_world.h"
#include "nexus/renderer/arena_scene.h"
#include "nexus/renderer/vulkan_renderer.h"

namespace {

auto seedArenaVoxels(nexus::creative::VoxelWorld& voxelWorld) -> void {
  using nexus::creative::Vec3i;
  using nexus::creative::Voxel;
  using nexus::renderer::arenaColumnHeightAt;
  using nexus::renderer::kArenaGridRadius;

  for (int gridX = -kArenaGridRadius; gridX <= kArenaGridRadius; ++gridX) {
    for (int gridZ = -kArenaGridRadius; gridZ <= kArenaGridRadius; ++gridZ) {
      const int height = arenaColumnHeightAt(gridX, gridZ);
      for (int gridY = 0; gridY < height; ++gridY) {
        (void)voxelWorld.setVoxel(Vec3i{gridX, gridY, gridZ}, Voxel{.material = 1, .solid = true});
      }
    }
  }
}

} // namespace

auto main() -> int {
  nexus::renderer::VulkanRenderer renderer;
  auto rendererResult = renderer.init({});
  if (rendererResult.isErr()) {
    NEXUS_LOG_ERROR(nexus::LogChannel::kRenderer, rendererResult.error());
    return 1;
  }

  nexus::physics::PhysicsWorld physics;
  auto physicsResult = physics.init({});
  if (physicsResult.isErr()) {
    NEXUS_LOG_ERROR(nexus::LogChannel::kPhysics, physicsResult.error());
    renderer.shutdown();
    return 1;
  }

  nexus::creative::VoxelWorld voxelWorld;
  seedArenaVoxels(voxelWorld);
  nexus::creative::WorldManipulator manipulator(voxelWorld);

  nexus::generative::GenerativePipeline generativePipeline;

  nexus::ai::CommandRouter router;
  auto routerResult = router.init(&manipulator, &voxelWorld, &generativePipeline);
  if (routerResult.isErr()) {
    NEXUS_LOG_ERROR(nexus::LogChannel::kAI, routerResult.error());
    physics.shutdown();
    renderer.shutdown();
    return 1;
  }

  nexus::gameplay::GameplayApplication gameplay(manipulator, voxelWorld);
  gameplay.setGenerativePipeline(&generativePipeline);
  router.setGameplayHandler(&gameplay);

  nexus::ai::AgentServer agentServer;
  auto agentResult = agentServer.init(&router);
  if (agentResult.isErr()) {
    NEXUS_LOG_ERROR(nexus::LogChannel::kAI, agentResult.error());
    router.shutdown();
    physics.shutdown();
    renderer.shutdown();
    return 1;
  }

  const auto transportResult = agentServer.startTransport({
      .enableStdinReader = true,
      .enableTcpListener = true,
      .tcpPort = 9090,
  });
  if (transportResult.isErr()) {
    NEXUS_LOG_WARN(nexus::LogChannel::kAI,
                   "Agent transport unavailable: " + transportResult.error());
  }

  nexus::core::Engine engine;
  auto engineResult = engine.init({}, &renderer, &physics, &agentServer, &gameplay);
  if (engineResult.isErr()) {
    NEXUS_LOG_ERROR(nexus::LogChannel::kCore, engineResult.error());
    agentServer.shutdown();
    router.shutdown();
    physics.shutdown();
    renderer.shutdown();
    return 1;
  }

  std::cerr
      << "\n[NEXUS] macOS dev runtime — 3D arena preview (orbit camera + cube field).\n"
      << "[NEXUS] Agent TCP: localhost:9090 | Voxel world seeded to match rendered arena.\n"
      << "[NEXUS] Product UI: open FinalEvolutionLab.xcodeproj → Run on iPhone/Simulator.\n\n";

  engine.run();

  engine.shutdown();
  agentServer.shutdown();
  router.shutdown();
  physics.shutdown();
  renderer.shutdown();
  return 0;
}
