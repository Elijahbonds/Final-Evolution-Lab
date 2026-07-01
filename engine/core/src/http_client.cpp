#include "nexus/core/http_client.h"

#include "nexus/core/log.h"

#include <cctype>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <string>
#include <sstream>
#include <system_error>
#if defined(__unix__) || defined(__APPLE__)
#include <sys/wait.h>
#endif

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

[[nodiscard]] auto makeRequestBodyPath() -> std::filesystem::path {
  const auto now = std::chrono::steady_clock::now().time_since_epoch().count();
  return std::filesystem::temp_directory_path() /
         ("nexus_http_post_body_" + std::to_string(now) + ".json");
}

[[nodiscard]] auto parseHttpStatus(std::string_view output) -> int {
  for (std::size_t index = 0; index + 2 < output.size(); ++index) {
    if (std::isdigit(static_cast<unsigned char>(output[index])) &&
        std::isdigit(static_cast<unsigned char>(output[index + 1])) &&
        std::isdigit(static_cast<unsigned char>(output[index + 2]))) {
      return (output[index] - '0') * 100 + (output[index + 1] - '0') * 10 +
             (output[index + 2] - '0');
    }
  }
  return 0;
}

[[nodiscard]] auto decodedExitStatus(int closeStatus) -> int {
#if defined(__unix__) || defined(__APPLE__)
  if (WIFEXITED(closeStatus)) {
    return WEXITSTATUS(closeStatus);
  }
#endif
  return closeStatus;
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

  const auto bodyPath = makeRequestBodyPath();
  {
    std::ofstream bodyFile(bodyPath, std::ios::binary | std::ios::trunc);
    if (!bodyFile.is_open()) {
      return Result<int>::err("failed to stage session POST body");
    }
    bodyFile.write(jsonBody.data(), static_cast<std::streamsize>(jsonBody.size()));
    if (!bodyFile.good()) {
      std::error_code removeError;
      std::filesystem::remove(bodyPath, removeError);
      return Result<int>::err("failed to write staged session POST body");
    }
  }

  std::ostringstream curlCmd;
  curlCmd << "curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 15";
  curlCmd << " -X POST -H " << shellQuote("Content-Type: application/json");
  if (!m_config.authToken.empty()) {
    curlCmd << " -H " << shellQuote("Authorization: Bearer " + m_config.authToken);
  }
  curlCmd << " -H " << shellQuote("X-FEL-Client: ios");
  curlCmd << " -H " << shellQuote("User-Agent: fel-ios/1.0 (NEXUS)");
  curlCmd << " --data-binary " << shellQuote("@" + bodyPath.string());
  curlCmd << " " << shellQuote(url);
  curlCmd << " 2>/dev/null";

  FILE* pipe = popen(curlCmd.str().c_str(), "r");
  if (pipe == nullptr) {
    std::error_code removeError;
    std::filesystem::remove(bodyPath, removeError);
    return Result<int>::err("failed to spawn curl for session POST");
  }
  std::string curlOutput;
  char buffer[64];
  while (std::fgets(buffer, sizeof(buffer), pipe) != nullptr) {
    curlOutput += buffer;
  }
  const int closeStatus = pclose(pipe);
  std::error_code removeError;
  std::filesystem::remove(bodyPath, removeError);

  const int statusCode = parseHttpStatus(curlOutput);
  m_posted.push_back({url, std::string(jsonBody), statusCode});

  if (closeStatus != 0) {
    const int exitStatus = decodedExitStatus(closeStatus);
    NEXUS_LOG_WARN(LogChannel::kAI,
                   "Session POST curl exit=" + std::to_string(exitStatus) + " url=" + url);
    return Result<int>::err("curl POST failed with exit " + std::to_string(exitStatus));
  }
  if (statusCode == 0) {
    NEXUS_LOG_WARN(LogChannel::kAI, "Session POST missing HTTP status url=" + url);
    return Result<int>::err("curl POST did not return an HTTP status");
  }

  NEXUS_LOG_INFO(LogChannel::kAI,
                 "Session POST completed url=" + url + " status=" + std::to_string(statusCode));
  return Result<int>::ok(statusCode);
}

} // namespace nexus::core
