#include "nexus/renderer/console_tier_lod.h"

#include "nexus/renderer/mesh_lod.h"

#include <algorithm>
#include <cmath>
#include <unordered_map>
#include <utility>
#include <vector>

namespace nexus::renderer {

auto batchDrawCommands(const std::vector<RenderScene::DrawCommand>& commands)
    -> BatchedDrawList {
  BatchedDrawList result{};
  result.instanceCount = commands.size();

  // Preserve first-seen mesh order for deterministic batch layout.
  std::unordered_map<std::size_t, std::size_t> meshToBatch;
  meshToBatch.reserve(commands.size());

  for (const RenderScene::DrawCommand& cmd : commands) {
    auto it = meshToBatch.find(cmd.meshIndex);
    if (it == meshToBatch.end()) {
      meshToBatch.emplace(cmd.meshIndex, result.batches.size());
      InstancedBatch batch{};
      batch.meshIndex = cmd.meshIndex;
      batch.instanceTransforms.push_back(cmd.modelMatrix);
      result.batches.push_back(std::move(batch));
    } else {
      result.batches[it->second].instanceTransforms.push_back(cmd.modelMatrix);
    }
  }
  result.drawCalls = result.batches.size();
  return result;
}

auto evaluateConsoleTierFrame(const RenderScene::DrawStats& stats,
                              const BatchedDrawList& batched,
                              const nexus::core::EngineScalePlan& plan)
    -> ConsoleTierFramePlan {
  ConsoleTierFramePlan frame{};
  frame.rawTriangles = stats.triangleCount;
  frame.rawDrawCalls = stats.visibleDraws;
  frame.batchedDrawCalls = batched.drawCalls;
  frame.dynamicShadows = plan.dynamicShadows;
  frame.bloomEnabled = plan.bloomEnabled;

  // LOD-distance bias trims geometry: a higher bias pulls the LOD switch nearer,
  // shedding triangles. Model the projected (post-LOD) triangle load. Bias 1.0
  // (console/kHigh) keeps full detail; >1.0 degrades distant geometry.
  const double bias = plan.lodDistanceBias > 0.0F ? plan.lodDistanceBias : 1.0F;
  frame.projectedTriangles =
      static_cast<std::size_t>(std::llround(static_cast<double>(stats.triangleCount) / bias));

  frame.withinTriangleBudget = frame.projectedTriangles <= plan.triangleBudget;
  frame.withinDrawBudget = frame.batchedDrawCalls <= plan.drawCallBudget;
  frame.recommendDegrade = !frame.withinTriangleBudget || !frame.withinDrawBudget;
  return frame;
}

auto planSceneForActiveTier(const RenderScene& scene) -> ConsoleTierFramePlan {
  const RenderScene::DrawCommandBatch batch = scene.collectDrawCommandBatch(true);
  const BatchedDrawList batched = batchDrawCommands(batch.commands);
  const nexus::core::EngineScalePlan plan = nexus::core::activeScalePlan();
  return evaluateConsoleTierFrame(batch.stats, batched, plan);
}

namespace {

auto drawCommandDistance(const RenderScene::DrawCommand& cmd) -> float {
  const float x = cmd.modelMatrix[12];
  const float y = cmd.modelMatrix[13];
  const float z = cmd.modelMatrix[14];
  return std::sqrt(x * x + y * y + z * z);
}

auto recomputeBatchStats(const RenderScene& scene, RenderScene::DrawCommandBatch batch,
                         std::size_t totalDraws, std::size_t culledDraws)
    -> RenderScene::DrawCommandBatch {
  batch.stats.totalDraws = totalDraws;
  batch.stats.culledDraws = culledDraws;
  batch.stats.visibleDraws = batch.commands.size();
  batch.stats.triangleCount = 0;
  for (const RenderScene::DrawCommand& command : batch.commands) {
    if (command.meshIndex < scene.meshCount()) {
      batch.stats.triangleCount += scene.mesh(command.meshIndex).triangleCount();
    }
  }
  return batch;
}

} // namespace

auto applyConsoleTierToDrawBatch(const RenderScene& scene,
                                 RenderScene::DrawCommandBatch collected)
    -> TierAwareDrawBatch {
  const nexus::core::EngineScalePlan plan = nexus::core::activeScalePlan();
  MeshLodPolicy lodPolicy{};
  if (plan.lodDistanceBias > 1.0F) {
    lodPolicy.lod1DistanceMeters /= plan.lodDistanceBias;
  }

  RenderScene::DrawCommandBatch filtered = collected;
  if (plan.lodDistanceBias > 1.0F) {
    std::vector<RenderScene::DrawCommand> kept;
    kept.reserve(collected.commands.size());
    for (const RenderScene::DrawCommand& command : collected.commands) {
      if (selectLodIndex(drawCommandDistance(command), lodPolicy) == 0) {
        kept.push_back(command);
      }
    }
    const std::size_t lodCulled = collected.commands.size() - kept.size();
    filtered.commands = std::move(kept);
    filtered = recomputeBatchStats(scene, std::move(filtered), collected.stats.totalDraws,
                                   collected.stats.culledDraws + lodCulled);
  }

  BatchedDrawList batched = batchDrawCommands(filtered.commands);
  ConsoleTierFramePlan tierPlan = evaluateConsoleTierFrame(filtered.stats, batched, plan);

  if (tierPlan.recommendDegrade && filtered.commands.size() > 1) {
    std::vector<std::pair<float, std::size_t>> ranked;
    ranked.reserve(filtered.commands.size());
    for (std::size_t i = 0; i < filtered.commands.size(); ++i) {
      ranked.emplace_back(drawCommandDistance(filtered.commands[i]), i);
    }
    std::sort(ranked.begin(), ranked.end(), std::greater<>());

    std::vector<bool> drop(filtered.commands.size(), false);
    std::size_t triCount = filtered.stats.triangleCount;
    std::size_t drawCount = batched.drawCalls;
    for (const auto& [distance, index] : ranked) {
      (void)distance;
      if (triCount <= plan.triangleBudget && drawCount <= plan.drawCallBudget) {
        break;
      }
      if (drop[index]) {
        continue;
      }
      const RenderScene::DrawCommand& command = filtered.commands[index];
      if (command.meshIndex >= scene.meshCount()) {
        continue;
      }
      triCount -= scene.mesh(command.meshIndex).triangleCount();
      drop[index] = true;
      --drawCount;
    }

    std::vector<RenderScene::DrawCommand> finalCommands;
    finalCommands.reserve(filtered.commands.size());
    for (std::size_t i = 0; i < filtered.commands.size(); ++i) {
      if (!drop[i]) {
        finalCommands.push_back(filtered.commands[i]);
      }
    }
    const std::size_t budgetCulled = filtered.commands.size() - finalCommands.size();
    filtered.commands = std::move(finalCommands);
    filtered = recomputeBatchStats(scene, std::move(filtered), collected.stats.totalDraws,
                                   collected.stats.culledDraws + budgetCulled);
    batched = batchDrawCommands(filtered.commands);
    tierPlan = evaluateConsoleTierFrame(filtered.stats, batched, plan);
  }

  return TierAwareDrawBatch{.batch = std::move(filtered), .tierPlan = tierPlan};
}

} // namespace nexus::renderer
