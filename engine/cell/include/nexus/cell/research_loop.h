#pragma once

// CELL Research Loop — The Mind
//
// An always-on background worker that runs a scheduled observe/analyse/
// hypothesise/validate/commit cycle, using JobSystem::parallelFor to
// parallelise the analyse step across ledger records.
//
// Cycle steps:
//   1. Harvest  — drain ObservationBus, write ExperienceRecords to ledger
//   2. Analyse  — extract numeric features per domain, correlate with reward
//   3. Hypothesise — generate WisdomEntry candidates from strong correlations
//   4. Validate — require minimum evidence_count before acceptance
//   5. Commit   — upsert surviving entries into WisdomStore

#include <atomic>
#include <condition_variable>
#include <chrono>
#include <mutex>
#include <thread>

namespace nexus::core {
class JobSystem;
}

namespace nexus::cell {
class ObservationBus;
class ExperienceLedger;
class WisdomStore;
}

namespace nexus::cell {

struct ResearchLoopConfig {
  /// Time between research cycles.
  std::chrono::seconds cycle_interval{5};
  /// Records to analyse per cycle (most recent).
  std::size_t analysis_window{1000};
  /// Minimum observations per feature before hypothesising.
  std::size_t min_evidence{10};
  /// Minimum normalised reward-delta to form a hypothesis.
  double min_delta{0.05};
};

class ResearchLoop {
public:
  explicit ResearchLoop(ResearchLoopConfig config = {});
  ~ResearchLoop();

  ResearchLoop(const ResearchLoop&) = delete;
  auto operator=(const ResearchLoop&) -> ResearchLoop& = delete;

  void start(ObservationBus& bus,
             ExperienceLedger& ledger,
             WisdomStore& wisdom,
             nexus::core::JobSystem& jobs);
  void stop();

  /// Force an immediate cycle (for testing / cell.train_now).
  void runCycleNow();

  [[nodiscard]] auto isRunning() const -> bool;
  [[nodiscard]] auto cycleCount() const -> std::uint64_t;

private:
  void loop();
  void runOneCycle();
  void harvest();
  void analyseAndCommit();

  ResearchLoopConfig      m_config;
  ObservationBus*         m_bus{nullptr};
  ExperienceLedger*        m_ledger{nullptr};
  WisdomStore*            m_wisdom{nullptr};
  nexus::core::JobSystem* m_jobs{nullptr};

  std::thread              m_thread;
  std::mutex               m_mutex;
  std::condition_variable  m_cv;
  std::atomic<bool>        m_running{false};
  std::atomic<bool>        m_runNow{false};
  std::atomic<std::uint64_t> m_cycleCount{0};
};

} // namespace nexus::cell
