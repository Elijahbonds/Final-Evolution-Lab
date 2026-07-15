// CELL BudgetMeter — per-subsystem daily token caps with hard stop and overage logging.
// Any CELL subsystem that makes LLM calls MUST call consume() first and return early if false.
#pragma once

#include "nexus/cell/cell_config.h"
#include "nexus/core/result.h"

#include <nlohmann/json.hpp>
#include <cstdint>
#include <mutex>
#include <string>
#include <string_view>
#include <unordered_map>

namespace nexus::cell {

struct BudgetStatus {
  std::string subsystem;
  int64_t usedToday{0};
  int64_t dailyCap{0};
  [[nodiscard]] auto remaining() const -> int64_t { return dailyCap - usedToday; }
  [[nodiscard]] auto overBudget() const -> bool { return usedToday >= dailyCap; }
};

/// Thread-safe singleton token budget enforcer.
/// Call BudgetMeter::instance() to get the singleton; configure once at startup.
class BudgetMeter {
public:
  static auto instance() -> BudgetMeter&;

  void configure(BudgetConfig config);

  /// Attempt to consume `tokens` from `subsystem`'s daily quota.
  /// Returns false (and logs the skip) if the cap would be exceeded.
  [[nodiscard]] auto consume(std::string_view subsystem, int64_t tokens) -> bool;

  [[nodiscard]] auto status(std::string_view subsystem) const -> BudgetStatus;
  [[nodiscard]] auto allStatus() const -> std::vector<BudgetStatus>;

  /// Reset all counters (called at midnight / start of a new day).
  void resetDaily();

  /// Flush the budget state to today's log file.
  auto flushLog() -> Result<void>;

private:
  BudgetMeter() = default;

  auto logSkip(std::string_view subsystem, int64_t requested, int64_t cap) -> void;
  [[nodiscard]] static auto todayDateString() -> std::string;

  BudgetConfig m_config;
  std::unordered_map<std::string, int64_t> m_used;
  mutable std::mutex m_mutex;
  std::string m_currentDay;
};

} // namespace nexus::cell
