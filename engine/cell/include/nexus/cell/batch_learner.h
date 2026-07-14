// CELL BatchLearner — nightly offline batch job replacing always-on learning loops.
// Reads telemetry from ExperienceLedger, sends to a cheap batch API endpoint,
// and writes insights back to WisdomStore.  Zero runtime LLM cost between batches.
#pragma once

#include "nexus/cell/cell_config.h"
#include "nexus/cell/experience_ledger.h"
#include "nexus/cell/wisdom_store.h"
#include "nexus/core/result.h"

#include <nlohmann/json.hpp>
#include <cstddef>
#include <string>
#include <vector>

namespace nexus::cell {

struct BatchResult {
  std::size_t recordsSubmitted{0};
  std::size_t insightsWritten{0};
  std::string batchId;
  bool submitted{false};
};

/// Assembles a JSONL batch payload from recent ledger records, POSTs to the
/// configured batch API endpoint (Anthropic Messages Batches or OpenAI Batch),
/// and writes the resulting insights back to WisdomStore.
///
/// Call runNightlyBatch() once per day from SelfImprovementScheduler.
/// Always check BudgetMeter before calling — this class does NOT check it
/// internally so the scheduler can deduct `batch_learner` tokens up front.
class BatchLearner {
public:
  BatchLearner(ExperienceLedger& ledger, WisdomStore& store,
               BatchLearnerConfig config = {});

  /// Run the nightly batch: read ledger → assemble payload → POST → write insights.
  auto runNightlyBatch() -> Result<BatchResult>;

  /// Build the raw batch payload (for testing / dry-run inspection).
  [[nodiscard]] auto buildPayload(std::size_t maxRecords) const -> nlohmann::json;

  [[nodiscard]] auto config() const -> const BatchLearnerConfig& { return m_config; }

private:
  auto submitBatch(const nlohmann::json& payload) -> Result<std::string>;
  auto writeInsights(const nlohmann::json& batchResponse) -> std::size_t;

  ExperienceLedger& m_ledger;
  WisdomStore& m_store;
  BatchLearnerConfig m_config;
};

} // namespace nexus::cell
