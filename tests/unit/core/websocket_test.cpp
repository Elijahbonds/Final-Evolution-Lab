#include "nexus/core/http_client.h"
#include "nexus/core/websocket_client.h"

#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string_view>
#include <string>
#include <thread>

#if defined(__unix__) || defined(__APPLE__)
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <unistd.h>
#endif

namespace {

void require(bool condition, const char* message) {
  if (!condition) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    std::exit(1);
  }
}

void require(bool condition, const std::string& message) {
  require(condition, message.c_str());
}

#if defined(__unix__) || defined(__APPLE__)
class OneShotHttpServer {
public:
  explicit OneShotHttpServer(int statusCode) : m_statusCode(statusCode) {
    m_serverFd = ::socket(AF_INET, SOCK_STREAM, 0);
    require(m_serverFd >= 0, "test HTTP server socket created");

    int reuse = 1;
    (void)::setsockopt(m_serverFd, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));

    sockaddr_in address{};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = 0;
    require(::bind(m_serverFd, reinterpret_cast<sockaddr*>(&address), sizeof(address)) == 0,
            "test HTTP server bind");

    socklen_t length = sizeof(address);
    require(::getsockname(m_serverFd, reinterpret_cast<sockaddr*>(&address), &length) == 0,
            "test HTTP server port");
    m_port = ntohs(address.sin_port);
    require(::listen(m_serverFd, 1) == 0, "test HTTP server listen");

    m_thread = std::thread([this] { serveOnce(); });
  }

  OneShotHttpServer(const OneShotHttpServer&) = delete;
  auto operator=(const OneShotHttpServer&) -> OneShotHttpServer& = delete;

  ~OneShotHttpServer() {
    if (m_thread.joinable()) {
      m_thread.join();
    }
    if (m_serverFd >= 0) {
      (void)::close(m_serverFd);
    }
  }

  [[nodiscard]] auto url() const -> std::string {
    return "http://127.0.0.1:" + std::to_string(m_port) + "/api/games/session";
  }

private:
  void serveOnce() const {
    fd_set readSet;
    FD_ZERO(&readSet);
    FD_SET(m_serverFd, &readSet);
    timeval timeout{};
    timeout.tv_sec = 5;
    if (::select(m_serverFd + 1, &readSet, nullptr, nullptr, &timeout) <= 0) {
      return;
    }

    const int clientFd = ::accept(m_serverFd, nullptr, nullptr);
    if (clientFd < 0) {
      return;
    }
    char request[1024];
    (void)::read(clientFd, request, sizeof(request));
    const std::string_view reason = m_statusCode == 503 ? "Service Unavailable" : "OK";
    const std::string response = "HTTP/1.1 " + std::to_string(m_statusCode) + " " +
                                 std::string(reason) +
                                 "\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
    (void)::write(clientFd, response.data(), response.size());
    (void)::close(clientFd);
  }

  int m_serverFd{-1};
  int m_statusCode{200};
  std::uint16_t m_port{0};
  std::thread m_thread;
};
#endif

void stub_connect_and_send() {
  nexus::core::WebSocketClient client({.url = "ws://127.0.0.1:8787/ws/vault",
                                       .autoReconnect = true,
                                       .useStubTransport = true});
  require(client.connect().isOk(), "stub connect");
  require(client.state() == nexus::core::WebSocketClientState::kConnected, "stub connected");
  require(client.send(R"({"type":"ping"})").isOk(), "stub send");
  require(client.sentFrames().size() == 1, "stub queued frame");
}

void send_without_connect_sets_error_envelope() {
  nexus::core::WebSocketClient client({.url = "ws://127.0.0.1:8787/ws/hud",
                                       .autoReconnect = false,
                                       .useStubTransport = true});
  const auto result = client.send(R"({"type":"fel.hud.frame"})");
  require(result.isErr(), "send rejected when disconnected");
  require(client.state() == nexus::core::WebSocketClientState::kError, "error state");
  require(client.lastError().code == "not_connected", "error envelope code");
  require(!client.lastError().message.empty(), "error envelope message");
}

