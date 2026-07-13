#pragma once

// CELL Observation Bus — The Senses
//
// A mutex-protected ring buffer that any engine subsystem can push an Observation
// into without blocking. The ring overwrites the oldest entry when full.
// DrainAll() atomically swaps the internal buffer out, returning all pending
// observations for processing by the ResearchLoop.

#include <cstdint>
#include <mutex>
#include <string>
#include <vector>

#include <nlohmann/json.hpp>

namespace nexus::cell {

enum class ObservationType : std::uint8_t {
  kFrameTelemetry,  ///< fps, frameTimeMs, tier from PerfMonitor
  kAgentInput,      ///< AgentMessage received
  kAgentOutput,     ///< AgentResponse emitted (status + payload)
  kGameplayOutcome, ///< scores, events from ApplicationUpdateHook
  kGenerativeEvent, ///< scan/model generation results
  kError,           ///< error or failure record
  kManual,          ///< manually injected via cell.observe command
};

struct Observation {
  ObservationType type{ObservationType::kManual};
  std::string     source_system;
  nlohmann::json  data;
  double          timestamp_seconds{0.0};
};

/// Thread-safe ring buffer for engine observations.
/// push() never blocks — oldest entry is silently dropped when at capacity.
class ObservationBus {
public:
  static constexpr std::size_t kCapacity = 4096;

  /// Push an observation. Returns true normally, false if the oldest was dropped.
  auto push(Observation obs) -> bool;

  /// Drain and return all buffered observations atomically.
  [[nodiscard]] auto drainAll() -> std::vector<Observation>;

  /// Current number of buffered observations (informational only).
  [[nodiscard]] auto size() const -> std::size_t;

private:
  mutable std::mutex     m_mutex;
  std::vector<Observation> m_buffer;
};

} // namespace nexus::cell
