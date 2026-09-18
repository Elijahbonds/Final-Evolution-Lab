#include "nexus/core/http_client.h"

#include "nexus/core/log.h"

#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <string>
#include <unistd.h>

namespace nexus::core {

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

  const auto bodyPath =
      std::filesystem::temp_directory_path() /
      ("nexus_receipt_" + std::to_string(static_cast<unsigned long>(getpid())) + ".json");
  {
    std::ofstream bodyFile(bodyPath, std::ios::trunc | std::ios::binary);
    if (!bodyFile.is_open()) {
      return Result<int>::err("failed to write receipt body temp file");
    }
    bodyFile.write(jsonBody.data(), static_cast<std::streamsize>(jsonBody.size()));
    if (!bodyFile.good()) {
      return Result<int>::err("failed to write receipt body temp file");
    }
  }

  std::ostringstream curlCmd;
  curlCmd << "curl -sS -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json'";
  if (!m_config.authToken.empty()) {
    curlCmd << " -H 'Authorization: Bearer " << m_config.authToken << "'";
  }
  curlCmd << " -H 'X-FEL-Client: NEXUS' -H 'User-Agent: fel-nexus/1.0 (NEXUS)'";
  curlCmd << " --data-binary '@" << bodyPath.string() << "'";
  curlCmd << " '" << url << "' 2>/dev/null";

  FILE* pipe = popen(curlCmd.str().c_str(), "r");
  if (pipe == nullptr) {
    std::error_code ec;
    std::filesystem::remove(bodyPath, ec);
    return Result<int>::err("failed to spawn curl for session POST");
  }

  char buffer[16] = {};
  std::string statusOutput;
  while (std::fgets(buffer, sizeof(buffer), pipe) != nullptr) {
    statusOutput += buffer;
  }
  const int closeStatus = pclose(pipe);

  std::error_code ec;
  std::filesystem::remove(bodyPath, ec);

  int statusCode = 0;
  try {
    statusCode = std::stoi(statusOutput);
  } catch (...) {
    return Result<int>::err("curl POST returned unparsable status: " + statusOutput);
  }

  m_posted.push_back({url, std::string(jsonBody), statusCode});

  if (closeStatus != 0) {
    NEXUS_LOG_WARN(LogChannel::kAI,
                   "Session POST curl exit=" + std::to_string(closeStatus) + " url=" + url +
                       " status=" + std::to_string(statusCode));
    return Result<int>::err("curl POST failed with exit " + std::to_string(closeStatus));
  }

  if (statusCode < 200 || statusCode >= 300) {
    NEXUS_LOG_WARN(LogChannel::kAI,
                   "Session POST non-2xx status=" + std::to_string(statusCode) + " url=" + url);
    return Result<int>::err("session POST HTTP " + std::to_string(statusCode));
  }

  NEXUS_LOG_INFO(LogChannel::kAI,
                 "Session POST ok url=" + url + " status=" + std::to_string(statusCode));
  return Result<int>::ok(statusCode);
}

} // namespace nexus::core
