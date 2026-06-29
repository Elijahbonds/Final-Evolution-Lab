#include "nexus/core/engine_scale_policy.h"
#include "nexus/core/perf_monitor.h"
#include "nexus/renderer/console_tier_lod.h"
#include "nexus/renderer/scene.h"

#include <array>
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

auto makeCommand(std::size_t meshIndex) -> nexus::renderer::RenderScene::DrawCommand {
  nexus::renderer::RenderScene::DrawCommand cmd{};
  cmd.meshIndex = meshIndex;
  cmd.modelMatrix = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
  return cmd;
}

void batching_collapses_repeated_meshes_into_instanced_draws() {
  std::vector<nexus::renderer::RenderScene::DrawCommand> cmds;
  // 300 instances spread across only 3 unique meshes.
  for (int i = 0; i < 300; ++i) {
    cmds.push_back(makeCommand(static_cast<std::size_t>(i % 3)));
  }
  const auto batched = nexus::renderer::batchDrawCommands(cmds);
  require(batched.instanceCount == 300, "all instances retained");
  require(batched.drawCalls == 3, "draw calls collapsed to unique mesh count");
  require(batched.drawCalls < cmds.size(), "batching reduced draw calls");
  std::size_t total = 0;
  for (const auto& b : batched.batches) {
    total += b.instanceTransforms.size();
  }
  require(total == 300, "no instances lost during batching");
}

void high_tier_keeps_full_detail_within_budget() {
  nexus::renderer::RenderScene::DrawStats stats{};
  stats.triangleCount = 128'000;
  stats.visibleDraws = 700;
  nexus::renderer::BatchedDrawList batched{};
  batched.drawCalls = 700;
  const auto plan = nexus::core::scalePlanForTier(nexus::core::PerformanceTier::kHigh);
  const auto frame = nexus::renderer::evaluateConsoleTierFrame(stats, batched, plan);
  require(frame.projectedTriangles == 128'000, "no LOD reduction at high tier");
  require(frame.withinMobileBudget(), "high tier frame within mobile budget");
  require(!frame.recommendDegrade, "no degrade recommended within budget");
  require(frame.dynamicShadows && frame.bloomEnabled, "console FX on at high tier");
}

void over_budget_frame_recommends_degrade() {
  nexus::renderer::RenderScene::DrawStats stats{};
  stats.triangleCount = 220'000; // well over the 130k cap
  stats.visibleDraws = 900;
  nexus::renderer::BatchedDrawList batched{};
  batched.drawCalls = 900;
  const auto plan = nexus::core::scalePlanForTier(nexus::core::PerformanceTier::kHigh);
  const auto frame = nexus::renderer::evaluateConsoleTierFrame(stats, batched, plan);
  require(frame.recommendDegrade, "over-budget frame recommends degrade");
  require(!frame.withinMobileBudget(), "frame flagged outside budget");
}

void low_power_lod_bias_sheds_triangles() {
  nexus::renderer::RenderScene::DrawStats stats{};
  stats.triangleCount = 130'000;
  stats.visibleDraws = 400;
  nexus::renderer::BatchedDrawList batched{};
  batched.drawCalls = 400;
  const auto plan = nexus::core::scalePlanForTier(nexus::core::PerformanceTier::kLowPower);
  const auto frame = nexus::renderer::evaluateConsoleTierFrame(stats, batched, plan);
  require(frame.projectedTriangles < stats.triangleCount,
          "low power LOD bias reduced triangle load");
  require(frame.withinMobileBudget(), "degraded frame fits low-power budget");
  require(!frame.dynamicShadows && !frame.bloomEnabled,
          "low power dropped expensive FX");
}

void active_tier_planning_on_default_arena() {
  nexus::core::PerfMonitor::instance().setTier(nexus::core::PerformanceTier::kHigh);
  const auto scene = nexus::renderer::RenderScene::createDefaultArena();
  const auto frame = nexus::renderer::planSceneForActiveTier(scene);
  require(frame.batchedDrawCalls > 0, "default arena produced batched draws");
  require(frame.withinMobileBudget(), "default arena within mobile budget");
}

} // namespace

auto main() -> int {
  batching_collapses_repeated_meshes_into_instanced_draws();
  high_tier_keeps_full_detail_within_budget();
  over_budget_frame_recommends_degrade();
  low_power_lod_bias_sheds_triangles();
  active_tier_planning_on_default_arena();
  std::fprintf(stderr, "PASS: nexus_console_tier_test\n");
  return 0;
}
