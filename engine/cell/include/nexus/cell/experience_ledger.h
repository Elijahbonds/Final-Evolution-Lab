#pragma once

// CELL Experience Ledger — Memory
//
// An append-only, in-memory log of ExperienceRecord structs backed by a rolling
// JSONL file store in artifacts/cell/ledger/.  The in-memory ring is capped at
// max_records; oldest entries are evicted when full.  Pending writes are flushed
// to the current shard when the pending buffer exceeds flush_threshold entries.
//
// Zero-copy analysis ring (P5):
//   When use_zero_copy_ring is true (default), a parallel mmap-backed circular
//   buffer of ExperienceRecordPOD structs is maintained alongside m_records.
//   The game thread writes both paths; the ResearchLoop reads from the POD ring
//   via queryRecentPOD() — a single contiguous memcpy instead of per-record
//   heap allocations, eliminating ~1000 × ~200-byte copies per analysis cycle.

#include "nexus/core/result.h"

#include <atomic>
#include <cstdint>
#include <functional>
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

// ── Zero-copy POD ring ────────────────────────────────────────────────────────

static constexpr std::size_t kSourceSystemMax = 64;
static constexpr std::size_t kContextJsonMax  = 1024;
static constexpr std::size_t kOutcomeJsonMax  = 512;

/// Fixed-layout POD record stored in the mmap-backed analysis ring.
/// Strings are null-terminated and truncated to their respective limits.
struct ExperienceRecordPOD {
  std::uint64_t timestamp_ms{0};
  char          source_system[kSourceSystemMax]{};
  char          context_json[kContextJsonMax]{};   ///< JSON serialised to string
  char          outcome_json[kOutcomeJsonMax]{};
  double        reward_signal{0.0};
};

// ── Config ────────────────────────────────────────────────────────────────────

struct ExperienceLedgerConfig {
  std::string   ledger_dir{"artifacts/cell/ledger"};
  std::size_t   max_records{100'000};
  std::size_t   flush_threshold{256}; ///< flush to disk after this many pending records
  bool          use_zero_copy_ring{true}; ///< enable mmap-backed POD ring
};

// ── Ledger ────────────────────────────────────────────────────────────────────

class ExperienceLedger {
public:
  explicit ExperienceLedger(ExperienceLedgerConfig config = {});
  ~ExperienceLedger();

  ExperienceLedger(const ExperienceLedger&)            = delete;
  ExperienceLedger& operator=(const ExperienceLedger&) = delete;

  /// Creates the ledger directory and the mmap ring if absent. Must be called
  /// before append().
  auto init() -> Result<void>;

  void append(ExperienceRecord record);

  /// Returns up to n most-recent records (newest last). Thread-safe.
  [[nodiscard]] auto queryRecent(std::size_t n) const -> std::vector<ExperienceRecord>;

  /// Returns up to max_results records where reward >= min_reward. Thread-safe.
  [[nodiscard]] auto queryByReward(double min_reward, std::size_t max_results) const
      -> std::vector<ExperienceRecord>;

  /// Zero-copy iteration over the n most-recent POD records (newest last).
  /// fn is called for each record directly from the mmap region — no heap copy.
  /// Falls back silently to a no-op if the POD ring is unavailable.
  void forEachPOD(std::size_t n,
                  const std::function<void(const ExperienceRecordPOD&)>& fn) const;

  /// Return the n most-recent POD records as a contiguous vector.
  /// Faster than queryRecent() for analysis-only paths that do not need JSON.
  [[nodiscard]] auto queryRecentPOD(std::size_t n) const -> std::vector<ExperienceRecordPOD>;

  [[nodiscard]] auto totalCount() const -> std::size_t;

  /// Force-flush any pending write-behind records to disk.
  void flush();

  void shutdown();

private:
  void flushPendingLocked();          ///< caller holds m_mutex
  [[nodiscard]] auto currentShardPath() const -> std::string;
  void appendToPODRing(const ExperienceRecord& record);
  void initPODRing();
  void destroyPODRing();

  static constexpr std::size_t kPODRingCapacity = 16384;

  ExperienceLedgerConfig     m_config;
  mutable std::mutex         m_mutex;
  std::vector<ExperienceRecord> m_records; ///< in-memory ring, capped at max_records
  std::vector<ExperienceRecord> m_pending; ///< awaiting disk flush
  std::uint32_t              m_shardIndex{0};
  std::size_t                m_pendingBytesApprox{0};

  // Zero-copy POD ring (mmap-backed on POSIX; heap-fallback otherwise)
  ExperienceRecordPOD*            m_podRing{nullptr};
  std::atomic<std::uint64_t>      m_podWriteIdx{0};
  std::size_t                     m_podRingBytes{0};
  bool                            m_podRingOwned{false}; ///< true = mmap; false = new[]
};

} // namespace nexus::cell
