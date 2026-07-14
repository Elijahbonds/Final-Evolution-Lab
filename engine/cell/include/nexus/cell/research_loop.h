// CELL ResearchLoop — online learning loop gated behind CELL_ONLINE_LEARNING compile flag.
// Default: CELL_ONLINE_LEARNING=0 → loop body is a no-op stub.
// Set CELL_ONLINE_LEARNING=1 to re-enable for dev/research use.
#pragma once

#include "nexus/cell/budget_meter.h"
#include "nexus/cell/cell_config.h"
#include "nexus/core/result.h"

#include <string>

namespace nexus::cell {

struct ResearchLoopConfig {
  std::string subsystemName{"research_loop"};
  int64_t tokensPerCycle{500};
};

/// Continuous research loop — disabled by default (CELL_ONLINE_LEARNING=0).
/// When online learning is enabled, each tick checks BudgetMeter before consuming tokens.
class ResearchLoop {
public:
  explicit ResearchLoop(ResearchLoopConfig config = {});

  /// Run one research cycle.  Returns err if budget is exhausted.
  auto tick() -> Result<void>;

  [[nodiscard]] auto isOnlineLearningEnabled() const -> bool;

private:
  ResearchLoopConfig m_config;
};

} // namespace nexus::cell
