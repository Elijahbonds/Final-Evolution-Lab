// Sprint 1 (nexus/engine-gfx): draw-call instancing, batched CPU skinning,
// and the phase-1 particle system.

#include "nexus/core/job_system.h"
#include "nexus/renderer/mesh.h"
#include "nexus/renderer/particle_system.h"
#include "nexus/renderer/scene.h"
#include "nexus/renderer/skinning_batch.h"

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <vector>

namespace {

void require(bool condition, const char* message) {
  if (!condition) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    std::exit(1);
  }
}

using nexus::renderer::Mesh;
using nexus::renderer::MeshInstance;
using nexus::renderer::ParticleEmitterConfig;
using nexus::renderer::ParticleSystem;
using nexus::renderer::ParticleTier;
using nexus::renderer::RenderScene;
using nexus::renderer::SceneEntity;
using nexus::renderer::SkinningBatch;

auto makeSceneWithDuplicateMeshes() -> RenderScene {
  RenderScene scene;
  const std::size_t cubeIndex = scene.addMesh(Mesh::createUnitCube(0.5F, 1.0F, 0.2F, 0.2F));
  const std::size_t planeIndex = scene.addMesh(Mesh::createPlane(4.0F, 0.0F, 0.2F, 1.0F, 0.2F));

  // 5 cube instances + 2 plane instances spread across entities.
  for (int i = 0; i < 5; ++i) {
    SceneEntity entity{};
    entity.transform.translation[0] = static_cast<float>(i) * 1.5F;
    entity.meshInstances.push_back(MeshInstance{cubeIndex, {}});
    scene.addRootEntity(entity);
  }
  for (int i = 0; i < 2; ++i) {
    SceneEntity entity{};
    entity.transform.translation[2] = static_cast<float>(i) * 3.0F;
    entity.meshInstances.push_back(MeshInstance{planeIndex, {}});
    scene.addRootEntity(entity);
  }
  return scene;
}

void testInstancedBatchGroupsByMesh() {
  RenderScene scene = makeSceneWithDuplicateMeshes();

  const auto flat = scene.collectDrawCommandBatch(/*frustumCull=*/false);
  require(flat.stats.totalDraws == 7, "flat batch should contain 7 draws");

  const auto instanced = scene.collectInstancedDrawBatch(/*frustumCull=*/false);
  require(instanced.instancedDrawCount() == 2,
          "7 instances of 2 meshes must batch into 2 instanced draws");
  require(instanced.stats.totalDraws == 7, "instanced batch keeps flat stats");

  std::size_t totalInstances = 0;
  for (const auto& draw : instanced.draws) {
    totalInstances += draw.instanceTransforms.size();
  }
  require(totalInstances == 7, "no instance may be dropped by batching");
  require(instanced.draws[0].meshIndex < instanced.draws[1].meshIndex,
          "instanced draws must be ordered by mesh index");
  require(instanced.draws[0].instanceTransforms.size() == 5,
          "cube mesh must carry 5 instance transforms");
}

void testInstancedBatchEmptyScene() {
  RenderScene scene;
  const auto instanced = scene.collectInstancedDrawBatch(false);
  require(instanced.instancedDrawCount() == 0, "empty scene yields no instanced draws");
}

