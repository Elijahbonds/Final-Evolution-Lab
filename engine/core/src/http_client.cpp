#include "nexus/core/http_client.h"

#include "nexus/core/log.h"

#include <atomic>
#include <chrono>
#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <exception>
#include <filesystem>
#include <fstream>
#include <sstream>

namespace nexus::core {

namespace {

[[nodiscard]] auto shellQuote(std::string_view value) -> std::string {
  std::string quoted;
  quoted.reserve(value.size() + 2);
  quoted.push_back('\'');
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

[[nodiscard]] auto trimAsciiWhitespace(std::string value) -> std::string {
  while (!value.empty() && std::isspace(static_cast<unsigned char>(value.front())) != 0) {
    value.erase(value.begin());
  }
  while (!value.empty() && std::isspace(static_cast<unsigned char>(value.back())) != 0) {
    value.pop_back();
  }
  return value;
}

[[nodiscard]] auto makeReceiptPostBodyPath() -> std::filesystem::path {
  static std::atomic<std::uint64_t> counter{0};
  const auto now = std::chrono::steady_clock::now().time_since_epoch().count();
  return std::filesystem::temp_directory_path() /
         ("nexus_receipt_post_" + std::to_string(now) + "_" +
          std::to_string(counter.fetch_add(1, std::memory_order_relaxed)) + ".json");
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

  const std::filesystem::path bodyPath = makeReceiptPostBodyPath();
  {
    std::ofstream bodyFile(bodyPath, std::ios::binary | std::ios::trunc);
    if (!bodyFile.is_open()) {
      return Result<int>::err("failed to write curl POST body temp file");
    }
    bodyFile.write(jsonBody.data(), static_cast<std::streamsize>(jsonBody.size()));
    if (!bodyFile.good()) {
      std::error_code ec;
      std::filesystem::remove(bodyPath, ec);
      return Result<int>::err("failed to write curl POST body");
    }
  }

  std::ostringstream curlCmd;
  curlCmd << "curl -s --max-time 10 -o /dev/null -w '%{http_code}' -X POST "
             "-H 'Content-Type: application/json'";
  if (!m_config.authToken.empty()) {
    curlCmd << " -H " << shellQuote("Authorization: Bearer " + m_config.authToken);
  }
  curlCmd << " -H 'X-FEL-Client: ios' -H 'User-Agent: fel-ios/1.0 (NEXUS)'";
  curlCmd << " --data-binary " << shellQuote("@" + bodyPath.string()) << ' ' << shellQuote(url);

  FILE* pipe = popen(curlCmd.str().c_str(), "r");
  if (pipe == nullptr) {
    std::error_code ec;
    std::filesystem::remove(bodyPath, ec);
    return Result<int>::err("failed to spawn curl for session POST");
  }

  std::string httpStatus;
  char buffer[32]{};
  while (std::fgets(buffer, sizeof(buffer), pipe) != nullptr) {
    httpStatus += buffer;
  }
  const int closeStatus = pclose(pipe);
  std::error_code ec;
  std::filesystem::remove(bodyPath, ec);

  httpStatus = trimAsciiWhitespace(std::move(httpStatus));
  int statusCode = 0;
  try {
    statusCode = httpStatus.empty() ? 0 : std::stoi(httpStatus);
  } catch (const std::exception&) {
    m_posted.push_back({url, std::string(jsonBody), 0});
    return Result<int>::err("curl POST returned invalid HTTP status: " + httpStatus);
  }

  m_posted.push_back({url, std::string(jsonBody), statusCode});

  if (closeStatus != 0) {
    NEXUS_LOG_WARN(LogChannel::kAI,
                   "Session POST curl exit=" + std::to_string(closeStatus) + " url=" + url);
    return Result<int>::err("curl POST failed with exit " + std::to_string(closeStatus));
  }

  NEXUS_LOG_INFO(LogChannel::kAI,
                 "Session POST completed url=" + url + " status=" + std::to_string(statusCode));
  return Result<int>::ok(statusCode);
}

} // namespace nexus::core
