#pragma once

#include <cstdint>
#include <string>
#include <unordered_map>
#include <vector>

namespace nexus::cell {

/// CELL growth phase — determined by total ledger size and model version.
enum class CellPhase : std::uint8_t {
  kEmbryo,        ///< < 1 000 records — observe only
  kLarva,         ///< 1 000–9 999 records — pattern analysis begins
  kCocoon,        ///< 10 000–99 999 records — model trainer activates
  kImperfectForm, ///< 100 000–999 999 records — proactive suggestions
  kPerfectForm,   ///< 1 000 000+ records AND model v10+ — autonomous tuning
};

inline auto cellPhaseName(CellPhase phase) -> const char* {
  switch (phase) {
  case CellPhase::kEmbryo:        return "Embryo";
  case CellPhase::kLarva:         return "Larva";
  case CellPhase::kCocoon:        return "Cocoon";
  case CellPhase::kImperfectForm: return "ImperfectForm";
  case CellPhase::kPerfectForm:   return "PerfectForm";
  }
  return "Unknown";
}

inline auto cellPhaseFrom(std::size_t ledger_size, std::uint32_t model_version) -> CellPhase {
  if (ledger_size >= 1'000'000 && model_version >= 10) return CellPhase::kPerfectForm;
  if (ledger_size >= 100'000)  return CellPhase::kImperfectForm;
  if (ledger_size >= 10'000)   return CellPhase::kCocoon;
  if (ledger_size >= 1'000)    return CellPhase::kLarva;
  return CellPhase::kEmbryo;
}

struct CellStatus {
  CellPhase         phase{CellPhase::kEmbryo};
  std::size_t       ledger_size{0};
  std::uint32_t     model_version{0};
  std::uint32_t     wisdom_count{0};
  double            model_accuracy{0.0};
  std::size_t       observation_queue_size{0};
  std::string       phase_name;
};

// ── Policy model weights ─────────────────────────────────────────────────────

/// Snapshot of the current linear model weights used for policy-guided
/// physics parameter scaling (Phase A of the Policy vs. Heuristic split).
struct PolicyWeights {
  std::unordered_map<std::string, double> weights;
  double        bias{0.0};
  std::uint32_t model_version{0};
};

// ── Parameter sandbox for active experimentation ─────────────────────────────

/// Describes a single parameter that CELL is allowed to nudge during the
/// ExperimentationPhase. The delegate enforces physical limits; the sandbox
/// tracks rollback state and evaluation progress.
struct ParameterSandbox {
  std::string   name;
  double        current_value{0.0};
  double        min_value{0.0};
  double        max_value{1.0};
  double        step_size{0.01};
  double        rollback_value{0.0};       ///< snapshot before experiment
  std::uint64_t experiment_start_cycle{0}; ///< ResearchLoop cycle when nudge applied
  std::uint32_t evaluation_cycles{5};      ///< cycles to observe before deciding
  double        baseline_reward{0.0};      ///< pre-experiment mean reward
  bool          active{false};
};

} // namespace nexus::cell
