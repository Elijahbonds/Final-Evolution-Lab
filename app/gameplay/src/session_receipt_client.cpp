#include "nexus/gameplay/session_receipt_client.h"

#include "nexus/core/http_client.h"
#include "nexus/core/log.h"

#include <chrono>
#include <cctype>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <optional>
#include <sstream>

namespace nexus::gameplay {

namespace {

[[nodiscard]] auto homeDirectory() -> std::string {
  if (const char* home = std::getenv("HOME")) {
    return std::string(home);
  }
  return std::filesystem::temp_directory_path().string();
}

[[nodiscard]] auto defaultQueueDirectoryPath() -> std::string {
  return (std::filesystem::path(homeDirectory()) / ".fel" / "pending_receipts").string();
}

[[nodiscard]] auto nonEmptyEnv(const char* name) -> std::optional<std::string> {
  if (const char* value = std::getenv(name)) {
    if (value[0] != '\0') {
      return std::string(value);
    }
  }
  return std::nullopt;
}

[[nodiscard]] auto envFlagValue(std::string value) -> std::optional<bool> {
  for (char& ch : value) {
    ch = static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));
  }
  if (value == "1" || value == "true" || value == "yes" || value == "on") {
    return true;
  }
  if (value == "0" || value == "false" || value == "no" || value == "off") {
    return false;
  }
  return std::nullopt;
}

[[nodiscard]] auto sanitizeFileStem(std::string stem) -> std::string {
  for (char& ch : stem) {
    if (!std::isalnum(static_cast<unsigned char>(ch)) && ch != '-' && ch != '_') {
      ch = '_';
    }
  }
  if (stem.empty()) {
    return "receipt";
  }
  return stem;
}

[[nodiscard]] auto receiptFileStem(const nlohmann::json& receipt, std::uint64_t& counter) -> std::string {
  if (receipt.contains("telemetry") && receipt.at("telemetry").contains("session_id")) {
    return sanitizeFileStem(receipt.at("telemetry").at("session_id").get<std::string>());
  }
  if (receipt.contains("mode_id")) {
    std::ostringstream stream;
    stream << sanitizeFileStem(receipt.at("mode_id").get<std::string>()) << "_" << ++counter;
    return stream.str();
  }
  return "receipt_" + std::to_string(++counter);
}

[[nodiscard]] auto resolvePostUrl(const SessionReceiptClientConfig& config) -> std::string {
  if (const auto envUrl = nonEmptyEnv("NEXUS_RECEIPT_URL")) {
    return *envUrl;
  }
  if (!config.baseUrl.empty()) {
    return config.baseUrl;
  }
  return "http://127.0.0.1:8000/api/games/session";
}

[[nodiscard]] auto resolveStubTransportEnabled(const SessionReceiptClientConfig& config) -> bool {
  for (const char* envName :
       {"NEXUS_RECEIPT_USE_STUB_HTTP_TRANSPORT", "NEXUS_RECEIPT_USE_STUB"}) {
    if (const auto overrideValue = nonEmptyEnv(envName)) {
      if (const auto parsed = envFlagValue(*overrideValue)) {
        return *parsed;
      }
    }
  }

  // A live receipt URL is an explicit production signal. Do not let the default
  // test stub convert an unreachable/non-2xx backend into a fake delivery.
  if (nonEmptyEnv("NEXUS_RECEIPT_URL")) {
    return false;
  }

  return config.useStubHttpTransport;
}

[[nodiscard]] auto normalizeConfig(SessionReceiptClientConfig config) -> SessionReceiptClientConfig {
  if (config.queueDirectory.empty()) {
    config.queueDirectory = defaultQueueDirectoryPath();
  }
  config.useStubHttpTransport = resolveStubTransportEnabled(config);
  return config;
}

} // namespace

auto SessionReceiptClient::defaultQueueDirectory() -> std::string {
  return defaultQueueDirectoryPath();
}

SessionReceiptClient::SessionReceiptClient(SessionReceiptClientConfig config)
    : m_config(normalizeConfig(std::move(config))),
      m_http(nexus::core::HttpClientConfig{
          .url = resolvePostUrl(m_config),
          .authToken = m_config.authToken,
          .useStubTransport = m_config.useStubHttpTransport,
      }) {}

void SessionReceiptClient::setConfig(SessionReceiptClientConfig config) {
  m_config = normalizeConfig(std::move(config));
  m_http.setUrl(resolvePostUrl(m_config));
  m_http.setAuthToken(m_config.authToken);
  m_http.setStubTransportEnabled(m_config.useStubHttpTransport);
}

void SessionReceiptClient::enqueue(nlohmann::json receipt) {
  m_pending.push_back(std::move(receipt));
  m_retryCounts.push_back(0);
}

