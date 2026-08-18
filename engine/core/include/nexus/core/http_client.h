#pragma once

#include "nexus/core/result.h"

#include <cstdint>
#include <span>
#include <string>
#include <string_view>
#include <vector>

namespace nexus::core {

struct HttpPostRecord {
  std::string url;
  std::string body;
  int statusCode{0};
};

struct HttpClientConfig {
  std::string url{"http://127.0.0.1:8000/api/games/session"};
  std::string authToken;
  /// When true, POST succeeds in-process without network (headless + unit tests).
  bool useStubTransport{true};
  /// Deterministic status for stub transport; non-2xx values surface as delivery errors.
  int stubStatusCode{200};
};

/// Minimal HTTP POST client for FEL session receipts (`POST /api/games/session`).
/// Stub transport records requests in-process; real mode shells out to curl when available.
class HttpClient {
public:
  explicit HttpClient(HttpClientConfig config = {});

  auto post(std::string_view jsonBody) -> Result<int>;
  void setUrl(std::string url);
  void setAuthToken(std::string token);
  void setStubTransportEnabled(bool enabled);
  void setStubStatusCode(int statusCode);

  [[nodiscard]] auto configuredUrl() const -> std::string_view;
  [[nodiscard]] auto postedRequests() const -> std::span<const HttpPostRecord>;
  void clearPostedRequests();

private:
  auto postViaCurl(std::string_view jsonBody) -> Result<int>;

  HttpClientConfig m_config;
  std::vector<HttpPostRecord> m_posted;
};

} // namespace nexus::core
