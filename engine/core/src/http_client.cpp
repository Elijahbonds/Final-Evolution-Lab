#include "nexus/core/http_client.h"

#include "nexus/core/log.h"

#include <array>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <sstream>

namespace nexus::core {

namespace {

[[nodiscard]] auto shellSingleQuote(std::string_view value) -> std::string {
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

[[nodiscard]] auto curlBodyTempPath() -> std::filesystem::path {
  const auto timestamp =
      std::chrono::steady_clock::now().time_since_epoch().count();
  return std::filesystem::temp_directory_path() /
         ("nexus_receipt_body_" + std::to_string(timestamp) + ".json");
}

[[nodiscard]] auto parseHttpStatus(const std::string& output) -> Result<int> {
  std::string digits;
  for (const char ch : output) {
    if (ch >= '0' && ch <= '9') {
      digits.push_back(ch);
    }
  }
  if (digits.empty()) {
    return Result<int>::err("curl did not report an HTTP status code");
  }
  return Result<int>::ok(std::stoi(digits));
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

  const auto bodyPath = curlBodyTempPath();
  {
    std::ofstream body(bodyPath, std::ios::binary | std::ios::trunc);
    if (!body.is_open()) {
      return Result<int>::err("failed to create curl session POST body");
    }
    body.write(jsonBody.data(), static_cast<std::streamsize>(jsonBody.size()));
    if (!body.good()) {
      std::error_code removeError;
      std::filesystem::remove(bodyPath, removeError);
      return Result<int>::err("failed to write curl session POST body");
    }
  }

  std::ostringstream curlCmd;
  curlCmd << "curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json'";
  if (!m_config.authToken.empty()) {
    curlCmd << " -H " << shellSingleQuote("Authorization: Bearer " + m_config.authToken);
  }
  curlCmd << " -H 'X-FEL-Client: ios' -H 'User-Agent: fel-ios/1.0 (NEXUS)'";
  curlCmd << " --data-binary @" << shellSingleQuote(bodyPath.string()) << " " << shellSingleQuote(url);

  FILE* pipe = popen(curlCmd.str().c_str(), "r");
  if (pipe == nullptr) {
    std::error_code removeError;
    std::filesystem::remove(bodyPath, removeError);
    return Result<int>::err("failed to spawn curl for session POST");
  }

  std::string statusOutput;
  std::array<char, 64> buffer{};
  while (std::fgets(buffer.data(), static_cast<int>(buffer.size()), pipe) != nullptr) {
    statusOutput += buffer.data();
  }
  const int closeStatus = pclose(pipe);
  std::error_code removeError;
  std::filesystem::remove(bodyPath, removeError);

  const auto parsedStatus = parseHttpStatus(statusOutput);
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

  NEXUS_LOG_INFO(LogChannel::kAI,
                 "Session POST completed url=" + url + " status=" + std::to_string(statusCode));
  return Result<int>::ok(statusCode);
}

} // namespace nexus::core
