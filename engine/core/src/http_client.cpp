#include "nexus/core/http_client.h"

#include "nexus/core/log.h"

#include <array>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <string>
#include <unistd.h>

namespace nexus::core {

namespace {

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

[[nodiscard]] auto writeTempPayload(std::string_view jsonBody) -> Result<std::filesystem::path> {
  std::string pathTemplate =
      (std::filesystem::temp_directory_path() / "nexus_receipt_payload_XXXXXX").string();
  pathTemplate.push_back('\0');

  const int fd = mkstemp(pathTemplate.data());
  if (fd == -1) {
    return Result<std::filesystem::path>::err("failed to create temp receipt payload");
  }
  close(fd);

  const std::filesystem::path payloadPath{pathTemplate.c_str()};
  std::ofstream output(payloadPath, std::ios::binary | std::ios::trunc);
  if (!output.is_open()) {
    std::error_code ec;
    std::filesystem::remove(payloadPath, ec);
    return Result<std::filesystem::path>::err("failed to open temp receipt payload");
  }
  output.write(jsonBody.data(), static_cast<std::streamsize>(jsonBody.size()));
  output.close();
  if (!output.good()) {
    std::error_code ec;
    std::filesystem::remove(payloadPath, ec);
    return Result<std::filesystem::path>::err("failed to write temp receipt payload");
  }

  return Result<std::filesystem::path>::ok(payloadPath);
}

[[nodiscard]] auto parseHttpStatus(const std::string& curlOutput) -> int {
  std::string digits;
  for (const char ch : curlOutput) {
    if (ch >= '0' && ch <= '9') {
      digits += ch;
    }
  }
  if (digits.empty()) {
    return 0;
  }
  return std::atoi(digits.c_str());
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
    const int statusCode = m_config.stubStatusCode;
    m_posted.push_back({url, std::string(jsonBody), statusCode});
    NEXUS_LOG_INFO(LogChannel::kAI,
                   "HTTP stub POST url=" + url + " bytes=" +
                       std::to_string(jsonBody.size()) +
                       " status=" + std::to_string(statusCode));
    return Result<int>::ok(statusCode);
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

void HttpClient::setStubStatusCode(int statusCode) {
  m_config.stubStatusCode = statusCode;
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

  auto payloadResult = writeTempPayload(jsonBody);
  if (payloadResult.isErr()) {
    return Result<int>::err(payloadResult.error());
  }
  const auto payloadPath = payloadResult.value();

  std::ostringstream curlCmd;
  curlCmd << "curl -sS -o /dev/null -w '%{http_code}' -X POST";
  curlCmd << " -H " << shellQuote("Content-Type: application/json");
  if (!m_config.authToken.empty()) {
    curlCmd << " -H " << shellQuote("Authorization: Bearer " + m_config.authToken);
  }
  curlCmd << " -H " << shellQuote("X-FEL-Client: ios");
  curlCmd << " -H " << shellQuote("User-Agent: fel-ios/1.0 (NEXUS)");
  curlCmd << " --data-binary @" << shellQuote(payloadPath.string());
  curlCmd << " " << shellQuote(url);

  FILE* pipe = popen(curlCmd.str().c_str(), "r");
  if (pipe == nullptr) {
    std::error_code ec;
    std::filesystem::remove(payloadPath, ec);
    return Result<int>::err("failed to spawn curl for session POST");
  }

  std::string curlOutput;
  std::array<char, 64> buffer{};
  while (std::fgets(buffer.data(), static_cast<int>(buffer.size()), pipe) != nullptr) {
    curlOutput += buffer.data();
  }
  const int closeStatus = pclose(pipe);
  std::error_code ec;
  std::filesystem::remove(payloadPath, ec);

  const int statusCode = parseHttpStatus(curlOutput);
  m_posted.push_back({url, std::string(jsonBody), statusCode});

  if (closeStatus != 0) {
    NEXUS_LOG_WARN(LogChannel::kAI,
                   "Session POST curl exit=" + std::to_string(closeStatus) + " url=" + url);
    return Result<int>::err("curl POST failed with exit " + std::to_string(closeStatus));
  }
  if (statusCode == 0) {
    NEXUS_LOG_WARN(LogChannel::kAI, "Session POST did not report an HTTP status url=" + url);
    return Result<int>::err("curl POST did not report an HTTP status");
  }

  NEXUS_LOG_INFO(LogChannel::kAI,
                 "Session POST completed url=" + url +
                     " status=" + std::to_string(statusCode));
  return Result<int>::ok(statusCode);
}

} // namespace nexus::core
