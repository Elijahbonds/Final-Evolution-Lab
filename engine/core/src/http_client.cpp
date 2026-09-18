#include "nexus/core/http_client.h"

#include "nexus/core/log.h"

#include <array>
#include <chrono>
#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <optional>
#include <sstream>

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

[[nodiscard]] auto writeCurlBody(std::string_view jsonBody) -> Result<std::filesystem::path> {
  const auto timestamp = std::chrono::steady_clock::now().time_since_epoch().count();
  const auto path = std::filesystem::temp_directory_path() /
                    ("nexus_receipt_post_" + std::to_string(timestamp) + ".json");

  std::ofstream output(path, std::ios::binary | std::ios::trunc);
  if (!output.is_open()) {
    return Result<std::filesystem::path>::err("failed to create temporary curl body");
  }
  output.write(jsonBody.data(), static_cast<std::streamsize>(jsonBody.size()));
  if (!output.good()) {
    return Result<std::filesystem::path>::err("failed to write temporary curl body");
  }
  return Result<std::filesystem::path>::ok(path);
}

[[nodiscard]] auto parseHttpStatus(const std::string& curlOutput) -> std::optional<int> {
  for (std::size_t index = 0; index + 2 < curlOutput.size(); ++index) {
    if (std::isdigit(static_cast<unsigned char>(curlOutput[index])) &&
        std::isdigit(static_cast<unsigned char>(curlOutput[index + 1])) &&
        std::isdigit(static_cast<unsigned char>(curlOutput[index + 2]))) {
      return std::stoi(curlOutput.substr(index, 3));
    }
  }
  return std::nullopt;
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

  const auto bodyPath = writeCurlBody(jsonBody);
  if (bodyPath.isErr()) {
    return Result<int>::err(bodyPath.error());
  }

  std::ostringstream curlCmd;
  curlCmd << "curl -sS -o /dev/null -w '%{http_code}' -X POST";
  curlCmd << " -H " << shellQuote("Content-Type: application/json");
  if (!m_config.authToken.empty()) {
    curlCmd << " -H " << shellQuote(std::string("Authorization: Bearer ") + m_config.authToken);
  }
  curlCmd << " -H " << shellQuote("X-FEL-Client: ios");
  curlCmd << " -H " << shellQuote("User-Agent: fel-ios/1.0 (NEXUS)");
  curlCmd << " --data-binary @" << shellQuote(bodyPath.value().string());
  curlCmd << " " << shellQuote(url);

  FILE* pipe = popen(curlCmd.str().c_str(), "r");
  if (pipe == nullptr) {
    std::error_code removeError;
    std::filesystem::remove(bodyPath.value(), removeError);
    return Result<int>::err("failed to spawn curl for session POST");
  }
  std::string curlOutput;
  std::array<char, 64> buffer{};
  while (std::fgets(buffer.data(), static_cast<int>(buffer.size()), pipe) != nullptr) {
    curlOutput += buffer.data();
  }
  const int closeStatus = pclose(pipe);
  std::error_code removeError;
  std::filesystem::remove(bodyPath.value(), removeError);

  const int statusCode = parseHttpStatus(curlOutput).value_or(0);
  m_posted.push_back({url, std::string(jsonBody), statusCode});

  if (closeStatus != 0) {
    NEXUS_LOG_WARN(LogChannel::kAI,
                   "Session POST curl exit=" + std::to_string(closeStatus) + " url=" + url);
    return Result<int>::err("curl POST failed with exit " + std::to_string(closeStatus));
  }
  if (statusCode <= 0) {
    return Result<int>::err("curl POST did not return a valid HTTP status");
  }

  NEXUS_LOG_INFO(LogChannel::kAI,
                 "Session POST completed url=" + url + " status=" + std::to_string(statusCode));
  return Result<int>::ok(statusCode);
}

} // namespace nexus::core
