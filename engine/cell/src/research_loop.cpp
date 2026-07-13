#include "nexus/cell/research_loop.h"

#include "nexus/cell/experience_ledger.h"
#include "nexus/cell/observation_bus.h"
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

ResearchLoop::ResearchLoop(ResearchLoopConfig config) : m_config(std::move(config)) {}

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

auto ResearchLoop::isRunning() const -> bool {
  return m_running.load(std::memory_order_acquire);
}

auto ResearchLoop::cycleCount() const -> std::uint64_t {
  return m_cycleCount.load(std::memory_order_relaxed);
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

  const auto records = m_ledger->queryRecent(m_config.analysis_window);
  if (records.size() < m_config.min_evidence) {
    return;
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

      WisdomEntry entry;
      entry.domain         = domain;
      entry.rule_text      = rule;
      entry.confidence     = std::min(1.0, std::abs(delta));
      entry.evidence_count = static_cast<std::uint64_t>(pairs.size());
      m_wisdom->upsert(std::move(entry));
    }
  }
}

} // namespace nexus::cell
