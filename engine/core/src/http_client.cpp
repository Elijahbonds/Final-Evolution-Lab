#include "nexus/core/http_client.h"

#include "nexus/core/log.h"

#include <array>
#include <chrono>
#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <optional>
#include <sstream>
#include <string>
#include <system_error>

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

[[nodiscard]] auto makeTempBodyPath() -> std::filesystem::path {
  const auto now = std::chrono::steady_clock::now().time_since_epoch().count();
  return std::filesystem::temp_directory_path() /
         ("nexus_http_post_" + std::to_string(now) + ".json");
}

[[nodiscard]] auto writeTempBody(std::string_view jsonBody) -> std::optional<std::filesystem::path> {
  const auto bodyPath = makeTempBodyPath();
  std::ofstream output(bodyPath, std::ios::binary | std::ios::trunc);
  if (!output.is_open()) {
    return std::nullopt;
  }
  output.write(jsonBody.data(), static_cast<std::streamsize>(jsonBody.size()));
  output.close();
  if (!output.good()) {
    std::error_code ec;
    std::filesystem::remove(bodyPath, ec);
    return std::nullopt;
  }
  return bodyPath;
}

[[nodiscard]] auto parseHttpStatus(std::string output) -> int {
  while (!output.empty() && std::isspace(static_cast<unsigned char>(output.back()))) {
    output.pop_back();
  }
  std::string digits;
  for (auto it = output.rbegin(); it != output.rend() && std::isdigit(static_cast<unsigned char>(*it));
       ++it) {
    digits.insert(digits.begin(), *it);
  }
  if (digits.empty()) {
    return 0;
  }
  return std::stoi(digits);
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

  const auto bodyPath = writeTempBody(jsonBody);
  if (!bodyPath.has_value()) {
    return Result<int>::err("failed to write temporary session POST body");
  }

  std::ostringstream curlCmd;
  curlCmd << "curl --silent --show-error --output /dev/null --write-out '%{http_code}' "
          << "--request POST --header " << shellQuote("Content-Type: application/json");
  if (!m_config.authToken.empty()) {
    curlCmd << " --header " << shellQuote("Authorization: Bearer " + m_config.authToken);
  }
  curlCmd << " --header " << shellQuote("X-FEL-Client: ios")
          << " --header " << shellQuote("User-Agent: fel-ios/1.0 (NEXUS)")
          << " --data-binary " << shellQuote("@" + bodyPath->string()) << ' '
          << shellQuote(url);

  FILE* pipe = popen(curlCmd.str().c_str(), "r");
  if (pipe == nullptr) {
    std::error_code ec;
    std::filesystem::remove(*bodyPath, ec);
    return Result<int>::err("failed to spawn curl for session POST");
  }

  std::string curlOutput;
  std::array<char, 64> buffer{};
  while (std::fgets(buffer.data(), static_cast<int>(buffer.size()), pipe) != nullptr) {
    curlOutput += buffer.data();
  }
  const int closeStatus = pclose(pipe);

  std::error_code ec;
  std::filesystem::remove(*bodyPath, ec);

  const int statusCode = parseHttpStatus(curlOutput);
  m_posted.push_back({url, std::string(jsonBody), statusCode});

  if (closeStatus != 0) {
    NEXUS_LOG_WARN(LogChannel::kAI,
                   "Session POST curl exit=" + std::to_string(closeStatus) + " url=" + url);
    return Result<int>::err("curl POST failed with exit " + std::to_string(closeStatus));
  }
  if (statusCode < 200 || statusCode >= 300) {
    NEXUS_LOG_WARN(LogChannel::kAI,
                   "Session POST rejected status=" + std::to_string(statusCode) + " url=" + url);
    return Result<int>::err("session POST returned HTTP " + std::to_string(statusCode));
  }

  NEXUS_LOG_INFO(LogChannel::kAI,
                 "Session POST ok status=" + std::to_string(statusCode) + " url=" + url);
  return Result<int>::ok(statusCode);
}

} // namespace nexus::core
