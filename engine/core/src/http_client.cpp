#include "nexus/core/http_client.h"

#include "nexus/core/log.h"

#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <optional>
#include <sstream>

namespace nexus::core {

namespace {

[[nodiscard]] auto isSuccessStatus(int statusCode) -> bool {
  return statusCode >= 200 && statusCode < 300;
}

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

[[nodiscard]] auto makeCurlTempPath(std::string_view label) -> std::filesystem::path {
  static std::atomic_uint64_t counter{0};
  const auto stamp = std::chrono::steady_clock::now().time_since_epoch().count();
  std::ostringstream name;
  name << "nexus_http_" << label << "_" << stamp << "_" << counter.fetch_add(1);
  return std::filesystem::temp_directory_path() / name.str();
}

[[nodiscard]] auto parseStatusCode(const std::filesystem::path& statusPath) -> std::optional<int> {
  std::ifstream input(statusPath);
  std::string statusText;
  input >> statusText;
  if (statusText.size() < 3) {
    return std::nullopt;
  }
  try {
    return std::stoi(statusText.substr(0, 3));
  } catch (...) {
    return std::nullopt;
  }
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
                   "HTTP stub POST url=" + url + " bytes=" + std::to_string(jsonBody.size()) +
                       " status=" + std::to_string(statusCode));
    if (!isSuccessStatus(statusCode)) {
      return Result<int>::err("HTTP stub POST returned status " + std::to_string(statusCode));
    }
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

  const auto bodyPath = makeCurlTempPath("body");
  const auto statusPath = makeCurlTempPath("status");
  auto cleanup = [&]() {
    std::error_code ec;
    std::filesystem::remove(bodyPath, ec);
    std::filesystem::remove(statusPath, ec);
  };

  {
    std::ofstream bodyFile(bodyPath, std::ios::binary | std::ios::trunc);
    if (!bodyFile.is_open()) {
      cleanup();
      return Result<int>::err("failed to stage session POST body");
    }
    bodyFile.write(jsonBody.data(), static_cast<std::streamsize>(jsonBody.size()));
    if (!bodyFile.good()) {
      cleanup();
      return Result<int>::err("failed to write session POST body");
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

  const int curlExit = std::system(curlCmd.str().c_str());
  const auto parsedStatus = parseStatusCode(statusPath);
  const int statusCode = parsedStatus.value_or(0);
  cleanup();

  m_posted.push_back({url, std::string(jsonBody), statusCode});

  if (curlExit != 0) {
    NEXUS_LOG_WARN(LogChannel::kAI,
                   "Session POST curl exit=" + std::to_string(curlExit) + " url=" + url);
    return Result<int>::err("curl POST failed with exit " + std::to_string(curlExit));
  }

  if (!parsedStatus.has_value()) {
    NEXUS_LOG_WARN(LogChannel::kAI, "Session POST curl returned no HTTP status url=" + url);
    return Result<int>::err("curl POST returned no HTTP status");
  }

  if (!isSuccessStatus(statusCode)) {
    NEXUS_LOG_WARN(LogChannel::kAI,
                   "Session POST rejected status=" + std::to_string(statusCode) + " url=" + url);
    return Result<int>::err("HTTP POST returned status " + std::to_string(statusCode));
  }

  NEXUS_LOG_INFO(LogChannel::kAI,
                 "Session POST ok status=" + std::to_string(statusCode) + " url=" + url);
  return Result<int>::ok(statusCode);
}

} // namespace nexus::core
