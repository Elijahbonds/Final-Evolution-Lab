#include "nexus/core/http_client.h"

#include "nexus/core/log.h"

#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <string>
#include <thread>

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

[[nodiscard]] auto tempPath(std::string_view label) -> std::filesystem::path {
  const auto stamp = std::chrono::steady_clock::now().time_since_epoch().count();
  std::ostringstream name;
  name << "nexus_http_" << label << "_" << std::this_thread::get_id() << "_" << stamp;
  return std::filesystem::temp_directory_path() / name.str();
}

[[nodiscard]] auto parseStatusCode(const std::filesystem::path& path) -> int {
  std::ifstream input(path);
  std::string text;
  input >> text;
  if (text.empty()) {
    return 0;
  }
  int statusCode = 0;
  for (const char ch : text) {
    if (ch < '0' || ch > '9') {
      return 0;
    }
    statusCode = (statusCode * 10) + (ch - '0');
  }
  return statusCode;
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

  const auto bodyPath = tempPath("body.json");
  const auto statusPath = tempPath("status.txt");
  {
    std::ofstream body(bodyPath, std::ios::binary | std::ios::trunc);
    if (!body.is_open()) {
      return Result<int>::err("failed to create curl request body");
    }
    body.write(jsonBody.data(), static_cast<std::streamsize>(jsonBody.size()));
    if (!body.good()) {
      std::error_code cleanupEc;
      std::filesystem::remove(bodyPath, cleanupEc);
      return Result<int>::err("failed to write curl request body");
    }
  }

  std::ostringstream curlCmd;
  curlCmd << "curl -sS -o /dev/null -w '%{http_code}' -X POST "
          << "-H 'Content-Type: application/json'";
  if (!m_config.authToken.empty()) {
    curlCmd << " -H " << shellQuote("Authorization: Bearer " + m_config.authToken);
  }
  curlCmd << " -H 'X-FEL-Client: ios' -H 'User-Agent: fel-ios/1.0 (NEXUS)'";
  curlCmd << " --data-binary @" << shellQuote(bodyPath.string()) << " " << shellQuote(url)
          << " > " << shellQuote(statusPath.string());

  const int closeStatus = std::system(curlCmd.str().c_str());
  const int statusCode = parseStatusCode(statusPath);
  std::error_code cleanupEc;
  std::filesystem::remove(bodyPath, cleanupEc);
  std::filesystem::remove(statusPath, cleanupEc);
  m_posted.push_back({url, std::string(jsonBody), statusCode});

  if (closeStatus != 0 || statusCode == 0) {
    NEXUS_LOG_WARN(LogChannel::kAI,
                   "Session POST curl exit=" + std::to_string(closeStatus) +
                       " status=" + std::to_string(statusCode) + " url=" + url);
    return Result<int>::err("curl POST failed with exit " + std::to_string(closeStatus));
  }

  NEXUS_LOG_INFO(LogChannel::kAI,
                 "Session POST completed status=" + std::to_string(statusCode) + " url=" + url);
  return Result<int>::ok(statusCode);
}

} // namespace nexus::core
