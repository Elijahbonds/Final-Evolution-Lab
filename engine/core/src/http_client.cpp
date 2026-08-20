#include "nexus/core/http_client.h"

#include "nexus/core/log.h"

#include <atomic>
#include <chrono>
#include <cctype>
#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <optional>
#include <sstream>

namespace nexus::core {

namespace {

std::atomic_uint64_t g_tempFileCounter{0};

[[nodiscard]] auto shellQuote(std::string_view value) -> std::string {
  std::string quoted{"'"};
  for (const char ch : value) {
    if (ch == '\'') {
      quoted += "'\\''";
    } else {
      quoted += ch;
    }
  }
  quoted += "'";
  return quoted;
}

[[nodiscard]] auto makeTempPath(std::string_view stem) -> std::filesystem::path {
  const auto now = std::chrono::steady_clock::now().time_since_epoch().count();
  const auto counter = g_tempFileCounter.fetch_add(1, std::memory_order_relaxed);
  return std::filesystem::temp_directory_path() /
         (std::string(stem) + "_" + std::to_string(now) + "_" + std::to_string(counter) + ".tmp");
}

[[nodiscard]] auto parseHttpStatus(std::string_view text) -> std::optional<int> {
  std::size_t index = 0;
  while (index < text.size() &&
         std::isspace(static_cast<unsigned char>(text[index])) != 0) {
    ++index;
  }

  int status = 0;
  int digits = 0;
  while (index < text.size() && std::isdigit(static_cast<unsigned char>(text[index])) != 0) {
    status = status * 10 + (text[index] - '0');
    ++index;
    ++digits;
  }

  if (digits == 0) {
    return std::nullopt;
  }
  return status;
}

} // namespace

HttpClient::HttpClient(HttpClientConfig config) : m_config(std::move(config)) {}

auto HttpClient::post(std::string_view jsonBody) -> Result<int> {
  std::string url = m_config.url;
  if (const char* envUrl = std::getenv("NEXUS_RECEIPT_URL")) {
    if (envUrl[0] != '\0') {
      url = envUrl;
    }
  }

  if (m_config.useStubTransport) {
    m_posted.push_back({url, std::string(jsonBody), 200});
    NEXUS_LOG_INFO(LogChannel::kAI,
                   "HTTP stub POST url=" + url + " bytes=" + std::to_string(jsonBody.size()));
    return Result<int>::ok(200);
  }

  return postViaCurl(jsonBody);
}

void HttpClient::setUrl(std::string url) {
  m_config.url = std::move(url);
}

void HttpClient::setAuthToken(std::string token) {
  m_config.authToken = std::move(token);
}

void HttpClient::setStubTransportEnabled(bool enabled) {
  m_config.useStubTransport = enabled;
}

auto HttpClient::configuredUrl() const -> std::string_view {
  return m_config.url;
}

auto HttpClient::postedRequests() const -> std::span<const HttpPostRecord> {
  return m_posted;
}

void HttpClient::clearPostedRequests() {
  m_posted.clear();
}

auto HttpClient::postViaCurl(std::string_view jsonBody) -> Result<int> {
  std::string url = m_config.url;
  if (const char* envUrl = std::getenv("NEXUS_RECEIPT_URL")) {
    if (envUrl[0] != '\0') {
      url = envUrl;
    }
  }

  const auto bodyPath = makeTempPath("nexus_receipt_body");
  const auto statusPath = makeTempPath("nexus_receipt_status");
  const auto cleanup = [&]() {
    std::error_code ec;
    std::filesystem::remove(bodyPath, ec);
    std::filesystem::remove(statusPath, ec);
  };

  {
    std::ofstream bodyFile(bodyPath, std::ios::binary | std::ios::trunc);
    if (!bodyFile.is_open()) {
      cleanup();
      return Result<int>::err("failed to create curl request body file");
    }
    bodyFile.write(jsonBody.data(), static_cast<std::streamsize>(jsonBody.size()));
    if (!bodyFile.good()) {
      cleanup();
      return Result<int>::err("failed to write curl request body file");
    }
  }

  std::ostringstream curlCmd;
  curlCmd << "curl -sS -o /dev/null -w '%{http_code}' -X POST";
  curlCmd << " -H " << shellQuote("Content-Type: application/json");
  if (!m_config.authToken.empty()) {
    curlCmd << " -H " << shellQuote("Authorization: Bearer " + m_config.authToken);
  }
  curlCmd << " -H " << shellQuote("X-FEL-Client: ios");
  curlCmd << " -H " << shellQuote("User-Agent: fel-ios/1.0 (NEXUS)");
  curlCmd << " --data-binary @" << shellQuote(bodyPath.string()) << " " << shellQuote(url);
  curlCmd << " > " << shellQuote(statusPath.string());

  const int closeStatus = std::system(curlCmd.str().c_str());
  std::ifstream statusFile(statusPath);
  std::string statusText;
  if (statusFile.is_open()) {
    statusFile >> statusText;
  }

  const auto parsedStatus = parseHttpStatus(statusText);
  const int statusCode = parsedStatus.value_or(0);
  cleanup();

  m_posted.push_back({url, std::string(jsonBody), statusCode});

  if (closeStatus != 0) {
    NEXUS_LOG_WARN(LogChannel::kAI,
                   "Session POST curl exit=" + std::to_string(closeStatus) + " url=" + url);
    return Result<int>::err("curl POST failed with exit " + std::to_string(closeStatus));
  }
  if (!parsedStatus.has_value()) {
    return Result<int>::err("curl POST did not report an HTTP status");
  }

  NEXUS_LOG_INFO(LogChannel::kAI,
                 "Session POST completed url=" + url + " status=" + std::to_string(statusCode));
  return Result<int>::ok(statusCode);
}

} // namespace nexus::core
