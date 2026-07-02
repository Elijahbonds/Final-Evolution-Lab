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

[[nodiscard]] auto shellQuote(const std::string& value) -> std::string {
  std::string quoted = "'";
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

[[nodiscard]] auto tempBodyPath() -> std::filesystem::path {
  const auto nonce = std::chrono::steady_clock::now().time_since_epoch().count();
  return std::filesystem::temp_directory_path() /
         ("nexus_http_body_" + std::to_string(nonce) + ".json");
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

  const auto bodyPath = tempBodyPath();
  {
    std::ofstream bodyFile(bodyPath, std::ios::trunc);
    if (!bodyFile.is_open()) {
      return Result<int>::err("failed to stage curl request body");
    }
    bodyFile << jsonBody;
    if (!bodyFile.good()) {
      std::error_code removeError;
      std::filesystem::remove(bodyPath, removeError);
      return Result<int>::err("failed to write curl request body");
    }
  }

  std::ostringstream curlCmd;
  curlCmd << "curl -s -o /dev/null -w '%{http_code}' -X POST";
  curlCmd << " -H " << shellQuote("Content-Type: application/json");
  if (!m_config.authToken.empty()) {
    curlCmd << " -H " << shellQuote("Authorization: Bearer " + m_config.authToken);
  }
  curlCmd << " -H " << shellQuote("X-FEL-Client: ios");
  curlCmd << " -H " << shellQuote("User-Agent: fel-ios/1.0 (NEXUS)");
  curlCmd << " --data-binary " << shellQuote("@" + bodyPath.string());
  curlCmd << " " << shellQuote(url);

  FILE* pipe = popen(curlCmd.str().c_str(), "r");
  if (pipe == nullptr) {
    std::error_code removeError;
    std::filesystem::remove(bodyPath, removeError);
    return Result<int>::err("failed to spawn curl for session POST");
  }

  std::array<char, 32> buffer{};
  std::string statusText;
  while (std::fgets(buffer.data(), static_cast<int>(buffer.size()), pipe) != nullptr) {
    statusText += buffer.data();
  }
  const int closeStatus = pclose(pipe);
  std::error_code removeError;
  std::filesystem::remove(bodyPath, removeError);

  int statusCode = 0;
  try {
    statusCode = std::stoi(statusText);
  } catch (...) {
    statusCode = 0;
  }
  m_posted.push_back({url, std::string(jsonBody), statusCode});

  if (closeStatus != 0) {
    NEXUS_LOG_WARN(LogChannel::kAI,
                   "Session POST curl exit=" + std::to_string(closeStatus) + " url=" + url);
    return Result<int>::err("curl POST failed with exit " + std::to_string(closeStatus));
  }

  if (statusCode == 0) {
    return Result<int>::err("curl POST did not return an HTTP status");
  }

  NEXUS_LOG_INFO(LogChannel::kAI,
                 "Session POST completed url=" + url + " status=" + std::to_string(statusCode));
  return Result<int>::ok(statusCode);
}

} // namespace nexus::core
