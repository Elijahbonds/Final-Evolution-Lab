#pragma once

// CELL Experience Ledger — Memory
//
// An append-only, in-memory log of ExperienceRecord structs backed by a rolling
// JSONL file store in artifacts/cell/ledger/.  The in-memory ring is capped at
// max_records; oldest entries are evicted when full.  Pending writes are flushed
// to the current shard when the pending buffer exceeds flush_threshold entries.

#include "nexus/core/result.h"

#include <cstdint>
#include <mutex>
#include <string>
#include <vector>

#include <nlohmann/json.hpp>

namespace nexus::cell {

struct ExperienceRecord {
  std::uint64_t  timestamp_ms{0};
  std::string    source_system;
  nlohmann::json context_json;  ///< inputs / environment snapshot
  nlohmann::json action_json;   ///< action taken (may be empty)
  nlohmann::json outcome_json;  ///< observed result
  double         reward_signal{0.0}; ///< normalised scalar in [-1, 1]
};

struct ExperienceLedgerConfig {
  std::string   ledger_dir{"artifacts/cell/ledger"};
  std::size_t   max_records{100'000};
  std::size_t   flush_threshold{256}; ///< flush to disk after this many pending records
};

class ExperienceLedger {
public:
  explicit ExperienceLedger(ExperienceLedgerConfig config = {});

  /// Creates the ledger directory if absent. Must be called before append().
  auto init() -> Result<void>;

  void append(ExperienceRecord record);

  /// Returns up to n most-recent records (newest last). Thread-safe.
  [[nodiscard]] auto queryRecent(std::size_t n) const -> std::vector<ExperienceRecord>;

  /// Returns up to max_results records where reward >= min_reward. Thread-safe.
  [[nodiscard]] auto queryByReward(double min_reward, std::size_t max_results) const
      -> std::vector<ExperienceRecord>;

  [[nodiscard]] auto totalCount() const -> std::size_t;

  /// Force-flush any pending write-behind records to disk.
  void flush();

  void shutdown();

private:
  void flushPendingLocked();          ///< caller holds m_mutex
  [[nodiscard]] auto currentShardPath() const -> std::string;

  ExperienceLedgerConfig     m_config;
  mutable std::mutex         m_mutex;
  std::vector<ExperienceRecord> m_records; ///< in-memory ring, capped at max_records
  std::vector<ExperienceRecord> m_pending; ///< awaiting disk flush
  std::uint32_t              m_shardIndex{0};
  std::size_t                m_pendingBytesApprox{0};
};

} // namespace nexus::cell
