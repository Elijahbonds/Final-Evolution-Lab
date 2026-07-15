#include "nexus/cell/batch_learner.h"
#include "nexus/core/http_client.h"
#include "nexus/core/log.h"

#include <chrono>
#include <ctime>
#include <iomanip>
#include <sstream>

namespace nexus::cell {

namespace {

auto nowIso8601() -> std::string {
  const auto now = std::chrono::system_clock::now();
  const std::time_t tt = std::chrono::system_clock::to_time_t(now);
  std::tm tmBuf{};
#if defined(_WIN32)
  gmtime_s(&tmBuf, &tt);
#else
  gmtime_r(&tt, &tmBuf);
#endif
  std::ostringstream oss;
  oss << std::put_time(&tmBuf, "%Y-%m-%dT%H:%M:%SZ");
  return oss.str();
}

} // namespace

BatchLearner::BatchLearner(ExperienceLedger& ledger, WisdomStore& store,
                            BatchLearnerConfig config)
    : m_ledger(ledger), m_store(store), m_config(std::move(config)) {}

auto BatchLearner::buildPayload(std::size_t maxRecords) const -> nlohmann::json {
  const auto records = m_ledger.readRecent(maxRecords);
  nlohmann::json requests = nlohmann::json::array();

  for (std::size_t idx = 0; idx < records.size(); ++idx) {
    const auto& rec = records[idx];
    // Build a compact prompt from the session record.
    const std::string prompt =
        "Analyze this FEL session and return a JSON object with keys: "
        "insight (string), skill_tags (array of strings), mastery_signal (0=struggling, "
        "1=progressing, 2=mastered). Session: " +
        rec.dump();

    requests.push_back({
        {"custom_id", "req_" + std::to_string(idx)},
        {"params", {
            {"model", m_config.model},
            {"max_tokens", 256},
            {"messages", nlohmann::json::array({{
                {"role", "user"},
                {"content", prompt},
            }})},
        }},
    });
  }

  return nlohmann::json{
      {"requests", requests},
      {"metadata", {
          {"submitted_at", nowIso8601()},
          {"record_count", records.size()},
      }},
  };
}

auto BatchLearner::submitBatch(const nlohmann::json& payload) -> Result<std::string> {
  nexus::core::HttpClientConfig httpConfig;
  httpConfig.url = m_config.batchApiUrl;
  httpConfig.authToken = m_config.batchApiKey;
  // Use real transport only when API key is configured.
  httpConfig.useStubTransport = m_config.batchApiKey.empty();

  nexus::core::HttpClient http(httpConfig);
  const auto result = http.post(payload.dump());
  if (result.isErr()) {
    return Result<std::string>::err("BatchLearner: POST failed: " + result.error());
  }
  NEXUS_LOG_INFO(nexus::LogChannel::kCell,
                 "[BatchLearner] Batch submitted, HTTP " +
                     std::to_string(result.value()));
  // In stub mode return a synthetic batch ID; real mode would parse the response body.
  return Result<std::string>::ok("batch_" + nowIso8601());
}

auto BatchLearner::writeInsights(const nlohmann::json& batchResponse) -> std::size_t {
  std::size_t written = 0;
  if (!batchResponse.contains("results") || !batchResponse["results"].is_array()) {
    return written;
  }
  for (const auto& item : batchResponse["results"]) {
    const std::string customId = item.value("custom_id", "");
    if (!item.contains("result")) {
      continue;
    }
    const std::string insightKey = "batch_insight:" + customId;
    m_store.set(insightKey, item["result"]);
    ++written;
  }
  return written;
}

auto BatchLearner::runNightlyBatch() -> Result<BatchResult> {
  NEXUS_LOG_INFO(nexus::LogChannel::kCell, "[BatchLearner] Starting nightly batch job.");

  if (!m_config.batchLearningEnabled) {
    NEXUS_LOG_INFO(nexus::LogChannel::kCell, "[BatchLearner] Disabled in config — skipping.");
    return Result<BatchResult>::ok(BatchResult{});
  }

  const nlohmann::json payload = buildPayload(m_config.maxRecordsPerBatch);
  const std::size_t recordCount = payload["metadata"]["record_count"].get<std::size_t>();

  if (recordCount == 0) {
    NEXUS_LOG_INFO(nexus::LogChannel::kCell, "[BatchLearner] No records to batch — done.");
    return Result<BatchResult>::ok(BatchResult{});
  }

  const auto submitResult = submitBatch(payload);
  if (submitResult.isErr()) {
    return Result<BatchResult>::err(submitResult.error());
  }

  // In production, polling for batch completion happens asynchronously.
  // Here we record the batch ID and write a placeholder insight for later pickup.
  const std::string batchId = submitResult.value();
  m_store.set("batch:pending:" + batchId, payload["metadata"]);

  const auto saveResult = m_store.save();
  if (saveResult.isErr()) {
    NEXUS_LOG_WARN(nexus::LogChannel::kCell,
                   "[BatchLearner] WisdomStore save failed: " + saveResult.error());
  }

  NEXUS_LOG_INFO(nexus::LogChannel::kCell,
                 "[BatchLearner] Batch submitted: id=" + batchId +
                     " records=" + std::to_string(recordCount));

  return Result<BatchResult>::ok(BatchResult{
      .recordsSubmitted = recordCount,
      .insightsWritten = 0,
      .batchId = batchId,
      .submitted = true,
  });
}

} // namespace nexus::cell
