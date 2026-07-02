#include "nexus/core/engine_scale_policy.h"
#include "nexus/core/perf_monitor.h"

#include <cstdio>
#include <cstdlib>

namespace {

using nexus::core::EngineScalePlan;
using nexus::core::PerformanceTier;

void require(bool condition, const char* message) {
  if (!condition) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    std::exit(1);
  }
}

void high_tier_is_console_grade_within_budget() {
  const EngineScalePlan p = nexus::core::scalePlanForTier(PerformanceTier::kHigh);
  require(p.withinMobileBudget(), "high tier within mobile budget");
  require(p.physicsSubsteps == 2, "high tier 2 substeps");
  require(p.continuousCollision, "high tier CCD on");
  require(p.dynamicShadows && p.bloomEnabled, "high tier full FX");
  require(p.triangleBudget == nexus::core::kSceneTriangleBudget,
          "high tier full triangle budget");
}

void tiers_degrade_monotonically() {
  const EngineScalePlan hi = nexus::core::scalePlanForTier(PerformanceTier::kHigh);
  const EngineScalePlan bal = nexus::core::scalePlanForTier(PerformanceTier::kBalanced);
  const EngineScalePlan low = nexus::core::scalePlanForTier(PerformanceTier::kLowPower);

  require(hi.triangleBudget >= bal.triangleBudget, "tri budget hi>=bal");
  require(bal.triangleBudget >= low.triangleBudget, "tri budget bal>=low");
  require(hi.drawCallBudget >= bal.drawCallBudget, "draw budget hi>=bal");
  require(bal.drawCallBudget >= low.drawCallBudget, "draw budget bal>=low");
  require(hi.shadowMapSize >= bal.shadowMapSize, "shadow hi>=bal");
  require(bal.shadowMapSize >= low.shadowMapSize, "shadow bal>=low");
  require(low.lodDistanceBias >= bal.lodDistanceBias, "lod bias low>=bal");
  require(bal.lodDistanceBias >= hi.lodDistanceBias, "lod bias bal>=hi");

  require(!low.continuousCollision, "low power disables CCD");
  require(!low.dynamicShadows, "low power disables shadows");
  require(!low.bloomEnabled, "low power disables bloom");

  // All tiers must respect the mobile cap.
  require(hi.withinMobileBudget() && bal.withinMobileBudget() && low.withinMobileBudget(),
          "every tier within mobile budget");
}

void worker_count_scales_and_clamps() {
  const EngineScalePlan hi = nexus::core::scalePlanForTier(PerformanceTier::kHigh);
  const EngineScalePlan low = nexus::core::scalePlanForTier(PerformanceTier::kLowPower);
  require(nexus::core::effectiveWorkerCount(hi, 8) == 8, "high uses all workers");
  require(nexus::core::effectiveWorkerCount(low, 8) == 4, "low halves workers");
  require(nexus::core::effectiveWorkerCount(low, 1) == 1, "never drops below 1");
  require(nexus::core::effectiveWorkerCount(hi, 0) == 0, "zero pool -> zero");
}

void active_plan_tracks_perf_monitor() {
  nexus::core::PerfMonitor::instance().setTier(PerformanceTier::kLowPower);
  const EngineScalePlan plan = nexus::core::activeScalePlan();
  require(!plan.continuousCollision, "active plan reflects low power tier");
  nexus::core::PerfMonitor::instance().setTier(PerformanceTier::kHigh);
  require(nexus::core::activeScalePlan().continuousCollision,
          "active plan reflects high tier");
}

} // namespace

auto main() -> int {
  high_tier_is_console_grade_within_budget();
  tiers_degrade_monotonically();
  worker_count_scales_and_clamps();
  active_plan_tracks_perf_monitor();
  std::fprintf(stderr, "PASS: nexus_scale_policy_test\n");
  return 0;
}
