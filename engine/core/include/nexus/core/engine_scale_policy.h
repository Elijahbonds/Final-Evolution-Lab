#pragma once

// NEXUS engine self-scaling policy (Workstream 5).
//
// Central translation from a PerfMonitor PerformanceTier into per-subsystem
// budgets so physics, renderer, and the job system degrade together and stay
// inside the mobile ship budget (60 FPS, <=130k tris, <750 draw calls, <400MB).
// Console-tier (kHigh) unlocks the richest path; kBalanced/kLowPower auto-degrade.

#include "nexus/core/perf_monitor.h"

#include <cstddef>
#include <cstdint>

namespace nexus::core {

struct EngineScalePlan {
  // Physics
  std::uint32_t physicsSubsteps{2};       // fixed-step substeps per frame
  std::uint32_t constraintIterations{8};  // solver iterations
  bool continuousCollision{true};         // CCD on/off

  // Renderer
  std::size_t triangleBudget{kSceneTriangleBudget};
  std::size_t drawCallBudget{kMaxDrawCallsMobile};
  std::uint32_t shadowMapSize{1024};
  float lodDistanceBias{1.0F};            // >1 pulls LOD switch nearer (cheaper)
  bool dynamicShadows{true};
  bool bloomEnabled{true};

  // Job system
  float workerUtilization{1.0F};          // fraction of available workers to use

  [[nodiscard]] auto withinMobileBudget() const -> bool {
    return triangleBudget <= kSceneTriangleBudget &&
           drawCallBudget <= kMaxDrawCallsMobile;
  }
};

/// Deterministic mapping tier -> budgets. Pure function (no global reads).
[[nodiscard]] auto scalePlanForTier(PerformanceTier tier) -> EngineScalePlan;

/// Convenience: reads the active tier from PerfMonitor::instance().
[[nodiscard]] auto activeScalePlan() -> EngineScalePlan;

/// Effective worker count for a plan given an available worker pool size.
[[nodiscard]] auto effectiveWorkerCount(const EngineScalePlan& plan,
                                        std::size_t availableWorkers) -> std::size_t;

} // namespace nexus::core
