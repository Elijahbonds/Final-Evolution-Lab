#include "nexus/ai/agent_server.h"
#include "nexus/ai/agent_transport.h"
#include "nexus/ai/command_router.h"
#include "nexus/assets/asset_manifest.h"
#include "nexus/assets/mesh_importer.h"
#include "nexus/core/dev_stats.h"
#include "nexus/core/engine.h"
#include "nexus/core/log.h"

#include <iostream>
#include <string>
#include <string_view>

#include "nexus/creative/voxel_world.h"
#include "nexus/creative/world_manipulator.h"
#include "nexus/gameplay/arena_mode_registry.h"
#include "nexus/gameplay/gameplay_application.h"
#include "nexus/generative/generative_pipeline.h"
#include "nexus/physics/physics_world.h"
#include "nexus/renderer/arena_scene.h"
#include "nexus/renderer/mesh_lod.h"
#include "nexus/renderer/scene.h"
#include "nexus/renderer/vulkan_renderer.h"

namespace {

struct RuntimeOptions {
  std::string modeId{"basketball_dunk"};
  std::string venueId{"venice_beach"};
  bool headless{false};
  bool validateOnly{false};
};

auto parseArgs(int argc, char** argv) -> RuntimeOptions {
  RuntimeOptions options;
  for (int index = 1; index < argc; ++index) {
    const std::string_view arg{argv[index]};
    if (arg == "--mode" && index + 1 < argc) {
      options.modeId = argv[++index];
    } else if (arg == "--venue" && index + 1 < argc) {
      options.venueId = argv[++index];
    } else if (arg == "--headless") {
      options.headless = true;
    } else if (arg == "--validate-only") {
      options.validateOnly = true;
      options.headless = true;
    } else if (arg == "--help" || arg == "-h") {
      std::cerr << "Usage: nexus_runtime [--mode basketball_dunk] [--venue venice_beach]\n"
                << "                     [--headless] [--validate-only]\n";
      std::exit(0);
    }
  }
  return options;
}

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

auto validateVenueMesh(std::string_view modeId, std::string_view venueHint) -> int {
  constexpr const char* kManifestPath = "assets/nexus/manifests/nexus_asset_manifest.json";
  const auto manifestResult = nexus::assets::AssetManifest::loadFromFile(kManifestPath);
  if (manifestResult.isErr()) {
    NEXUS_LOG_ERROR(nexus::LogChannel::kRenderer, manifestResult.error());
    return 1;
  }

  const nexus::assets::AssetManifest& manifest = manifestResult.value();
  const nexus::assets::VenueRecord* venue = manifest.findVenueForMode(modeId);
  if (venue == nullptr && !venueHint.empty()) {
    venue = manifest.findVenueByKey(venueHint);
  }
  if (venue == nullptr) {
    NEXUS_LOG_ERROR(nexus::LogChannel::kRenderer,
                    "No venue registered for mode: " + std::string(modeId));
    return 1;
  }

  const nexus::assets::AssetRecord* environmentAsset = manifest.findAsset(venue->environmentAssetId);
  if (environmentAsset == nullptr || environmentAsset->importedMesh.empty()) {
    NEXUS_LOG_ERROR(nexus::LogChannel::kRenderer, "Venue environment asset missing imported mesh");
    return 1;
  }

  const std::string meshPath = manifest.resolveMeshPathAtDistance(*environmentAsset, 0.0F);
  nexus::assets::MeshImportOptions importOptions{};
  importOptions.applyDecimation =
      !nexus::assets::meshProfilePrefersMobile() && !nexus::assets::distanceLodEnabled();

  const auto meshResult = nexus::assets::MeshImporter::importFile(meshPath, importOptions);
  if (meshResult.isErr()) {
    NEXUS_LOG_ERROR(nexus::LogChannel::kRenderer, meshResult.error());
    return 1;
  }

  const auto scene = nexus::renderer::RenderScene::createFromManifest(kManifestPath, modeId);
  if (scene.meshCount() == 0 || scene.rootEntityCount() == 0) {
    NEXUS_LOG_ERROR(nexus::LogChannel::kRenderer, "RenderScene failed to build venue from manifest");
    return 1;
  }

  const auto drawBatch = scene.collectDrawCommandBatch(false);
  if (!drawBatch.stats.withinBudget()) {
    NEXUS_LOG_ERROR(nexus::LogChannel::kRenderer,
                    "Scene triangle budget exceeded: tris=" +
                        std::to_string(drawBatch.stats.triangleCount) + " budget=" +
                        std::to_string(nexus::renderer::RenderScene::DrawStats::kSceneTriangleBudget()));
    return 1;
  }

  nexus::core::logFrameDevStats({
      .fps = 0.0F,
      .frameTimeMs = 0.0F,
      .visibleDraws = drawBatch.stats.visibleDraws,
      .culledDraws = drawBatch.stats.culledDraws,
      .triangleCount = drawBatch.stats.triangleCount,
      .withinDrawBudget = drawBatch.stats.withinBudget(),
  });

  const auto& mesh = meshResult.value();
  std::cerr << "[NEXUS] validate-only OK mode=" << modeId << " venue=" << venue->venueKey
            << " mesh=" << meshPath << " verts=" << mesh.vertices.size()
            << " tris=" << (mesh.indices.size() / 3)
            << " profile=" << nexus::assets::activeMeshProfileName() << "\n";
  return 0;
}

} // namespace

