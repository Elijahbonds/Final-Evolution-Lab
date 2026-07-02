#include "nexus/core/http_client.h"

#include "nexus/core/log.h"

#include <atomic>
#include <charconv>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <string>
#include <string_view>
#include <system_error>

#include <unistd.h>

namespace nexus::core {

namespace {

[[nodiscard]] auto shellQuote(std::string_view value) -> std::string {
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

[[nodiscard]] auto parseHttpStatus(std::string_view output) -> int {
  while (!output.empty() &&
         (output.back() == '\n' || output.back() == '\r' || output.back() == ' ' ||
          output.back() == '\t')) {
    output.remove_suffix(1);
  }
  if (output.size() < 3) {
    return 0;
  }

  const std::string_view statusText = output.substr(output.size() - 3);
  int statusCode = 0;
  const auto* begin = statusText.data();
  const auto* end = begin + statusText.size();
  const auto parsed = std::from_chars(begin, end, statusCode);
  if (parsed.ec != std::errc{} || parsed.ptr != end) {
    return 0;
  }
  return statusCode;
}

[[nodiscard]] auto writeTempBody(std::string_view body) -> Result<std::filesystem::path> {
  static std::atomic_uint64_t counter{0};
  std::filesystem::path path =
      std::filesystem::temp_directory_path() /
      ("nexus_receipt_post_" + std::to_string(static_cast<long long>(getpid())) + "_" +
       std::to_string(counter.fetch_add(1, std::memory_order_relaxed)) + ".json");

  std::ofstream out(path, std::ios::binary | std::ios::trunc);
  if (!out) {
    return Result<std::filesystem::path>::err("failed to create temp receipt POST body");
  }
  out.write(body.data(), static_cast<std::streamsize>(body.size()));
  if (!out) {
    return Result<std::filesystem::path>::err("failed to write temp receipt POST body");
  }
  return Result<std::filesystem::path>::ok(std::move(path));
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

  auto tempBody = writeTempBody(jsonBody);
  if (tempBody.isErr()) {
    return Result<int>::err(tempBody.error());
  }

  std::ostringstream curlCmd;
  curlCmd << "curl -sS -o /dev/null -w '%{http_code}' -X POST";
  curlCmd << " -H " << shellQuote("Content-Type: application/json");
  if (!m_config.authToken.empty()) {
    curlCmd << " -H " << shellQuote("Authorization: Bearer " + m_config.authToken);
  }
  curlCmd << " -H " << shellQuote("X-FEL-Client: ios");
  curlCmd << " -H " << shellQuote("User-Agent: fel-ios/1.0 (NEXUS)");
  curlCmd << " --data-binary " << shellQuote("@" + tempBody.value().string());
  curlCmd << " " << shellQuote(url);

  FILE* pipe = popen(curlCmd.str().c_str(), "r");
  if (pipe == nullptr) {
    std::error_code ec;
    std::filesystem::remove(tempBody.value(), ec);
    return Result<int>::err("failed to spawn curl for session POST");
  }

  std::string output;
  char buffer[128];
  while (std::fgets(buffer, sizeof(buffer), pipe) != nullptr) {
    output += buffer;
  }
  const int closeStatus = pclose(pipe);
  const int statusCode = parseHttpStatus(output);

  std::error_code ec;
  std::filesystem::remove(tempBody.value(), ec);

  m_posted.push_back({url, std::string(jsonBody), statusCode});

  if (closeStatus != 0) {
    NEXUS_LOG_WARN(LogChannel::kAI,
                   "Session POST curl exit=" + std::to_string(closeStatus) + " url=" + url);
    return Result<int>::err("curl POST failed with exit " + std::to_string(closeStatus));
  }
  if (statusCode < 200 || statusCode >= 300) {
    NEXUS_LOG_WARN(LogChannel::kAI,
                   "Session POST rejected status=" + std::to_string(statusCode) + " url=" + url);
    return Result<int>::err("session POST rejected with HTTP " + std::to_string(statusCode));
  }

  NEXUS_LOG_INFO(LogChannel::kAI,
                 "Session POST ok status=" + std::to_string(statusCode) + " url=" + url);
  return Result<int>::ok(statusCode);
}

} // namespace nexus::core
