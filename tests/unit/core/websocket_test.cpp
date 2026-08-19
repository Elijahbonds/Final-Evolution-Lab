#include "nexus/core/http_client.h"
#include "nexus/core/websocket_client.h"

#include <cstdio>
#include <cstdlib>
#include <string>
#include <thread>

#if !defined(_WIN32)
#include <arpa/inet.h>
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

#if !defined(_WIN32)
void http_real_transport_reports_server_status() {
  const int serverSocket = ::socket(AF_INET, SOCK_STREAM, 0);
  require(serverSocket >= 0, "test HTTP server socket opens");

  const int reuse = 1;
  (void)::setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));

  sockaddr_in address{};
  address.sin_family = AF_INET;
  address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  address.sin_port = 0;
  require(::bind(serverSocket, reinterpret_cast<sockaddr*>(&address), sizeof(address)) == 0,
          "test HTTP server binds");

  socklen_t addressLength = sizeof(address);
  require(::getsockname(serverSocket, reinterpret_cast<sockaddr*>(&address), &addressLength) == 0,
          "test HTTP server port resolved");
  require(::listen(serverSocket, 1) == 0, "test HTTP server listens");

  const int port = ntohs(address.sin_port);
  std::thread server([serverSocket]() {
    const int clientSocket = ::accept(serverSocket, nullptr, nullptr);
    if (clientSocket >= 0) {
      char requestBuffer[1024];
      (void)::recv(clientSocket, requestBuffer, sizeof(requestBuffer), 0);
      constexpr const char* response =
          "HTTP/1.1 503 Service Unavailable\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
      (void)::send(clientSocket, response, std::char_traits<char>::length(response), 0);
      (void)::close(clientSocket);
    }
    (void)::close(serverSocket);
  });

  nexus::core::HttpClient client({
      .url = "http://127.0.0.1:" + std::to_string(port) + "/api/games/session",
      .useStubTransport = false,
  });
  const auto result = client.post(R"({"mode_id":"basketball_dunk","score":10})");
  server.join();

  require(result.isOk(), "real HTTP transport returns HTTP status");
  require(result.value() == 503, "real HTTP transport preserves 503 status");
  require(client.postedRequests().size() == 1, "real HTTP POST recorded");
  require(client.postedRequests().front().statusCode == 503, "recorded HTTP status is 503");
}
#endif

} // namespace

auto main() -> int {
  stub_connect_and_send();
  send_without_connect_sets_error_envelope();
  tcp_connect_failure_surfaces_error();
  invalid_url_rejected();
  stub_reconnect_after_disconnect();
  auto_reconnect_on_send_when_disconnected();
  http_stub_post_records_session_contract();
#if !defined(_WIN32)
  http_real_transport_reports_server_status();
#endif
  std::fprintf(stderr, "PASS: nexus_realtime_test\n");
  return 0;
}