auto main(int argc, char** argv) -> int {
  const RuntimeOptions options = parseArgs(argc, argv);

  if (options.validateOnly) {
    return validateVenueMesh(options.modeId, options.venueId);
  }

  nexus::renderer::VulkanRenderer renderer;
  nexus::renderer::RendererConfig rendererConfig{};
  rendererConfig.modeId = options.modeId.c_str();
  if (options.headless) {
    NEXUS_LOG_WARN(nexus::LogChannel::kRenderer,
                   "Headless flag noted — macOS runtime still opens SDL window for Vulkan");
  }

  auto rendererResult = renderer.init(rendererConfig);
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

  const std::string venueToken =
      nexus::gameplay::ArenaModeRegistry::venueTokenForMode(options.modeId);

  (void)gameplay.handleGameplayCommand(
      "fel.arena.start_session",
      {{"mode_id", options.modeId}, {"user_id", "nexus_runtime"}},
      "boot_arena");
  (void)gameplay.handleGameplayCommand(
      "fel.bridge.broadcast_map_loaded",
      {{"map", venueToken}, {"mode_id", options.modeId}},
      "boot_map");
  (void)gameplay.handleGameplayCommand(
      "fel.venue.register_volume",
      {{"venue_token", venueToken},
       {"mode_id", options.modeId},
       {"min", {{"x", -50.0F}, {"y", 0.0F}, {"z", -30.0F}}},
       {"max", {{"x", 50.0F}, {"y", 15.0F}, {"z", 30.0F}}}},
      "boot_venue");
  (void)renderer.loadVenue(options.modeId);

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

  std::cerr << "\n[NEXUS] desktop dev runtime — 3D venue preview (mode=" << options.modeId
            << ", venue=" << venueToken << ").\n"
            << "[NEXUS] Agent TCP: localhost:9090\n"
            << "[NEXUS] Dunk commands: fel.dunk.charge_begin / charge_release / apex_tap\n"
            << "[NEXUS] Karate commands: fel.karate.action {action: light_strike|...}\n"
            << "[NEXUS] iOS product UI: FinalEvolutionLab.xcodeproj → Run on device.\n\n";

  engine.run();

  engine.shutdown();
  agentServer.shutdown();
  router.shutdown();
  physics.shutdown();
  renderer.shutdown();
  return 0;
}
