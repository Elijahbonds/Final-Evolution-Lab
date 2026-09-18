#include "nexus/core/http_client.h"

#include "nexus/core/log.h"

#include <array>
#include <cctype>
#include <cerrno>
#include <cstring>
#include <filesystem>
#include <cstdio>
#include <cstdlib>
#include <sstream>
#include <string>
#include <vector>

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

[[nodiscard]] auto writeTempBody(std::string_view jsonBody) -> Result<std::string> {
  const auto templatePath =
      (std::filesystem::temp_directory_path() / "nexus_http_post_body_XXXXXX").string();
  std::vector<char> pathBuffer(templatePath.begin(), templatePath.end());
  pathBuffer.push_back('\0');

  const int fd = mkstemp(pathBuffer.data());
  if (fd == -1) {
    return Result<std::string>::err("failed to create curl POST temp body: " +
                                   std::string(std::strerror(errno)));
  }

  std::size_t written = 0;
  while (written < jsonBody.size()) {
    const ssize_t count = ::write(fd, jsonBody.data() + written, jsonBody.size() - written);
    if (count <= 0) {
      const std::string error = std::strerror(errno);
      (void)::close(fd);
      (void)std::filesystem::remove(pathBuffer.data());
      return Result<std::string>::err("failed to write curl POST temp body: " + error);
    }
    written += static_cast<std::size_t>(count);
  }

  if (::close(fd) != 0) {
    const std::string error = std::strerror(errno);
    (void)std::filesystem::remove(pathBuffer.data());
    return Result<std::string>::err("failed to close curl POST temp body: " + error);
  }

  return Result<std::string>::ok(std::string(pathBuffer.data()));
}

[[nodiscard]] auto parseHttpStatus(std::string_view curlOutput) -> int {
  int status = 0;
  bool sawDigit = false;
  for (const unsigned char ch : curlOutput) {
    if (std::isdigit(ch)) {
      sawDigit = true;
      status = (status * 10) + static_cast<int>(ch - '0');
    }
  }
  return sawDigit ? status : 0;
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
  if (bodyPath.isErr()) {
    return Result<int>::err(bodyPath.error());
  }

  std::ostringstream curlCmd;
  curlCmd << "curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json'";
  if (!m_config.authToken.empty()) {
    curlCmd << " -H " << shellQuote("Authorization: Bearer " + m_config.authToken);
  }
  curlCmd << " -H 'X-FEL-Client: ios' -H 'User-Agent: fel-ios/1.0 (NEXUS)'";
  curlCmd << " --data-binary @" << shellQuote(bodyPath.value()) << " " << shellQuote(url);

  FILE* pipe = popen(curlCmd.str().c_str(), "r");
  if (pipe == nullptr) {
    (void)std::filesystem::remove(bodyPath.value());
    return Result<int>::err("failed to spawn curl for session POST");
  }

  std::string curlOutput;
  std::array<char, 64> buffer{};
  while (std::fgets(buffer.data(), static_cast<int>(buffer.size()), pipe) != nullptr) {
    curlOutput += buffer.data();
  }
  const int closeStatus = pclose(pipe);
  (void)std::filesystem::remove(bodyPath.value());

  const int statusCode = parseHttpStatus(curlOutput);
  m_posted.push_back({url, std::string(jsonBody), statusCode});

  if (closeStatus != 0) {
    NEXUS_LOG_WARN(LogChannel::kAI,
                   "Session POST curl exit=" + std::to_string(closeStatus) + " url=" + url);
    return Result<int>::err("curl POST failed with exit " + std::to_string(closeStatus));
  }

  if (statusCode < 100 || statusCode > 599) {
    return Result<int>::err("curl POST did not return a valid HTTP status");
  }

  NEXUS_LOG_INFO(LogChannel::kAI,
                 "Session POST completed url=" + url + " status=" + std::to_string(statusCode));
  return Result<int>::ok(statusCode);
}

} // namespace nexus::core
