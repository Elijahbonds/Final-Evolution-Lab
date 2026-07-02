#include "nexus/core/http_client.h"
#include "nexus/core/websocket_client.h"

#include <arpa/inet.h>
#include <array>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <netinet/in.h>
#include <string>
#include <sys/socket.h>
#include <thread>
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
    m_serverFd = socket(AF_INET, SOCK_STREAM, 0);
    require(m_serverFd >= 0, "create HTTP test socket");

    int reuse = 1;
    (void)setsockopt(m_serverFd, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));

    sockaddr_in address{};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = 0;
    require(bind(m_serverFd, reinterpret_cast<sockaddr*>(&address), sizeof(address)) == 0,
            "bind HTTP test socket");
    require(listen(m_serverFd, 1) == 0, "listen HTTP test socket");

    socklen_t length = sizeof(address);
    require(getsockname(m_serverFd, reinterpret_cast<sockaddr*>(&address), &length) == 0,
            "read HTTP test socket port");
    m_port = ntohs(address.sin_port);
    m_thread = std::thread([this] { serveOnce(); });
  }

  ~OneShotHttpServer() {
    if (m_serverFd >= 0) {
      shutdown(m_serverFd, SHUT_RDWR);
      close(m_serverFd);
      m_serverFd = -1;
    }
    if (m_thread.joinable()) {
      m_thread.join();
    }
  }

  [[nodiscard]] auto url() const -> std::string {
    return "http://127.0.0.1:" + std::to_string(m_port) + "/api/games/session";
  }

private:
  void serveOnce() {
    const int clientFd = accept(m_serverFd, nullptr, nullptr);
    if (clientFd < 0) {
      return;
    }

    std::string request;
    std::array<char, 512> buffer{};
    while (request.find("\r\n\r\n") == std::string::npos) {
      const ssize_t received = recv(clientFd, buffer.data(), buffer.size(), 0);
      if (received <= 0) {
        break;
      }
      request.append(buffer.data(), static_cast<std::size_t>(received));
    }

    const std::string reason = m_statusCode >= 200 && m_statusCode < 300 ? "OK" : "Unavailable";
    const std::string response = "HTTP/1.1 " + std::to_string(m_statusCode) + " " + reason +
                                 "\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
    (void)send(clientFd, response.data(), response.size(), 0);
    close(clientFd);
  }

  int m_statusCode{200};
  int m_serverFd{-1};
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

void http_live_post_reports_status_codes() {
  if (std::system("command -v curl >/dev/null 2>&1") != 0) {
    std::fprintf(stderr, "SKIP: curl unavailable for live HTTP status test\n");
    return;
  }

  OneShotHttpServer okServer(201);
  nexus::core::HttpClient okClient({
      .url = okServer.url(),
      .useStubTransport = false,
  });
  const auto ok = okClient.post(R"({"mode_id":"basketball_dunk","score":10})");
  require(ok.isOk(), "live HTTP 201 accepted");
  require(ok.value() == 201, "live HTTP status code captured");
  require(okClient.postedRequests().size() == 1, "live HTTP success recorded");
  require(okClient.postedRequests().front().statusCode == 201, "live HTTP success status recorded");

  OneShotHttpServer failServer(503);
  nexus::core::HttpClient failClient({
      .url = failServer.url(),
      .useStubTransport = false,
  });
  const auto fail = failClient.post(R"({"mode_id":"basketball_dunk","score":10})");
  require(fail.isErr(), "live HTTP 503 rejected");
  require(failClient.postedRequests().size() == 1, "live HTTP failure recorded");
  require(failClient.postedRequests().front().statusCode == 503, "live HTTP failure status recorded");
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
  http_live_post_reports_status_codes();
  std::fprintf(stderr, "PASS: nexus_realtime_test\n");
  return 0;
}
