#include "nexus/cell/experience_ledger.h"

#include "nexus/core/log.h"

#include <chrono>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <sstream>

#if !defined(_WIN32)
#  include <sys/mman.h>
#endif

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

ExperienceLedger::~ExperienceLedger() {
  destroyPODRing();
}

auto ExperienceLedger::init() -> Result<void> {
  try {
    std::filesystem::create_directories(m_config.ledger_dir);
  } catch (const std::exception& ex) {
    return Result<void>::err(std::string("ExperienceLedger: cannot create dir: ") + ex.what());
  }
  if (m_config.use_zero_copy_ring) {
    initPODRing();
  }
  NEXUS_LOG_INFO(LogChannel::kCell, "ExperienceLedger initialised at " + m_config.ledger_dir);
  return Result<void>::ok();
}

void ExperienceLedger::initPODRing() {
  m_podRingBytes = kPODRingCapacity * sizeof(ExperienceRecordPOD);

#if !defined(_WIN32)
  void* ptr = mmap(nullptr,
                   m_podRingBytes,
                   PROT_READ | PROT_WRITE,
                   MAP_PRIVATE | MAP_ANONYMOUS,
                   -1, 0);
  if (ptr != MAP_FAILED) { // NOLINT
    m_podRing      = static_cast<ExperienceRecordPOD*>(ptr);
    m_podRingOwned = true; // mmap-backed
    return;
  }
#endif
  // Fallback: heap allocation.
  m_podRing      = new ExperienceRecordPOD[kPODRingCapacity]{}; // NOLINT
  m_podRingOwned = false;
}

void ExperienceLedger::destroyPODRing() {
  if (m_podRing == nullptr) { return; }
#if !defined(_WIN32)
  if (m_podRingOwned) {
    munmap(m_podRing, m_podRingBytes);
    m_podRing = nullptr;
    return;
  }
#endif
  delete[] m_podRing; // NOLINT
  m_podRing = nullptr;
}

void ExperienceLedger::appendToPODRing(const ExperienceRecord& record) {
  if (m_podRing == nullptr) { return; }
  const std::uint64_t idx = m_podWriteIdx.fetch_add(1, std::memory_order_relaxed)
                            % kPODRingCapacity;
  auto& pod        = m_podRing[idx];
  pod.timestamp_ms = record.timestamp_ms;
  pod.reward_signal = record.reward_signal;

  std::strncpy(pod.source_system, record.source_system.c_str(), kSourceSystemMax - 1);
  pod.source_system[kSourceSystemMax - 1] = '\0';

  const std::string ctxStr = record.context_json.dump();
  std::strncpy(pod.context_json, ctxStr.c_str(), kContextJsonMax - 1);
  pod.context_json[kContextJsonMax - 1] = '\0';

  const std::string outStr = record.outcome_json.dump();
  std::strncpy(pod.outcome_json, outStr.c_str(), kOutcomeJsonMax - 1);
  pod.outcome_json[kOutcomeJsonMax - 1] = '\0';
}

void ExperienceLedger::append(ExperienceRecord record) {
  if (record.timestamp_ms == 0) {
    record.timestamp_ms = nowMs();
  }
  // Write to the mmap POD ring (allocation-free hot path) before locking.
  appendToPODRing(record);

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

void ExperienceLedger::forEachPOD(
    std::size_t n,
    const std::function<void(const ExperienceRecordPOD&)>& fn) const {
  if (m_podRing == nullptr) { return; }
  const std::uint64_t writeIdx = m_podWriteIdx.load(std::memory_order_acquire);
  const std::uint64_t total =
      std::min(writeIdx, static_cast<std::uint64_t>(kPODRingCapacity));
  const std::size_t count =
      static_cast<std::size_t>(std::min(static_cast<std::uint64_t>(n), total));
  if (count == 0) { return; }
  // Iterate oldest to newest.
  for (std::size_t i = 0; i < count; ++i) {
    const std::uint64_t ringIdx = (writeIdx - count + i) % kPODRingCapacity;
    fn(m_podRing[ringIdx]);
  }
}

auto ExperienceLedger::queryRecentPOD(std::size_t n) const
    -> std::vector<ExperienceRecordPOD> {
  std::vector<ExperienceRecordPOD> out;
  out.reserve(n);
  forEachPOD(n, [&](const ExperienceRecordPOD& rec) { out.push_back(rec); });
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

