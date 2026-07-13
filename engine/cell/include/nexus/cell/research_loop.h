#pragma once

// CELL Research Loop — The Mind
//
// An always-on background worker that runs a scheduled observe/analyse/
// hypothesise/validate/commit cycle, using JobSystem::parallelFor to
// parallelise the analyse step across ledger records.
//
// Cycle steps:
//   1. Harvest      — drain ObservationBus, write ExperienceRecords to ledger
//   2. Analyse      — extract numeric features per domain, correlate with reward
//   3. Hypothesise  — generate WisdomEntry candidates from strong correlations
//   4. Validate     — require minimum evidence_count before acceptance
//   5. Commit       — upsert surviving entries into WisdomStore
//   6. Experiment   — nudge a low-confidence parameter (kImperfectForm+ only)

#include "nexus/cell/cell_types.h"
#include "nexus/cell/geval_scorer.h"

#include <atomic>
#include <condition_variable>
#include <chrono>
#include <mutex>
#include <thread>
#include <vector>

namespace nexus::core {
class JobSystem;
}

namespace nexus::cell {
class CellParameterDelegate;
class ObservationBus;
class ExperienceLedger;
class SpatialSampler;
class WisdomStore;
} // namespace nexus::cell

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
  /// Minimum G-Eval aggregate score [0–10] for a WisdomEntry to be committed.
  /// Entries below this threshold are refined once and re-scored before discard.
  double geval_min_score{6.0};
};

class ResearchLoop {
public:
  explicit ResearchLoop(ResearchLoopConfig config = {});
  ~ResearchLoop();

  ResearchLoop(const ResearchLoop&)            = delete;
  auto operator=(const ResearchLoop&) -> ResearchLoop& = delete;

  void start(ObservationBus& bus,
             ExperienceLedger& ledger,
             WisdomStore& wisdom,
             nexus::core::JobSystem& jobs);
  void stop();

  /// Force an immediate cycle (for testing / cell.train_now).
  void runCycleNow();

  /// Attach a parameter delegate and its configurable sandboxes.
  /// Must be called before start() or guarded externally.
  void attachCellParameterDelegate(CellParameterDelegate* delegate,
                                   std::vector<ParameterSandbox> sandboxes);

  /// Attach a spatial sampler that pre-filters records before analysis.
  void attachSpatialSampler(SpatialSampler* sampler);

  [[nodiscard]] auto isRunning() const -> bool;
  [[nodiscard]] auto cycleCount() const -> std::uint64_t;
  [[nodiscard]] auto gevalPassed() const -> std::uint64_t;
  [[nodiscard]] auto gevalRejected() const -> std::uint64_t;

private:
  void loop();
  void runOneCycle();
  void harvest();
  void analyseAndCommit();
  void experimentationPhase(CellPhase phase);

  ResearchLoopConfig      m_config;
  ObservationBus*         m_bus{nullptr};
  ExperienceLedger*        m_ledger{nullptr};
  WisdomStore*            m_wisdom{nullptr};
  nexus::core::JobSystem* m_jobs{nullptr};

  // G-Eval scorer — gates wisdom writes
  GEvalScorer             m_scorer;

  // Experimentation state
  CellParameterDelegate*        m_delegate{nullptr};
  std::vector<ParameterSandbox> m_sandboxes;
  int                           m_activeExperimentIdx{-1};
  double                        m_baselineRewardSum{0.0};
  std::size_t                   m_baselineRewardCount{0};

  // Spatial sampler
  SpatialSampler* m_spatialSampler{nullptr};

  std::thread              m_thread;
  std::mutex               m_mutex;
  std::condition_variable  m_cv;
  std::atomic<bool>        m_running{false};
  std::atomic<bool>        m_runNow{false};
  std::atomic<std::uint64_t> m_cycleCount{0};
  std::atomic<std::uint64_t> m_gevalPassed{0};
  std::atomic<std::uint64_t> m_gevalRejected{0};
};

} // namespace nexus::cell
