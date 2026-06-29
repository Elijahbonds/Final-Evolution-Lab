#include "nexus/core/engine_scale_policy.h"

#include <algorithm>
#include <cmath>

namespace nexus::core {

auto scalePlanForTier(PerformanceTier tier) -> EngineScalePlan {
  EngineScalePlan plan{};
  switch (tier) {
  case PerformanceTier::kHigh:
    // Console-tier path: maximum fidelity inside the mobile cap.
    plan.physicsSubsteps = 2;
    plan.constraintIterations = 8;
    plan.continuousCollision = true;
    plan.triangleBudget = kSceneTriangleBudget;
    plan.drawCallBudget = kMaxDrawCallsMobile;
    plan.shadowMapSize = 1024;
    plan.lodDistanceBias = 1.0F;
    plan.dynamicShadows = true;
    plan.bloomEnabled = true;
    plan.workerUtilization = 1.0F;
    break;
  case PerformanceTier::kBalanced:
    plan.physicsSubsteps = 1;
    plan.constraintIterations = 6;
    plan.continuousCollision = true;
    plan.triangleBudget = static_cast<std::size_t>(kSceneTriangleBudget * 0.8);  // 104k
    plan.drawCallBudget = static_cast<std::size_t>(kMaxDrawCallsMobile * 0.8);   // 600
    plan.shadowMapSize = 768;
    plan.lodDistanceBias = 1.4F;
    plan.dynamicShadows = true;
    plan.bloomEnabled = true;
    plan.workerUtilization = 0.75F;
    break;
  case PerformanceTier::kLowPower:
    plan.physicsSubsteps = 1;
    plan.constraintIterations = 4;
    plan.continuousCollision = false;
    plan.triangleBudget = static_cast<std::size_t>(kSceneTriangleBudget * 0.55); // 71.5k
    plan.drawCallBudget = static_cast<std::size_t>(kMaxDrawCallsMobile * 0.6);   // 450
    plan.shadowMapSize = 512;
    plan.lodDistanceBias = 2.2F;
    plan.dynamicShadows = false;
    plan.bloomEnabled = false;
    plan.workerUtilization = 0.5F;
    break;
  }
  return plan;
}

auto activeScalePlan() -> EngineScalePlan {
  return scalePlanForTier(PerfMonitor::instance().getTier());
}

auto effectiveWorkerCount(const EngineScalePlan& plan, std::size_t availableWorkers)
    -> std::size_t {
  if (availableWorkers == 0) {
    return 0;
  }
  const auto scaled = static_cast<std::size_t>(
      std::lround(static_cast<double>(availableWorkers) * plan.workerUtilization));
  return std::clamp<std::size_t>(scaled, 1, availableWorkers);
}

} // namespace nexus::core