void tcp_connect_failure_surfaces_error() {
  nexus::core::WebSocketClient client({.url = "ws://127.0.0.1:1/ws/hud",
                                       .autoReconnect = false,
                                       .useStubTransport = false});
  const auto result = client.connect();
  require(result.isErr(), "tcp connect fails on closed port");
  require(client.state() == nexus::core::WebSocketClientState::kError, "tcp error state");
  require(!client.lastError().code.empty(), "tcp error code populated");
}

void invalid_url_rejected() {
  nexus::core::WebSocketClient client({.url = "http://127.0.0.1/hud",
                                       .autoReconnect = false,
                                       .useStubTransport = false});
  const auto result = client.connect();
  require(result.isErr(), "invalid scheme rejected");
  require(client.lastError().code == "invalid_url", "invalid url code");
}

void stub_reconnect_after_disconnect() {
  nexus::core::WebSocketClient client({.url = "ws://127.0.0.1:8787/ws/hud",
                                       .autoReconnect = true,
                                       .useStubTransport = true});
  require(client.connect().isOk(), "initial stub connect");
  client.disconnect();
  require(client.state() == nexus::core::WebSocketClientState::kDisconnected, "disconnected");
  require(client.reconnect().isOk(), "stub reconnect");
  require(client.reconnectAttemptCount() == 1, "reconnect counter incremented");
  require(client.send(R"({"type":"fel.hud.frame"})").isOk(), "send after reconnect");
  require(client.sentFrames().size() == 1, "frame sent after reconnect");
}

void auto_reconnect_on_send_when_disconnected() {
  nexus::core::WebSocketClient client({.url = "ws://127.0.0.1:8787/ws/vault",
                                       .autoReconnect = true,
                                       .useStubTransport = true});
  const auto result = client.send(R"({"type":"session.heartbeat"})");
  require(result.isOk(), "auto reconnect on send");
  require(client.state() == nexus::core::WebSocketClientState::kConnected, "connected after auto");
  require(client.reconnectAttemptCount() == 1, "auto reconnect counted");
}

void http_stub_post_records_session_contract() {
  nexus::core::HttpClient client({
      .url = "http://127.0.0.1:8000/api/games/session",
      .useStubTransport = true,
  });
  const auto result = client.post(R"({"mode_id":"basketball_dunk","score":10})");
  require(result.isOk(), "http stub post ok");
  require(result.value() == 200, "http stub status 200");
  require(client.postedRequests().size() == 1, "http stub recorded post");
  require(client.postedRequests().front().url.find("/api/games/session") != std::string::npos,
          "http stub session path");
}

void http_live_post_rejects_non_2xx_status() {
#if defined(__unix__) || defined(__APPLE__)
  OneShotHttpServer server(503);
  nexus::core::HttpClient client({
      .url = server.url(),
      .useStubTransport = false,
  });
  const auto result = client.post(R"({"mode_id":"basketball_dunk","score":10})");
  require(result.isErr(), "live HTTP 503 is rejected");
  require(client.postedRequests().size() == 1, "live HTTP records post");
  require(client.postedRequests().front().statusCode == 503, "live HTTP records actual status");
#else
  std::fprintf(stderr, "SKIP: live HTTP status test requires POSIX sockets\n");
#endif
}

} // namespace

auto main() -> int {
  stub_connect_and_send();
  send_without_connect_sets_error_envelope();
  tcp_connect_failure_surfaces_error();
  invalid_url_rejected();
  stub_reconnect_after_disconnect();
  auto_reconnect_on_send_when_disconnected();
  http_stub_post_records_session_contract();
  http_live_post_rejects_non_2xx_status();
  std::fprintf(stderr, "PASS: nexus_realtime_test\n");
  return 0;
}
