#include "nexus/core/http_client.h"

#include "nexus/core/log.h"

#include <array>
#include <cctype>
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
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
      quoted.push_back(ch);
    }
  }
  quoted.push_back('\'');
  return quoted;
}

[[nodiscard]] auto parseHttpStatus(std::string_view output) -> Result<int> {
  std::string digits;
  for (const char ch : output) {
    if (std::isdigit(static_cast<unsigned char>(ch))) {
      digits.push_back(ch);
    }
  }
  if (digits.size() < 3) {
    return Result<int>::err("curl POST did not return an HTTP status code");
  }
  const std::string status = digits.substr(digits.size() - 3);
  return Result<int>::ok(std::stoi(status));
}

[[nodiscard]] auto writeTempBody(std::string_view jsonBody, std::string& pathOut) -> Result<void> {
  std::array<char, 64> path{};
  std::snprintf(path.data(), path.size(), "/tmp/nexus_receipt_body_XXXXXX");
  const int fd = mkstemp(path.data());
  if (fd == -1) {
    return Result<void>::err("failed to create temporary receipt body file");
  }

  std::size_t written = 0;
  while (written < jsonBody.size()) {
    const ssize_t count =
        write(fd, jsonBody.data() + written, static_cast<unsigned int>(jsonBody.size() - written));
    if (count <= 0) {
      const std::string error = std::strerror(errno);
      close(fd);
      unlink(path.data());
      return Result<void>::err("failed to write temporary receipt body file: " + error);
    }
    written += static_cast<std::size_t>(count);
  }

  if (close(fd) != 0) {
    const std::string error = std::strerror(errno);
    unlink(path.data());
    return Result<void>::err("failed to close temporary receipt body file: " + error);
  }

  pathOut = path.data();
  return Result<void>::ok();
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

  std::string bodyPath;
  if (const auto ready = writeTempBody(jsonBody, bodyPath); ready.isErr()) {
    return Result<int>::err(ready.error());
  }

  std::ostringstream curlCmd;
  curlCmd << "curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json'";
  if (!m_config.authToken.empty()) {
    curlCmd << " -H " << shellQuote("Authorization: Bearer " + m_config.authToken);
  }
  curlCmd << " -H 'X-FEL-Client: ios' -H 'User-Agent: fel-ios/1.0 (NEXUS)'";
  curlCmd << " --data-binary @" << shellQuote(bodyPath) << " " << shellQuote(url);

  FILE* pipe = popen(curlCmd.str().c_str(), "r");
  if (pipe == nullptr) {
    unlink(bodyPath.c_str());
    return Result<int>::err("failed to spawn curl for session POST");
  }

  std::string statusOutput;
  std::array<char, 32> buffer{};
  while (std::fgets(buffer.data(), static_cast<int>(buffer.size()), pipe) != nullptr) {
    statusOutput += buffer.data();
  }
  const int closeStatus = pclose(pipe);
  unlink(bodyPath.c_str());

  const auto parsedStatus = parseHttpStatus(statusOutput);
  const int statusCode = parsedStatus.isOk() ? parsedStatus.value() : 0;
  m_posted.push_back({url, std::string(jsonBody), statusCode});

  if (closeStatus != 0) {
    NEXUS_LOG_WARN(LogChannel::kAI,
                   "Session POST curl exit=" + std::to_string(closeStatus) + " url=" + url);
    return Result<int>::err("curl POST failed with exit " + std::to_string(closeStatus));
  }
  if (parsedStatus.isErr()) {
    return Result<int>::err(parsedStatus.error());
  }

  NEXUS_LOG_INFO(LogChannel::kAI,
                 "Session POST completed url=" + url + " status=" + std::to_string(statusCode));
  return Result<int>::ok(statusCode);
}

} // namespace nexus::core
