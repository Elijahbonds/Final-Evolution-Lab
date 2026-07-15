// CELL SelfImprovementScheduler — orchestrates the nightly batch job.
// Replaces always-on learning loops with a single daily BatchLearner invocation.
#pragma once

#include "nexus/cell/batch_learner.h"
#include "nexus/cell/budget_meter.h"
#include "nexus/cell/cell_config.h"
#include "nexus/core/result.h"

#include <string>

namespace nexus::cell {

/// Decides whether the nightly batch job should run and invokes BatchLearner.
/// Call tick(deltaSeconds) from a game/server update loop; it fires once per day.
class SelfImprovementScheduler {
public:
  explicit SelfImprovementScheduler(BatchLearner& batchLearner,
                                    CellConfig config = {});

  /// Advance scheduler by `deltaSeconds`.  Triggers nightly batch when due.
  auto tick(double deltaSeconds) -> Result<void>;

  /// Force a batch run immediately (for testing or manual trigger).
  auto runNow() -> Result<BatchResult>;

  [[nodiscard]] auto secondsUntilNextBatch() const -> double;

private:
  [[nodiscard]] static auto secondsUntilMidnightUtc() -> double;

  BatchLearner& m_batchLearner;
  CellConfig m_config;
  double m_secondsUntilBatch{0.0};
  bool m_initialised{false};
};

} // namespace nexus::cell
