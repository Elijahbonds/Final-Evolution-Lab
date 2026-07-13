#include "nexus/cell/future_state_buffer.h"

#include <algorithm>
#include <cmath>
#include <unordered_map>

namespace nexus::cell {

void FutureStateBuffer::park(PredictedOutcome outcome) {
  std::scoped_lock lock(m_mutex);
  if (m_ring.size() < kCapacity) {
    m_ring.push_back(std::move(outcome));
  } else {
    m_ring[m_writeIdx % kCapacity] = std::move(outcome);
  }
  ++m_writeIdx;
}

auto FutureStateBuffer::resolve(const std::string& source_system,
                                 const nlohmann::json& actual_json)
    -> std::optional<PredictedOutcome> {
  std::scoped_lock lock(m_mutex);
  // Search from newest to oldest for the most-recent unresolved prediction
  // matching this source.
  for (auto it = m_ring.rbegin(); it != m_ring.rend(); ++it) {
    if (!it->resolved && it->source_system == source_system) {
      it->actual_json = actual_json;
      it->resolved    = true;
      return *it;
    }
  }
  return std::nullopt;
}

auto FutureStateBuffer::pendingCount() const -> std::size_t {
  std::scoped_lock lock(m_mutex);
  std::size_t count = 0;
  for (const auto& p : m_ring) {
    if (!p.resolved) { ++count; }
  }
  return count;
}

// ── computeSurprise ──────────────────────────────────────────────────────────

namespace {

void collectNumericLeaves(const nlohmann::json& j, const std::string& prefix,
                           std::unordered_map<std::string, double>& out) {
  if (j.is_number()) {
    out[prefix] = j.get<double>();
  } else if (j.is_object()) {
    for (auto it = j.begin(); it != j.end(); ++it) {
      const std::string k = prefix.empty() ? it.key() : (prefix + "." + it.key());
      collectNumericLeaves(it.value(), k, out);
    }
  }
}

} // namespace

auto computeSurprise(const nlohmann::json& predicted,
                     const nlohmann::json& actual) -> double {
  std::unordered_map<std::string, double> predMap, actualMap;
  collectNumericLeaves(predicted, "", predMap);
  collectNumericLeaves(actual,    "", actualMap);

  double totalErr = 0.0;
  std::size_t shared = 0;

  for (const auto& [key, pv] : predMap) {
    const auto it = actualMap.find(key);
    if (it == actualMap.end()) { continue; }
    const double av    = it->second;
    const double denom = std::max(1.0, std::max(std::abs(pv), std::abs(av)));
    totalErr += std::abs(pv - av) / denom;
    ++shared;
  }

  return (shared > 0) ? std::min(1.0, totalErr / static_cast<double>(shared)) : 0.5;
}

} // namespace nexus::cell
