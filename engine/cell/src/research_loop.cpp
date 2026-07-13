#include "nexus/cell/research_loop.h"

#include "nexus/cell/cell_parameter_delegate.h"
#include "nexus/cell/experience_ledger.h"
#include "nexus/cell/geval_scorer.h"
#include "nexus/cell/observation_bus.h"
#include "nexus/cell/spatial_sampler.h"
#include "nexus/cell/wisdom_store.h"
#include "nexus/core/job_system.h"
#include "nexus/core/log.h"

#include <nlohmann/json.hpp>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <numeric>
#include <string>
#include <unordered_map>
#include <vector>

namespace nexus::cell {

namespace {

/// Extract all numeric leaf values from a JSON object, keyed by dot-path.
void extractNumericFeatures(const nlohmann::json& j,
                             const std::string& prefix,
                             std::unordered_map<std::string, double>& out) {
  if (j.is_number()) {
    out[prefix] = j.get<double>();
  } else if (j.is_object()) {
    for (auto it = j.begin(); it != j.end(); ++it) {
      const std::string key = prefix.empty() ? it.key() : (prefix + "." + it.key());
      extractNumericFeatures(it.value(), key, out);
    }
  } else if (j.is_array()) {
    for (std::size_t i = 0; i < j.size(); ++i) {
      extractNumericFeatures(j[i], prefix + "[" + std::to_string(i) + "]", out);
    }
  }
}

/// Infer a reward signal from a raw observation if no explicit reward is present.
auto rewardFromObservation(const Observation& obs) -> double {
  switch (obs.type) {
  case ObservationType::kFrameTelemetry: {
    const double fps = obs.data.value("fps", 0.0);
    return std::min(1.0, fps / 60.0);
  }
  case ObservationType::kAgentOutput: {
    const std::string status = obs.data.value("status", "");
    return (status == "ok") ? 1.0 : 0.0;
  }
  case ObservationType::kError:
    return 0.0;
  case ObservationType::kManual:
  case ObservationType::kHardwareTelemetry:
  case ObservationType::kExternalKnowledge:
    return obs.data.value("reward", 0.5);
  default:
    return 0.5;
  }
}

struct FeatureStat {
  double sum_reward_high{0.0};
  std::size_t count_high{0};
  double sum_reward_low{0.0};
  std::size_t count_low{0};
};

} // namespace

ResearchLoop::ResearchLoop(ResearchLoopConfig config)
    : m_config(std::move(config)),
      m_scorer(GEvalConfig{m_config.geval_min_score}) {}

ResearchLoop::~ResearchLoop() {
  stop();
}

void ResearchLoop::start(ObservationBus& bus,
                         ExperienceLedger& ledger,
                         WisdomStore& wisdom,
                         nexus::core::JobSystem& jobs) {
  m_bus    = &bus;
  m_ledger = &ledger;
  m_wisdom = &wisdom;
  m_jobs   = &jobs;

  m_running.store(true, std::memory_order_release);
  m_thread = std::thread([this] { loop(); });
  NEXUS_LOG_INFO(LogChannel::kCell, "ResearchLoop started");
}

void ResearchLoop::stop() {
  if (!m_running.load(std::memory_order_acquire)) {
    return;
  }
  m_running.store(false, std::memory_order_release);
  {
    std::scoped_lock lock(m_mutex);
    m_runNow.store(true, std::memory_order_release);
  }
  m_cv.notify_all();
  if (m_thread.joinable()) {
    m_thread.join();
  }
  NEXUS_LOG_INFO(LogChannel::kCell, "ResearchLoop stopped (cycles=" +
                                        std::to_string(m_cycleCount.load()) + ")");
}

void ResearchLoop::runCycleNow() {
  {
    std::scoped_lock lock(m_mutex);
    m_runNow.store(true, std::memory_order_release);
  }
  m_cv.notify_one();
}

void ResearchLoop::attachCellParameterDelegate(CellParameterDelegate* delegate,
                                                std::vector<ParameterSandbox> sandboxes) {
  m_delegate  = delegate;
  m_sandboxes = std::move(sandboxes);
}

void ResearchLoop::attachSpatialSampler(SpatialSampler* sampler) {
  m_spatialSampler = sampler;
}

auto ResearchLoop::isRunning() const -> bool {
  return m_running.load(std::memory_order_acquire);
}

auto ResearchLoop::cycleCount() const -> std::uint64_t {
  return m_cycleCount.load(std::memory_order_relaxed);
}

auto ResearchLoop::gevalPassed() const -> std::uint64_t {
  return m_gevalPassed.load(std::memory_order_relaxed);
}

auto ResearchLoop::gevalRejected() const -> std::uint64_t {
  return m_gevalRejected.load(std::memory_order_relaxed);
}

void ResearchLoop::loop() {
  while (m_running.load(std::memory_order_acquire)) {
    {
      std::unique_lock<std::mutex> lock(m_mutex);
      m_cv.wait_for(lock, m_config.cycle_interval, [this] {
        return m_runNow.load(std::memory_order_acquire) ||
               !m_running.load(std::memory_order_acquire);
      });
      m_runNow.store(false, std::memory_order_release);
    }
    if (!m_running.load(std::memory_order_acquire)) {
      break;
    }
    runOneCycle();
  }
}

void ResearchLoop::runOneCycle() {
  harvest();
  analyseAndCommit();
  m_wisdom->decay();
  const auto saveResult = m_wisdom->save();
  if (saveResult.isErr()) {
    NEXUS_LOG_WARN(LogChannel::kCell, "ResearchLoop: wisdom save error: " + saveResult.error());
  }

  // Experimentation phase — only in kImperfectForm and kPerfectForm.
  const std::size_t ledgerSize = m_ledger ? m_ledger->totalCount() : 0;
  const CellPhase phase = cellPhaseFrom(ledgerSize, 0);
  experimentationPhase(phase);

  m_cycleCount.fetch_add(1, std::memory_order_relaxed);
}

void ResearchLoop::harvest() {
  if (m_bus == nullptr || m_ledger == nullptr) {
    return;
  }
  auto observations = m_bus->drainAll();
  for (auto& obs : observations) {
    ExperienceRecord rec;
    rec.source_system  = obs.source_system;
    rec.context_json   = obs.data;
    rec.outcome_json   = obs.data;
    rec.reward_signal  = rewardFromObservation(obs);
    m_ledger->append(std::move(rec));
  }
}

void ResearchLoop::analyseAndCommit() {
  if (m_ledger == nullptr || m_wisdom == nullptr) {
    return;
  }

  auto records = m_ledger->queryRecent(m_config.analysis_window);
  if (records.size() < m_config.min_evidence) {
    return;
  }

  // Spatial filtering: discard records outside hot zones (if sampler attached).
  if (m_spatialSampler != nullptr) {
    records = m_spatialSampler->filterRecords(std::move(records));
    if (records.size() < m_config.min_evidence) {
      return;
    }
  }

  // Group feature→reward pairs by domain.
  using DomainFeatureMap =
      std::unordered_map<std::string,                          // domain
          std::unordered_map<std::string,                      // feature name
              std::vector<std::pair<double, double>>>>;        // (value, reward)
  DomainFeatureMap byDomain;

  for (const auto& rec : records) {
    std::unordered_map<std::string, double> features;
    extractNumericFeatures(rec.context_json, "", features);
    for (const auto& [feat, val] : features) {
      byDomain[rec.source_system][feat].emplace_back(val, rec.reward_signal);
    }
  }

  // Analyse each domain and feature.
  for (const auto& [domain, featureMap] : byDomain) {
    for (const auto& [feature, pairs] : featureMap) {
      if (pairs.size() < m_config.min_evidence) {
        continue;
      }

      // Compute median feature value.
      std::vector<double> vals;
      vals.reserve(pairs.size());
      for (const auto& [v, _] : pairs) {
        vals.push_back(v);
      }
      std::sort(vals.begin(), vals.end());
      const double median = vals[vals.size() / 2];

      double sumHigh = 0.0; std::size_t countHigh = 0;
      double sumLow  = 0.0; std::size_t countLow  = 0;
      for (const auto& [v, r] : pairs) {
        if (v > median) { sumHigh += r; ++countHigh; }
        else             { sumLow  += r; ++countLow;  }
      }
      if (countHigh == 0 || countLow == 0) {
        continue;
      }
      const double meanHigh = sumHigh / static_cast<double>(countHigh);
      const double meanLow  = sumLow  / static_cast<double>(countLow);
      const double delta    = meanHigh - meanLow;

      if (std::abs(delta) < m_config.min_delta) {
        continue;
      }

      const std::string direction = (delta > 0) ? "higher" : "lower";
      const std::string impact    = (delta > 0) ? "improves" : "degrades";
      const std::string rule =
          direction + " " + feature + " " + impact + " outcomes" +
          " (delta=" + std::to_string(static_cast<int>(std::abs(delta) * 100)) + "%, n=" +
          std::to_string(pairs.size()) + ")";

      // ── Tier classification ────────────────────────────────────────────────
      // Features with one or more dots in their path are mechanical sub-rules
      // (e.g. "physics.velocity.x"). Top-level features are tactical heuristics.
      const std::size_t dotCount = std::count(feature.begin(), feature.end(), '.');
      const WisdomTier tier = (dotCount >= 1) ? WisdomTier::kMechanical : WisdomTier::kTactical;

      // For mechanical entries, derive the parent rule_text from the prefix.
      std::string parentRuleText;
      if (tier == WisdomTier::kMechanical) {
        const std::size_t lastDot = feature.rfind('.');
        const std::string parentFeature = feature.substr(0, lastDot);
        // The parent rule would have the same direction/impact pattern.
        parentRuleText = direction + " " + parentFeature + " " + impact + " outcomes";
      }

      WisdomEntry entry;
      entry.domain           = domain;
      entry.rule_text        = rule;
      entry.confidence       = std::min(1.0, std::abs(delta));
      entry.evidence_count   = static_cast<std::uint64_t>(pairs.size());
      entry.tier             = tier;
      entry.parent_rule_text = parentRuleText;

      // ── G-Eval gate ────────────────────────────────────────────────────────
      // Score the candidate; if it fails the threshold try one refinement pass.
      auto evalResult = m_scorer.score(entry);
      if (!evalResult.passes) {
        entry      = m_scorer.refine(std::move(entry));
        evalResult = m_scorer.score(entry);
      }
      if (evalResult.passes) {
        m_wisdom->upsert(std::move(entry));
        m_gevalPassed.fetch_add(1, std::memory_order_relaxed);
      } else {
        m_gevalRejected.fetch_add(1, std::memory_order_relaxed);
      }
    }
  }
}

void ResearchLoop::experimentationPhase(CellPhase phase) {
  // Gate: only run in kImperfectForm or kPerfectForm.
  if (phase < CellPhase::kImperfectForm) { return; }
  if (m_delegate == nullptr || m_sandboxes.empty()) { return; }
  if (m_ledger == nullptr) { return; }

  const std::uint64_t cycle = m_cycleCount.load(std::memory_order_relaxed);

  if (m_activeExperimentIdx < 0) {
    // Start a new experiment: pick the sandbox corresponding to the WisdomEntry
    // with the lowest confidence in any domain (most uncertain = most to learn).
    int bestIdx = 0;
    double lowestConf = 1.0;
    for (int i = 0; i < static_cast<int>(m_sandboxes.size()); ++i) {
      if (m_sandboxes[i].active) { continue; }
      // Use delegate to check the parameter exists.
      const double cur = m_delegate->getParam(m_sandboxes[i].name);
      // Estimate "uncertainty" as distance from mid-range.
      const auto& sb = m_sandboxes[i];
      const double mid = (sb.min_value + sb.max_value) * 0.5;
      const double dist = std::abs(cur - mid) / std::max(1e-6, sb.max_value - sb.min_value);
      if (dist < lowestConf) { lowestConf = dist; bestIdx = i; }
    }

    auto& sb = m_sandboxes[bestIdx];
    sb.rollback_value          = m_delegate->getParam(sb.name);
    sb.current_value           = sb.rollback_value;
    sb.experiment_start_cycle  = cycle;

    // Compute baseline mean reward from recent ledger records.
    const auto recent = m_ledger->queryRecent(50);
    double rewardSum = 0.0;
    for (const auto& r : recent) { rewardSum += r.reward_signal; }
    sb.baseline_reward = recent.empty() ? 0.5
                                        : rewardSum / static_cast<double>(recent.size());

    // Apply a +step nudge, clamped to [min, max].
    const double nudged = std::min(sb.max_value,
                                    std::max(sb.min_value, sb.current_value + sb.step_size));
    m_delegate->setParam(sb.name, nudged);
    sb.current_value = nudged;
    sb.active        = true;
    m_activeExperimentIdx = bestIdx;
    m_baselineRewardSum   = 0.0;
    m_baselineRewardCount = 0;

    NEXUS_LOG_INFO(LogChannel::kCell,
                   "ExperimentationPhase: nudging '" + sb.name + "' " +
                       std::to_string(sb.rollback_value) + " -> " +
                       std::to_string(nudged));
  } else {
    // An experiment is in progress — evaluate or continue.
    auto& sb = m_sandboxes[m_activeExperimentIdx];
    const std::uint64_t elapsed = cycle - sb.experiment_start_cycle;

    // Accumulate reward during evaluation window.
    const auto recent = m_ledger->queryRecent(10);
    double sum = 0.0;
    for (const auto& r : recent) { sum += r.reward_signal; }
    if (!recent.empty()) {
      m_baselineRewardSum += sum / static_cast<double>(recent.size());
      ++m_baselineRewardCount;
    }

    if (elapsed >= static_cast<std::uint64_t>(sb.evaluation_cycles)) {
      const double newMean = (m_baselineRewardCount > 0)
                                 ? m_baselineRewardSum /
                                       static_cast<double>(m_baselineRewardCount)
                                 : 0.0;

      if (newMean >= sb.baseline_reward + m_config.min_delta) {
        // Improvement confirmed: commit the nudge.
        sb.rollback_value = sb.current_value;
        NEXUS_LOG_INFO(LogChannel::kCell,
                       "ExperimentationPhase: committed '" + sb.name +
                           "'=" + std::to_string(sb.current_value) +
                           " (reward +" + std::to_string(newMean - sb.baseline_reward) + ")");
      } else {
        // No improvement: roll back.
        m_delegate->setParam(sb.name, sb.rollback_value);
        sb.current_value = sb.rollback_value;
        NEXUS_LOG_INFO(LogChannel::kCell,
                       "ExperimentationPhase: rolled back '" + sb.name + "'");
      }
      sb.active             = false;
      m_activeExperimentIdx = -1;
    }
  }
}

} // namespace nexus::cell
