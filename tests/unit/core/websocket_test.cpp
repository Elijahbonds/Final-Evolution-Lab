#include "nexus/core/http_client.h"
#include "nexus/core/websocket_client.h"

#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <string>
#include <thread>

#if defined(__unix__) || defined(__APPLE__)
#include <netinet/in.h>
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

#if defined(__unix__) || defined(__APPLE__)
class SingleResponseHttpServer {
public:
  explicit SingleResponseHttpServer(int statusCode) {
    const int serverSocket = ::socket(AF_INET, SOCK_STREAM, 0);
    require(serverSocket >= 0, "create test HTTP socket");

    const int reuse = 1;
    (void)::setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));

    sockaddr_in address{};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = 0;
    require(::bind(serverSocket, reinterpret_cast<sockaddr*>(&address), sizeof(address)) == 0,
            "bind test HTTP socket");
    require(::listen(serverSocket, 1) == 0, "listen test HTTP socket");

    socklen_t length = sizeof(address);
    require(::getsockname(serverSocket, reinterpret_cast<sockaddr*>(&address), &length) == 0,
            "read test HTTP socket port");
    m_port = ntohs(address.sin_port);

    m_thread = std::thread([serverSocket, statusCode]() {
      const int clientSocket = ::accept(serverSocket, nullptr, nullptr);
      if (clientSocket >= 0) {
        char requestBuffer[2048];
        (void)::recv(clientSocket, requestBuffer, sizeof(requestBuffer), 0);
        const std::string body = "{}";
        const std::string response = "HTTP/1.1 " + std::to_string(statusCode) +
                                     " NEXUS\r\nContent-Type: application/json\r\n"
                                     "Content-Length: " +
                                     std::to_string(body.size()) +
                                     "\r\nConnection: close\r\n\r\n" + body;
        (void)::send(clientSocket, response.data(), response.size(), 0);
        (void)::close(clientSocket);
      }
      (void)::close(serverSocket);
    });
  }

  ~SingleResponseHttpServer() {
    if (m_thread.joinable()) {
      m_thread.join();
    }
  }

  [[nodiscard]] auto url() const -> std::string {
    return "http://127.0.0.1:" + std::to_string(m_port) + "/api/games/session";
  }

private:
  std::uint16_t m_port{0};
  std::thread m_thread;
};

[[nodiscard]] auto curlAvailable() -> bool {
  return std::system("command -v curl >/dev/null 2>&1") == 0;
}
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

void http_live_post_records_server_status() {
#if defined(__unix__) || defined(__APPLE__)
  if (!curlAvailable()) {
    std::fprintf(stderr, "SKIP: curl unavailable for live HTTP status test\n");
    return;
  }

  SingleResponseHttpServer server(503);
  nexus::core::HttpClient client({
      .url = server.url(),
      .useStubTransport = false,
  });

  const auto result = client.post(R"({"mode_id":"basketball_dunk","score":10})");
  require(result.isOk(), "curl HTTP post returns parsed status");
  require(result.value() == 503, "curl HTTP post preserves non-2xx status");
  require(client.postedRequests().size() == 1, "live HTTP post recorded request");
  require(client.postedRequests().front().statusCode == 503, "record stores HTTP 503");
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
  http_live_post_records_server_status();
  std::fprintf(stderr, "PASS: nexus_realtime_test\n");
  return 0;
}
