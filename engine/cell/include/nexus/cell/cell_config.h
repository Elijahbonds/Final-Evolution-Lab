// CELL — compile-time + runtime configuration.
// CELL_ONLINE_LEARNING=OFF (default): always-on loops are gated; only nightly batch runs.
#pragma once

#include <cstdint>
#include <string>
#include <unordered_map>

// Compile-time gate.  Set CELL_ONLINE_LEARNING=1 to re-enable continuous loops.
#ifndef CELL_ONLINE_LEARNING
#  define CELL_ONLINE_LEARNING 0
#endif

namespace nexus::cell {

struct BatchLearnerConfig {
  /// Batch API endpoint (Anthropic/OpenAI batch URL).
  std::string batchApiUrl{"https://api.anthropic.com/v1/messages/batches"};
  std::string batchApiKey;
  /// Model to use for nightly batch jobs (cheap tier by default).
  std::string model{"claude-haiku-4-5"};
  /// Maximum ledger records to include in a single batch.
  std::size_t maxRecordsPerBatch{500};
  /// Directory for JSONL ledger files.
  std::string ledgerDirectory{"artifacts/cell-ledger"};
  /// Set to false to disable the nightly batch learner entirely.
  bool batchLearningEnabled{true};
};

struct BudgetConfig {
  /// Per-subsystem daily token cap.  Key = subsystem name, value = max tokens/day.
  std::unordered_map<std::string, int64_t> maxTokensPerDay{
      {"research_loop", 10000},
      {"agent_swarm", 20000},
      {"web_auditor", 5000},
      {"batch_learner", 100000},
      {"escalation", 50000},
  };
  /// Directory where budget overage logs are written.
  std::string logDirectory{"artifacts/cell-budget-log"};
};

struct BktParams {
  float pL0{0.10F};   ///< Initial probability of mastery.
  float pT{0.10F};    ///< Probability of learning (transit to mastery).
  float pS{0.10F};    ///< Probability of slip (error despite mastery).
  float pG{0.20F};    ///< Probability of guess (correct despite non-mastery).
};

struct MasteryConfig {
  BktParams bkt;
  /// WisdomStore key prefix for mastery records.
  std::string storePrefix{"mastery"};
  /// Mastery threshold above which a skill is considered learned.
  float masteryThreshold{0.95F};
};

struct WisdomStoreConfig {
  std::string storeFile{"artifacts/cell-wisdom/wisdom.json"};
};

struct CellConfig {
  WisdomStoreConfig wisdomStore;
  BudgetConfig budget;
  BatchLearnerConfig batchLearner;
  MasteryConfig mastery;
  bool batchLearningEnabled{true};
};

} // namespace nexus::cell
