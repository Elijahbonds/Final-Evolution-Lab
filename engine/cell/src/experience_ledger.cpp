#include "nexus/cell/experience_ledger.h"

#include "nexus/core/log.h"

#include <chrono>
#include <filesystem>
#include <fstream>
#include <sstream>

namespace nexus::cell {

namespace {

auto nowMs() -> std::uint64_t {
  using namespace std::chrono;
  return static_cast<std::uint64_t>(
      duration_cast<milliseconds>(steady_clock::now().time_since_epoch()).count());
}

auto recordToJsonLine(const ExperienceRecord& r) -> std::string {
  nlohmann::json j = {
      {"ts",      r.timestamp_ms},
      {"src",     r.source_system},
      {"ctx",     r.context_json},
      {"act",     r.action_json},
      {"out",     r.outcome_json},
      {"reward",  r.reward_signal}};
  return j.dump() + "\n";
}

} // namespace

ExperienceLedger::ExperienceLedger(ExperienceLedgerConfig config)
    : m_config(std::move(config)) {
  m_records.reserve(std::min(m_config.max_records, std::size_t{8192}));
  m_pending.reserve(m_config.flush_threshold * 2);
}

auto ExperienceLedger::init() -> Result<void> {
  try {
    std::filesystem::create_directories(m_config.ledger_dir);
  } catch (const std::exception& ex) {
    return Result<void>::err(std::string("ExperienceLedger: cannot create dir: ") + ex.what());
  }
  NEXUS_LOG_INFO(LogChannel::kCell, "ExperienceLedger initialised at " + m_config.ledger_dir);
  return Result<void>::ok();
}

void ExperienceLedger::append(ExperienceRecord record) {
  if (record.timestamp_ms == 0) {
    record.timestamp_ms = nowMs();
  }
  std::scoped_lock lock(m_mutex);

  // Evict oldest if at capacity.
  if (m_records.size() >= m_config.max_records) {
    m_records.erase(m_records.begin());
  }
  m_pending.push_back(record);
  m_pendingBytesApprox += record.source_system.size() + 64; // rough estimate
  m_records.push_back(std::move(record));

  if (m_pending.size() >= m_config.flush_threshold) {
    flushPendingLocked();
  }
}

auto ExperienceLedger::queryRecent(std::size_t n) const -> std::vector<ExperienceRecord> {
  std::scoped_lock lock(m_mutex);
  if (m_records.empty()) {
    return {};
  }
  const std::size_t count = std::min(n, m_records.size());
  return {m_records.end() - static_cast<std::ptrdiff_t>(count), m_records.end()};
}

auto ExperienceLedger::queryByReward(double min_reward, std::size_t max_results) const
    -> std::vector<ExperienceRecord> {
  std::scoped_lock lock(m_mutex);
  std::vector<ExperienceRecord> out;
  out.reserve(std::min(max_results, m_records.size()));
  for (auto it = m_records.rbegin(); it != m_records.rend() && out.size() < max_results; ++it) {
    if (it->reward_signal >= min_reward) {
      out.push_back(*it);
    }
  }
  return out;
}

auto ExperienceLedger::totalCount() const -> std::size_t {
  std::scoped_lock lock(m_mutex);
  return m_records.size();
}

void ExperienceLedger::flush() {
  std::scoped_lock lock(m_mutex);
  if (!m_pending.empty()) {
    flushPendingLocked();
  }
}

void ExperienceLedger::shutdown() {
  flush();
  NEXUS_LOG_INFO(LogChannel::kCell, "ExperienceLedger shutdown (records=" +
                                        std::to_string(m_records.size()) + ")");
}

void ExperienceLedger::flushPendingLocked() {
  if (m_pending.empty()) {
    return;
  }
  const std::string path = currentShardPath();
  try {
    std::ofstream file(path, std::ios::app);
    if (file.is_open()) {
      for (const auto& rec : m_pending) {
        file << recordToJsonLine(rec);
      }
      // Roll to a new shard after ~1 MB of writes.
      if (m_pendingBytesApprox > 1'048'576) {
        ++m_shardIndex;
        m_pendingBytesApprox = 0;
      }
    }
  } catch (const std::exception& ex) {
    // Disk writes are best-effort — never let I/O errors propagate to callers.
    NEXUS_LOG_WARN(LogChannel::kCell,
                   std::string("ExperienceLedger: flush failed: ") + ex.what());
  }
  m_pending.clear();
  m_pendingBytesApprox = 0;
}

auto ExperienceLedger::currentShardPath() const -> std::string {
  std::ostringstream ss;
  ss << m_config.ledger_dir << "/shard_";
  ss.width(4);
  ss.fill('0');
  ss << m_shardIndex << ".jsonl";
  return ss.str();
}

} // namespace nexus::cell
