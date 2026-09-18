#include "nexus/core/http_client.h"

#include "nexus/core/log.h"

#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <string_view>

namespace nexus::core {

namespace {

[[nodiscard]] auto shellQuote(std::string_view value) -> std::string {
  std::string quoted{"'"};
  for (const char ch : value) {
    if (ch == '\'') {
      quoted += "'\\''";
    } else {
      quoted.push_back(ch);
    }
  }
  quoted.push_back('\'');
  return quoted;
}

[[nodiscard]] auto writeTempPayload(std::string_view jsonBody) -> Result<std::string> {
  const auto stamp = std::chrono::steady_clock::now().time_since_epoch().count();
  const auto path = std::filesystem::temp_directory_path() /
                    ("fel_http_post_" + std::to_string(stamp) + ".json");

  std::ofstream output(path, std::ios::binary | std::ios::trunc);
  if (!output.is_open()) {
    return Result<std::string>::err("failed to create curl payload file");
  }
  output.write(jsonBody.data(), static_cast<std::streamsize>(jsonBody.size()));
  output.close();
  if (!output.good()) {
    std::error_code ec;
    std::filesystem::remove(path, ec);
    return Result<std::string>::err("failed to write curl payload file");
  }
  return Result<std::string>::ok(path.string());
}

[[nodiscard]] auto parseCurlStatus(std::string_view output) -> Result<int> {
  std::string digits;
  digits.reserve(output.size());
  for (const char ch : output) {
    if (ch >= '0' && ch <= '9') {
      digits.push_back(ch);
    }
  }
  if (digits.size() < 3) {
    return Result<int>::err("curl did not return an HTTP status code");
  }
  const std::string status = digits.substr(digits.size() - 3);
  return Result<int>::ok(std::stoi(status));
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

  const auto payloadPath = writeTempPayload(jsonBody);
  if (payloadPath.isErr()) {
    return Result<int>::err(payloadPath.error());
  }

  std::ostringstream curlCmd;
  curlCmd << "curl -sS -o /dev/null -w '%{http_code}' -X POST";
  curlCmd << " -H " << shellQuote("Content-Type: application/json");
  if (!m_config.authToken.empty()) {
    curlCmd << " -H " << shellQuote("Authorization: Bearer " + m_config.authToken);
  }
  curlCmd << " -H " << shellQuote("X-FEL-Client: ios");
  curlCmd << " -H " << shellQuote("User-Agent: fel-ios/1.0 (NEXUS)");
  curlCmd << " --data-binary @" << shellQuote(payloadPath.value());
  curlCmd << " " << shellQuote(url);

  FILE* pipe = popen(curlCmd.str().c_str(), "r");
  if (pipe == nullptr) {
    std::error_code ec;
    std::filesystem::remove(payloadPath.value(), ec);
    return Result<int>::err("failed to spawn curl for session POST");
  }
  std::string statusOutput;
  char buffer[64];
  while (std::fgets(buffer, sizeof(buffer), pipe) != nullptr) {
    statusOutput += buffer;
  }
  const int closeStatus = pclose(pipe);
  std::error_code ec;
  std::filesystem::remove(payloadPath.value(), ec);

  const auto parsedStatus = parseCurlStatus(statusOutput);
  const int statusCode = parsedStatus.isOk() ? parsedStatus.value() : 0;
  m_posted.push_back({url, std::string(jsonBody), statusCode});

  if (closeStatus != 0) {
    NEXUS_LOG_WARN(LogChannel::kAI,
                   "Session POST curl exit=" + std::to_string(closeStatus) + " url=" + url);
    return Result<int>::err("curl POST failed with exit " + std::to_string(closeStatus));
  }
  if (parsedStatus.isErr()) {
    return Result<int>::err(parsedStatus.error());
  }

  if (statusCode < 200 || statusCode >= 300) {
    NEXUS_LOG_WARN(LogChannel::kAI,
                   "Session POST non-2xx status=" + std::to_string(statusCode) + " url=" + url);
    return Result<int>::err("HTTP POST failed with status " + std::to_string(statusCode));
  }

  NEXUS_LOG_INFO(LogChannel::kAI,
                 "Session POST ok status=" + std::to_string(statusCode) + " url=" + url);
  return Result<int>::ok(statusCode);
}

} // namespace nexus::core