void testSkinningBatchSerialAndParallelMatch() {
  using nexus::renderer::AnimationPlayer;

  const auto makePlayers = [](std::size_t count) {
    std::vector<AnimationPlayer> players(count);
    for (std::size_t i = 0; i < count; ++i) {
      // Missing path => deterministic synthesized clip (existing behavior).
      const auto clip = players[i].loadClip("synthetic_gfx_batch_clip");
      require(clip.isOk(), "synthesized clip must load");
      require(players[i].play("synthetic_gfx_batch_clip").isOk(), "clip must play");
    }
    return players;
  };

  auto serialPlayers = makePlayers(8);
  auto parallelPlayers = makePlayers(8);

  const auto serialStats = SkinningBatch::advanceAll({serialPlayers}, 0.25F, nullptr);
  require(serialStats.playersAdvanced == 8, "serial batch advances all players");
  require(!serialStats.ranParallel, "no job system means serial path");
  require(serialStats.bonesSkinned > 0, "bones must be skinned");

  nexus::core::JobSystem jobs(2);
  const auto parallelStats = SkinningBatch::advanceAll({parallelPlayers}, 0.25F, &jobs);
  require(parallelStats.ranParallel, "8 players with jobs must run parallel");
  require(parallelStats.bonesSkinned == serialStats.bonesSkinned,
          "parallel and serial skin the same bone count");

  for (std::size_t i = 0; i < serialPlayers.size(); ++i) {
    const auto serialData = serialPlayers[i].skinningMatrixData();
    const auto parallelData = parallelPlayers[i].skinningMatrixData();
    require(serialData.size() == parallelData.size(), "matrix buffer sizes match");
    for (std::size_t j = 0; j < serialData.size(); ++j) {
      require(std::fabs(serialData[j] - parallelData[j]) < 1e-6F,
              "parallel skinning must be bit-stable vs serial");
    }
  }
}

void testParticleEmitterLifecycleAndBatch() {
  ParticleEmitterConfig config{};
  config.maxParticles = 64;
  config.spawnPerSecond = 120.0F;
  config.lifetimeSeconds = 0.5F;
  config.flipbookFrames = 16;

  ParticleSystem system(ParticleTier::kMobileMid);
  const std::size_t index = system.addEmitter(config);
  auto& emitter = system.emitter(index);

  system.update(1.0F / 60.0F);
  require(emitter.liveCount() > 0, "first tick must spawn particles");

  for (int frame = 0; frame < 60; ++frame) {
    system.update(1.0F / 60.0F);
  }
  require(emitter.liveCount() <= config.maxParticles, "live count respects capacity");

  const auto batches = system.buildSpriteBatches();
  require(batches.size() == 1, "one emitter yields one sprite batch");
  require(batches[0].drawCallCount() == 1, "an active emitter is a single instanced draw");
  require(batches[0].instances.size() == emitter.liveCount(),
          "batch instance count equals live particles");
  for (const auto& instance : batches[0].instances) {
    require(instance.opacity >= 0.0F && instance.opacity <= 1.0F, "opacity in [0,1]");
    require(instance.frameIndex >= 0.0F &&
                instance.frameIndex < static_cast<float>(config.flipbookFrames),
            "flipbook frame within sheet range");
  }

  // All particles must eventually expire without spawning (zero rate clone).
  ParticleEmitterConfig dieOff = config;
  dieOff.spawnPerSecond = 0.0F;
  ParticleSystem dieSystem(ParticleTier::kMobileLow);
  auto& dieEmitter = dieSystem.emitter(dieSystem.addEmitter(dieOff));
  for (int frame = 0; frame < 120; ++frame) {
    dieSystem.update(1.0F / 60.0F);
  }
  require(dieEmitter.liveCount() == 0, "zero spawn rate drains the pool");
}

void testParticleBudgetClamp() {
  ParticleSystem system(ParticleTier::kMobileLow); // budget 512

  ParticleEmitterConfig big{};
  big.maxParticles = 400;
  system.addEmitter(big);
  system.addEmitter(big); // only 112 slots left
  require(system.totalCapacity() <= system.tierBudget(),
          "emitter capacity must clamp to the tier budget");
  require(system.emitter(1).config().maxParticles == 112,
          "second emitter receives the remaining budget");

  system.addEmitter(big); // zero slots left
  require(system.emitter(2).config().maxParticles == 0, "over-budget emitter gets zero");

  nexus::core::JobSystem jobs(2);
  for (int frame = 0; frame < 90; ++frame) {
    system.update(1.0F / 60.0F, &jobs);
  }
  require(system.totalLive() <= system.tierBudget(),
          "live particles never exceed the tier budget");
}

} // namespace

auto main() -> int {
  testInstancedBatchGroupsByMesh();
  testInstancedBatchEmptyScene();
  testSkinningBatchSerialAndParallelMatch();
  testParticleEmitterLifecycleAndBatch();
  testParticleBudgetClamp();
  std::printf("gfx_batch_test OK\n");
  return 0;
}
