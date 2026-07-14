#include "nexus/cell/budget_meter.h"
#include "nexus/core/log.h"

#include <chrono>
#include <ctime>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <sstream>

namespace nexus::cell {

auto BudgetMeter::instance() -> BudgetMeter& {
  static BudgetMeter singleton;
  return singleton;
}

void BudgetMeter::configure(BudgetConfig config) {
  std::lock_guard lock(m_mutex);
  m_config = std::move(config);
  m_currentDay = todayDateString();
}

auto BudgetMeter::todayDateString() -> std::string {
  const auto now = std::chrono::system_clock::now();
  const std::time_t tt = std::chrono::system_clock::to_time_t(now);
  std::tm tmBuf{};
#if defined(_WIN32)
  gmtime_s(&tmBuf, &tt);
#else
  gmtime_r(&tt, &tmBuf);
#endif
  std::ostringstream oss;
  oss << std::put_time(&tmBuf, "%Y-%m-%d");
  return oss.str();
}

auto BudgetMeter::consume(std::string_view subsystem, int64_t tokens) -> bool {
  std::lock_guard lock(m_mutex);

  // Auto-reset on day rollover.
  const std::string today = todayDateString();
  if (today != m_currentDay) {
    m_used.clear();
    m_currentDay = today;
  }

  const std::string key{subsystem};
  const auto capIt = m_config.maxTokensPerDay.find(key);
  const int64_t cap = (capIt != m_config.maxTokensPerDay.end()) ? capIt->second : 0;

  if (cap == 0) {
    // No cap configured → allow (opt-in enforcement).
    m_used[key] += tokens;
    return true;
  }

  const int64_t current = m_used[key];
  if (current + tokens > cap) {
    logSkip(subsystem, tokens, cap);
    return false;
  }
  m_used[key] += tokens;
  return true;
}

auto BudgetMeter::status(std::string_view subsystem) const -> BudgetStatus {
  std::lock_guard lock(m_mutex);
  const std::string key{subsystem};
  const auto capIt = m_config.maxTokensPerDay.find(key);
  const int64_t cap = (capIt != m_config.maxTokensPerDay.end()) ? capIt->second : 0;
  const auto usedIt = m_used.find(key);
  const int64_t used = (usedIt != m_used.end()) ? usedIt->second : 0;
  return BudgetStatus{key, used, cap};
}

auto BudgetMeter::allStatus() const -> std::vector<BudgetStatus> {
  std::lock_guard lock(m_mutex);
  std::vector<BudgetStatus> out;
  out.reserve(m_config.maxTokensPerDay.size());
  for (const auto& [key, cap] : m_config.maxTokensPerDay) {
    const auto usedIt = m_used.find(key);
    const int64_t used = (usedIt != m_used.end()) ? usedIt->second : 0;
    out.push_back(BudgetStatus{key, used, cap});
  }
  return out;
}

void BudgetMeter::resetDaily() {
  std::lock_guard lock(m_mutex);
  m_used.clear();
  m_currentDay = todayDateString();
  NEXUS_LOG_INFO(nexus::LogChannel::kCell, "[BudgetMeter] Daily counters reset.");
}

auto BudgetMeter::flushLog() -> Result<void> {
  std::lock_guard lock(m_mutex);
  std::error_code ec;
  std::filesystem::create_directories(m_config.logDirectory, ec);
  if (ec) {
    return Result<void>::err("BudgetMeter: cannot create log dir: " + ec.message());
  }
  const std::string logFile = m_config.logDirectory + "/" + todayDateString() + ".jsonl";
  std::ofstream stream(logFile, std::ios::app);
  if (!stream.is_open()) {
    return Result<void>::err("BudgetMeter: cannot open log " + logFile);
  }
  nlohmann::json entry = nlohmann::json::object();
  for (const auto& [key, cap] : m_config.maxTokensPerDay) {
    const auto usedIt = m_used.find(key);
    const int64_t used = (usedIt != m_used.end()) ? usedIt->second : 0;
    entry[key] = {{"used", used}, {"cap", cap}};
  }
  stream << entry.dump() << '\n';
  return Result<void>::ok();
}

void BudgetMeter::logSkip(std::string_view subsystem, int64_t requested, int64_t cap) {
  // Called with lock held — write to log file.
  const std::string logFile = m_config.logDirectory + "/" + todayDateString() + ".jsonl";
  std::ofstream stream(logFile, std::ios::app);
  if (stream.is_open()) {
    nlohmann::json skip{
        {"event", "budget_skip"},
        {"subsystem", std::string(subsystem)},
        {"requested", requested},
        {"cap", cap},
        {"used", m_used[std::string(subsystem)]},
    };
    stream << skip.dump() << '\n';
  }
  NEXUS_LOG_WARN(nexus::LogChannel::kCell,
                 "[BudgetMeter] " + std::string(subsystem) +
                     " over cap — skipping. cap=" + std::to_string(cap));
}

} // namespace nexus::cell
