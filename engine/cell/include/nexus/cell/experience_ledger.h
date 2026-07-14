// CELL ExperienceLedger — append-only JSONL session telemetry store.
#pragma once

#include "nexus/cell/cell_config.h"
#include "nexus/core/result.h"

#include <nlohmann/json.hpp>
#include <cstddef>
#include <string>
#include <vector>

namespace nexus::cell {

/// Appends session telemetry records to per-day JSONL files under `ledgerDirectory/`.
/// BatchLearner reads recent records for the nightly batch job.
class ExperienceLedger {
public:
  explicit ExperienceLedger(std::string ledgerDirectory = "artifacts/cell-ledger");

  /// Append a session record.  Writes to `<ledgerDir>/YYYY-MM-DD.jsonl`.
  auto append(const nlohmann::json& record) -> Result<void>;

  /// Read the N most recent records across all day files (newest first).
  [[nodiscard]] auto readRecent(std::size_t maxCount) const -> std::vector<nlohmann::json>;

  [[nodiscard]] auto ledgerDirectory() const -> const std::string& { return m_ledgerDirectory; }

private:
  [[nodiscard]] auto todayFile() const -> std::string;
  [[nodiscard]] static auto todayDateString() -> std::string;

  std::string m_ledgerDirectory;
};

} // namespace nexus::cell
