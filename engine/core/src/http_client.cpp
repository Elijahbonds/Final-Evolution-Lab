#include "nexus/core/http_client.h"

#include "nexus/core/log.h"

#include <array>
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <sstream>
#include <string>
#include <sys/wait.h>
#include <unistd.h>

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

[[nodiscard]] auto trim(std::string value) -> std::string {
  const auto first = value.find_first_not_of(" \t\r\n");
  if (first == std::string::npos) {
    return {};
  }
  const auto last = value.find_last_not_of(" \t\r\n");
  return value.substr(first, last - first + 1);
}

[[nodiscard]] auto parseHttpCode(const std::string& curlOutput) -> int {
  const std::string trimmed = trim(curlOutput);
  if (trimmed.empty()) {
    return 0;
  }
  try {
    return std::stoi(trimmed);
  } catch (...) {
    return 0;
  }
}

[[nodiscard]] auto isSuccessfulHttpStatus(int statusCode) -> bool {
  return statusCode >= 200 && statusCode < 300;
}

[[nodiscard]] auto writeBodyToTempFile(std::string_view body) -> Result<std::string> {
  auto path = std::filesystem::temp_directory_path() / "nexus_http_post_XXXXXX";
  std::string pathTemplate = path.string();
  int fd = mkstemp(pathTemplate.data());
  if (fd < 0) {
    return Result<std::string>::err("failed to create curl body temp file: " +
                                   std::string(std::strerror(errno)));
  }

  std::size_t totalWritten = 0;
  while (totalWritten < body.size()) {
    const ssize_t written =
        write(fd, body.data() + totalWritten, body.size() - totalWritten);
    if (written < 0) {
      const std::string error = std::strerror(errno);
      close(fd);
      std::remove(pathTemplate.c_str());
      return Result<std::string>::err("failed to write curl body temp file: " + error);
    }
    totalWritten += static_cast<std::size_t>(written);
  }

  if (close(fd) != 0) {
    const std::string error = std::strerror(errno);
    std::remove(pathTemplate.c_str());
    return Result<std::string>::err("failed to close curl body temp file: " + error);
  }
  return Result<std::string>::ok(std::move(pathTemplate));
}

[[nodiscard]] auto processExitCode(int closeStatus) -> int {
  if (closeStatus == -1) {
    return -1;
  }
  if (WIFEXITED(closeStatus)) {
    return WEXITSTATUS(closeStatus);
  }
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

  const auto tempBody = writeBodyToTempFile(jsonBody);
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
  curlCmd << " --data-binary @" << shellQuote(tempBody.value());
  curlCmd << ' ' << shellQuote(url);

  FILE* pipe = popen(curlCmd.str().c_str(), "r");
  if (pipe == nullptr) {
    std::remove(tempBody.value().c_str());
    return Result<int>::err("failed to spawn curl for session POST");
  }

  std::string curlOutput;
  std::array<char, 64> buffer{};
  while (std::fgets(buffer.data(), static_cast<int>(buffer.size()), pipe) != nullptr) {
    curlOutput += buffer.data();
  }
  const int closeStatus = pclose(pipe);
  std::remove(tempBody.value().c_str());

  const int curlExit = processExitCode(closeStatus);
  int statusCode = parseHttpCode(curlOutput);
  if (statusCode == 0 && curlExit != 0) {
    statusCode = 502;
  }
  m_posted.push_back({url, std::string(jsonBody), statusCode});

  if (curlExit != 0) {
    NEXUS_LOG_WARN(LogChannel::kAI,
                   "Session POST curl exit=" + std::to_string(curlExit) + " url=" + url +
                       " http_status=" + std::to_string(statusCode));
    return Result<int>::err("curl POST failed with exit " + std::to_string(curlExit));
  }

  if (!isSuccessfulHttpStatus(statusCode)) {
    NEXUS_LOG_WARN(LogChannel::kAI,
                   "Session POST rejected url=" + url +
                       " status=" + std::to_string(statusCode));
    return Result<int>::err("HTTP POST failed with status " + std::to_string(statusCode));
  }

  NEXUS_LOG_INFO(LogChannel::kAI,
                 "Session POST ok url=" + url + " status=" + std::to_string(statusCode));
  return Result<int>::ok(statusCode);
}

} // namespace nexus::core
