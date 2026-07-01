#include "nexus/core/http_client.h"
#include "nexus/core/websocket_client.h"

#include <array>
#include <cerrno>
#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <thread>

#include <netinet/in.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <unistd.h>

namespace {

void require(bool condition, const char* message) {
  if (!condition) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    std::exit(1);
  }
}

class OneShotHttpServer {
public:
  explicit OneShotHttpServer(int statusCode) : m_statusCode(statusCode) {
    m_listenFd = ::socket(AF_INET, SOCK_STREAM, 0);
    require(m_listenFd >= 0, "http test server socket");

    int enabled = 1;
    (void)::setsockopt(m_listenFd, SOL_SOCKET, SO_REUSEADDR, &enabled, sizeof(enabled));

    sockaddr_in address{};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = 0;
    require(::bind(m_listenFd, reinterpret_cast<sockaddr*>(&address), sizeof(address)) == 0,
            "http test server bind");
    require(::listen(m_listenFd, 1) == 0, "http test server listen");

    socklen_t addressLength = sizeof(address);
    require(::getsockname(m_listenFd, reinterpret_cast<sockaddr*>(&address), &addressLength) == 0,
            "http test server getsockname");
    m_port = ntohs(address.sin_port);
    m_thread = std::thread([this] { serveOnce(); });
  }

  ~OneShotHttpServer() {
    if (m_thread.joinable()) {
      m_thread.join();
    }
  }

  [[nodiscard]] auto url() const -> std::string {
    return "http://127.0.0.1:" + std::to_string(m_port) + "/api/games/session";
  }

private:
  void serveOnce() {
    fd_set readSet;
    FD_ZERO(&readSet);
    FD_SET(m_listenFd, &readSet);
    timeval timeout{5, 0};
    const int ready = ::select(m_listenFd + 1, &readSet, nullptr, nullptr, &timeout);
    if (ready <= 0) {
      ::close(m_listenFd);
      return;
    }

    const int clientFd = ::accept(m_listenFd, nullptr, nullptr);
    if (clientFd < 0) {
      ::close(m_listenFd);
      return;
    }

    std::array<char, 1024> requestBuffer{};
    (void)::recv(clientFd, requestBuffer.data(), requestBuffer.size(), 0);
    const std::string response = "HTTP/1.1 " + std::to_string(m_statusCode) +
                                 " Test\r\nContent-Type: application/json\r\n"
                                 "Content-Length: 2\r\nConnection: close\r\n\r\n{}";
    (void)::send(clientFd, response.data(), response.size(), 0);
    ::close(clientFd);
    ::close(m_listenFd);
  }

  int m_statusCode{200};
  int m_listenFd{-1};
  std::uint16_t m_port{0};
  std::thread m_thread;
};

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

void http_live_post_records_real_status_code() {
  require(std::system("command -v curl >/dev/null 2>&1") == 0, "curl available for live HTTP test");
  (void)::unsetenv("NEXUS_RECEIPT_URL");

  OneShotHttpServer server(503);
  nexus::core::HttpClient client({
      .url = server.url(),
      .useStubTransport = false,
  });

  const auto result = client.post(R"({"mode_id":"basketball_dunk","score":10})");
  require(result.isOk(), "live HTTP POST returns transport result");
  require(result.value() == 503, "live HTTP POST preserves 503 status");
  require(client.postedRequests().size() == 1, "live HTTP POST recorded");
  require(client.postedRequests().front().statusCode == 503, "record stores real HTTP status");
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
  http_live_post_records_real_status_code();
  std::fprintf(stderr, "PASS: nexus_realtime_test\n");
  return 0;
}