auto SessionReceiptClient::flush() -> SessionReceiptDispatchResult {
  SessionReceiptDispatchResult result;
  if (m_pending.empty()) {
    return result;
  }

  std::vector<nlohmann::json> remaining;
  std::vector<std::size_t> remainingRetries;
  remaining.reserve(m_pending.size());
  remainingRetries.reserve(m_retryCounts.size());

  for (std::size_t index = 0; index < m_pending.size(); ++index) {
    nlohmann::json& receipt = m_pending[index];
    std::size_t retries = m_retryCounts[index];
    ++result.attempted;

    const auto delivery = deliverReceipt(receipt);
    if (delivery.isOk()) {
      ++result.delivered;
      ++result.queued_on_disk;
      continue;
    }

    ++retries;
    if (retries < m_config.maxRetries) {
      ++result.requeued;
      remaining.push_back(std::move(receipt));
      remainingRetries.push_back(retries);
      if (m_config.persistToDisk) {
        (void)persistReceipt(remaining.back());
      }
    } else {
      NEXUS_LOG_WARN(nexus::LogChannel::kAI,
                     "Session receipt dropped after max retries: " + delivery.error());
    }
  }

  m_pending = std::move(remaining);
  m_retryCounts = std::move(remainingRetries);
  return result;
}

void SessionReceiptClient::tick(double deltaSeconds) {
  if (m_pending.empty()) {
    return;
  }
  m_secondsSinceFlush += deltaSeconds;
  if (m_secondsSinceFlush < m_config.flushIntervalSeconds) {
    return;
  }
  m_secondsSinceFlush = 0.0;
  (void)flush();
}

auto SessionReceiptClient::pendingCount() const -> std::size_t {
  return m_pending.size();
}

auto SessionReceiptClient::pendingReceipts() const -> std::span<const nlohmann::json> {
  return m_pending;
}

auto SessionReceiptClient::postedRequests() const -> std::span<const nexus::core::HttpPostRecord> {
  return m_http.postedRequests();
}

auto SessionReceiptClient::queueDirectory() const -> const std::string& {
  return m_config.queueDirectory;
}

auto SessionReceiptClient::config() const -> const SessionReceiptClientConfig& {
  return m_config;
}

void SessionReceiptClient::clearPending() {
  m_pending.clear();
  m_retryCounts.clear();
}

auto SessionReceiptClient::ensureQueueDirectory() const -> Result<void> {
  std::error_code ec;
  std::filesystem::create_directories(m_config.queueDirectory, ec);
  if (ec) {
    return Result<void>::err("failed to create receipt queue directory");
  }
  return Result<void>::ok();
}

auto SessionReceiptClient::persistReceipt(const nlohmann::json& receipt) -> std::optional<std::string> {
  if (const auto ready = ensureQueueDirectory(); ready.isErr()) {
    return std::nullopt;
  }

  const std::string stem = receiptFileStem(receipt, m_receiptCounter);
  const auto path = std::filesystem::path(m_config.queueDirectory) / (stem + ".json");
  std::ofstream output(path, std::ios::trunc);
  if (!output.is_open()) {
    return std::nullopt;
  }
  output << receipt.dump(2);
  if (!output.good()) {
    return std::nullopt;
  }
  output.close();
  return path.string();
}

auto SessionReceiptClient::deliverReceipt(const nlohmann::json& receipt) -> Result<int> {
  const std::string modeId = receipt.value("mode_id", std::string("unknown"));
  const int score = receipt.value("score", 0);
  int deliveredStatus = 200;

  if (m_config.persistToDisk) {
    if (const auto path = persistReceipt(receipt)) {
      NEXUS_LOG_INFO(nexus::LogChannel::kAI,
                     "Session receipt persisted for iOS/SessionService pickup path=" + *path);
    } else {
      return Result<int>::err("failed to persist receipt");
    }
  }

  if (m_config.httpEnabled) {
    m_http.setUrl(resolvePostUrl(m_config));
    const auto postResult = m_http.post(receipt.dump());
    if (postResult.isErr()) {
      return postResult;
    }
    const int statusCode = postResult.value();
    deliveredStatus = statusCode;
    NEXUS_LOG_INFO(nexus::LogChannel::kAI,
                   "Session receipt POST mode=" + modeId + " score=" + std::to_string(score) +
                       " status=" + std::to_string(statusCode));
    if (statusCode < 200 || statusCode >= 300) {
      return Result<int>::err("session POST rejected with status " + std::to_string(statusCode));
    }
  } else {
    NEXUS_LOG_INFO(nexus::LogChannel::kAI,
                   "Session receipt flush (HTTP disabled) mode=" + modeId +
                       " score=" + std::to_string(score));
  }

  return Result<int>::ok(deliveredStatus);
}

} // namespace nexus::gameplay
