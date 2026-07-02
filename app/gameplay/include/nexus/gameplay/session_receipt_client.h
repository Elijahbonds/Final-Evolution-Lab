// Session receipt dispatch — queue to ~/.fel/pending_receipts/ with flush retry.
#pragma once

#include "nexus/core/http_client.h"
#include "nexus/core/result.h"

#include <nlohmann/json.hpp>
#include <cstddef>
#include <optional>
#include <string>
#include <vector>

namespace nexus::gameplay {

struct SessionReceiptClientConfig {
  std::string queueDirectory;
  /// Full POST URL including path, e.g. `http://127.0.0.1:8000/api/games/session`.
  std::string baseUrl{"http://127.0.0.1:8000/api/games/session"};
  std::string authToken;
  bool persistToDisk{true};
  bool httpEnabled{true};
  bool useStubHttpTransport{true};
  float flushIntervalSeconds{5.0F};
  std::size_t maxRetries{5};
};

struct SessionReceiptDispatchResult {
  std::size_t attempted{0};
  std::size_t delivered{0};
  std::size_t requeued{0};
  std::size_t queued_on_disk{0};
};

class SessionReceiptClient {
public:
  explicit SessionReceiptClient(SessionReceiptClientConfig config = {});

  void setConfig(SessionReceiptClientConfig config);
  void enqueue(nlohmann::json receipt);
  auto flush() -> SessionReceiptDispatchResult;
  void tick(double deltaSeconds);
  [[nodiscard]] auto pendingCount() const -> std::size_t;
  [[nodiscard]] auto pendingReceipts() const -> std::span<const nlohmann::json>;
  [[nodiscard]] auto postedRequests() const -> std::span<const nexus::core::HttpPostRecord>;
  [[nodiscard]] auto config() const -> SessionReceiptClientConfig;
  [[nodiscard]] auto queueDirectory() const -> const std::string&;
  void clearPending();

private:
  [[nodiscard]] static auto defaultQueueDirectory() -> std::string;
  [[nodiscard]] auto ensureQueueDirectory() const -> Result<void>;
  [[nodiscard]] auto persistReceipt(const nlohmann::json& receipt) -> std::optional<std::string>;
  [[nodiscard]] auto deliverReceipt(const nlohmann::json& receipt) -> Result<int>;

  SessionReceiptClientConfig m_config;
  nexus::core::HttpClient m_http;
  std::vector<nlohmann::json> m_pending;
  std::vector<std::size_t> m_retryCounts;
  double m_secondsSinceFlush{0.0};
  std::uint64_t m_receiptCounter{0};
};

} // namespace nexus::gameplay
