#include "nexus/cell/self_improvement_scheduler.h"
#include "nexus/core/log.h"

#include <chrono>
#include <ctime>

namespace nexus::cell {

namespace {
constexpr double kSecondsPerDay = 86400.0;
} // namespace

SelfImprovementScheduler::SelfImprovementScheduler(BatchLearner& batchLearner,
                                                    CellConfig config)
    : m_batchLearner(batchLearner), m_config(std::move(config)) {}

auto SelfImprovementScheduler::secondsUntilMidnightUtc() -> double {
  const auto now = std::chrono::system_clock::now();
  const std::time_t tt = std::chrono::system_clock::to_time_t(now);
  std::tm tmBuf{};
#if defined(_WIN32)
  gmtime_s(&tmBuf, &tt);
#else
  gmtime_r(&tt, &tmBuf);
#endif
  const double secondsIntoDay =
      static_cast<double>(tmBuf.tm_hour) * 3600.0 +
      static_cast<double>(tmBuf.tm_min) * 60.0 +
      static_cast<double>(tmBuf.tm_sec);
  return kSecondsPerDay - secondsIntoDay;
}

auto SelfImprovementScheduler::tick(double deltaSeconds) -> Result<void> {
  if (!m_batchLearner.config().batchLearningEnabled) {
    return Result<void>::ok();
  }

  if (!m_initialised) {
    m_secondsUntilBatch = secondsUntilMidnightUtc();
    m_initialised = true;
    NEXUS_LOG_INFO(nexus::LogChannel::kCell,
                   "[Scheduler] Next batch in " +
                       std::to_string(static_cast<int>(m_secondsUntilBatch / 3600.0)) + "h");
  }

  m_secondsUntilBatch -= deltaSeconds;
  if (m_secondsUntilBatch > 0.0) {
    return Result<void>::ok();
  }

  // Schedule next batch for 24h from now.
  m_secondsUntilBatch = kSecondsPerDay;

  // Check budget before running.
  constexpr int64_t kBatchBudgetCheck = 1000;
  if (!BudgetMeter::instance().consume("batch_learner", kBatchBudgetCheck)) {
    NEXUS_LOG_WARN(nexus::LogChannel::kCell,
                   "[Scheduler] batch_learner budget exhausted — skipping nightly batch.");
    return Result<void>::ok();
  }

  const auto batchResult = m_batchLearner.runNightlyBatch();
  if (batchResult.isErr()) {
    NEXUS_LOG_WARN(nexus::LogChannel::kCell,
                   "[Scheduler] Nightly batch failed: " + batchResult.error());
  }
  return Result<void>::ok();
}

auto SelfImprovementScheduler::runNow() -> Result<BatchResult> {
  m_secondsUntilBatch = kSecondsPerDay;
  return m_batchLearner.runNightlyBatch();
}

auto SelfImprovementScheduler::secondsUntilNextBatch() const -> double {
  return m_secondsUntilBatch;
}

} // namespace nexus::cell
