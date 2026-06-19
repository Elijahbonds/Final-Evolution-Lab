#include "nexus/ai/agent_server.h"
#include "nexus/ai/agent_transport.h"
#include "nexus/ai/command_router.h"
#include "nexus/core/engine.h"
#include "nexus/core/log.h"

#include <iostream>
#include "nexus/creative/voxel_world.h"
#include "nexus/creative/world_manipulator.h"
#include "nexus/gameplay/gameplay_application.h"
#include "nexus/physics/physics_world.h"
#include "nexus/renderer/vulkan_renderer.h"

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
  nexus::creative::WorldManipulator manipulator(voxelWorld);

  nexus::ai::CommandRouter router;
  auto routerResult = router.init(&manipulator, &voxelWorld);
  if (routerResult.isErr()) {
    NEXUS_LOG_ERROR(nexus::LogChannel::kAI, routerResult.error());
    physics.shutdown();
    renderer.shutdown();
    return 1;
  }

  nexus::gameplay::GameplayApplication gameplay(manipulator, voxelWorld);
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
      << "\n[NEXUS] macOS dev runtime only — Vulkan swapchain test window (NOT the iOS app).\n"
      << "[NEXUS] Product UI: open FinalEvolutionLab.xcodeproj → Run on iPhone/Simulator (no -ScreenshotHarness).\n"
      << "[NEXUS] Web: sites/finalevolutiongroup.com or sites/final-evolution-main-site.\n\n";

  engine.run();

  engine.shutdown();
  agentServer.shutdown();
  router.shutdown();
  physics.shutdown();
  renderer.shutdown();
  return 0;
}
