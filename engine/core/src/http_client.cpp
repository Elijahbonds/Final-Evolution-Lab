#include "nexus/core/http_client.h"

#include "nexus/core/log.h"

#include <array>
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <exception>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <string>
#include <system_error>
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
  std::string pathTemplate =
      (std::filesystem::temp_directory_path() / "nexus_receipt_body_XXXXXX").string();
  const int fd = mkstemp(pathTemplate.data());
  if (fd < 0) {
    return Result<std::string>::err("failed to create curl body temp file: " +
                                    std::string(std::strerror(errno)));
  }

  FILE* file = fdopen(fd, "wb");
  if (file == nullptr) {
    close(fd);
    std::filesystem::remove(pathTemplate);
    return Result<std::string>::err("failed to open curl body temp file");
  }

  const std::size_t written = std::fwrite(jsonBody.data(), 1, jsonBody.size(), file);
  const int closeResult = std::fclose(file);
  if (written != jsonBody.size() || closeResult != 0) {
    std::filesystem::remove(pathTemplate);
    return Result<std::string>::err("failed to write curl body temp file");
  }

  return Result<std::string>::ok(pathTemplate);
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

  struct TempFileCleanup {
    std::string path;
    ~TempFileCleanup() {
      std::error_code ec;
      std::filesystem::remove(path, ec);
    }
  } cleanup{bodyPath.value()};

  std::ostringstream curlCmd;
  curlCmd << "curl -sS -o /dev/null -w '%{http_code}' -X POST";
  curlCmd << " -H " << shellQuote("Content-Type: application/json");
  if (!m_config.authToken.empty()) {
    curlCmd << " -H " << shellQuote("Authorization: Bearer " + m_config.authToken);
  }
  curlCmd << " -H " << shellQuote("X-FEL-Client: ios");
  curlCmd << " -H " << shellQuote("User-Agent: fel-ios/1.0 (NEXUS)");
  curlCmd << " --data-binary @" << shellQuote(bodyPath.value()) << " " << shellQuote(url);

  FILE* pipe = popen(curlCmd.str().c_str(), "r");
  if (pipe == nullptr) {
    return Result<int>::err("failed to spawn curl for session POST");
  }

  std::string statusOutput;
  std::array<char, 64> buffer{};
  while (std::fgets(buffer.data(), static_cast<int>(buffer.size()), pipe) != nullptr) {
    statusOutput += buffer.data();
  }
  const int closeStatus = pclose(pipe);

  int statusCode = 0;
  try {
    statusCode = std::stoi(statusOutput);
  } catch (const std::exception&) {
    statusCode = 0;
  }
  m_posted.push_back({url, std::string(jsonBody), statusCode});

  if (closeStatus != 0) {
    NEXUS_LOG_WARN(LogChannel::kAI,
                   "Session POST curl exit=" + std::to_string(closeStatus) + " url=" + url);
    return Result<int>::err("curl POST failed with exit " + std::to_string(closeStatus));
  }
  if (statusCode <= 0) {
    return Result<int>::err("curl POST did not return an HTTP status");
  }

  NEXUS_LOG_INFO(LogChannel::kAI,
                 "Session POST completed url=" + url + " status=" + std::to_string(statusCode));
  return Result<int>::ok(statusCode);
}

} // namespace nexus::core
