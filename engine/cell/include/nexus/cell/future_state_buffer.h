#pragma once

// CELL Future State Buffer — Predictive Telemetry
//
// A fixed-capacity ring that parks CELL's forward-model predictions and
// resolves them against actual outcomes once the physics step completes.
// The "surprise" signal (1 - normalised_distance(predicted, actual)) is
// pushed back into ObservationBus as a kGenerativeEvent, providing a
// high-fidelity learning signal that is far richer than plain event logs.

#include <cstddef>
#include <cstdint>
#include <mutex>
#include <optional>
#include <string>
#include <vector>

#include <nlohmann/json.hpp>

namespace nexus::cell {

struct PredictedOutcome {
  std::string    source_system;
  nlohmann::json predicted_json;
  nlohmann::json actual_json;         ///< empty until resolved
  double         timestamp_seconds{0.0};
  bool           resolved{false};
};

/// Thread-safe fixed-capacity ring for in-flight CELL predictions.
/// When full, the oldest unresolved prediction is silently overwritten.
class FutureStateBuffer {
public:
  static constexpr std::size_t kCapacity = 256;

  /// Park a new prediction into the ring.
  void park(PredictedOutcome outcome);

  /// Resolve the most recent unresolved prediction for source_system.
  /// Fills actual_json, marks the entry resolved, and returns a copy.
  /// Returns std::nullopt if no matching unresolved entry exists.
  [[nodiscard]] auto resolve(const std::string& source_system,
                             const nlohmann::json& actual_json)
      -> std::optional<PredictedOutcome>;

  /// Number of unresolved (pending) entries across all sources.
  [[nodiscard]] auto pendingCount() const -> std::size_t;

private:
  mutable std::mutex            m_mutex;
  std::vector<PredictedOutcome> m_ring;
  std::size_t                   m_writeIdx{0};
};

// ── Surprise metric ──────────────────────────────────────────────────────────

/// Compute a normalised surprise scalar in [0, 1] between two JSON objects.
/// surprise = mean( |pred[k] - actual[k]| / max(1.0, |pred[k]|, |actual[k]|) )
/// over all numeric keys present in both objects.
/// Returns 0.5 when no numeric keys are shared (maximum uncertainty).
[[nodiscard]] auto computeSurprise(const nlohmann::json& predicted,
                                   const nlohmann::json& actual) -> double;

} // namespace nexus::cell
