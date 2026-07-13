#pragma once

#include <cstdint>
#include <string>
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

} // namespace nexus::cell
