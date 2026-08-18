#include "nexus/core/http_client.h"
#include "nexus/core/websocket_client.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <thread>

#if defined(__unix__) || defined(__APPLE__)
#include <arpa/inet.h>
#include <netinet/in.h>
#include <poll.h>
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

void http_stub_post_rejects_non_success_status() {
  nexus::core::HttpClient client({
      .url = "http://127.0.0.1:8000/api/games/session",
      .useStubTransport = true,
      .stubStatusCode = 503,
  });
  const auto result = client.post(R"({"mode_id":"basketball_dunk","score":10})");
  require(result.isErr(), "http stub non-2xx rejected");
  require(client.postedRequests().size() == 1, "http stub failure recorded post");
  require(client.postedRequests().front().statusCode == 503, "http stub recorded status 503");
}

#if defined(__unix__) || defined(__APPLE__)
void http_real_post_rejects_non_success_status() {
  if (std::system("command -v curl >/dev/null 2>&1") != 0) {
    return;
  }

  const int serverFd = ::socket(AF_INET, SOCK_STREAM, 0);
  require(serverFd >= 0, "http test socket created");
  const int reuse = 1;
  (void)::setsockopt(serverFd, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));

  sockaddr_in address{};
  address.sin_family = AF_INET;
  address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  address.sin_port = 0;
  require(::bind(serverFd, reinterpret_cast<sockaddr*>(&address), sizeof(address)) == 0,
          "http test socket bound");
  socklen_t addressLength = sizeof(address);
  require(::getsockname(serverFd, reinterpret_cast<sockaddr*>(&address), &addressLength) == 0,
          "http test socket port resolved");
  const auto port = ntohs(address.sin_port);
  require(::listen(serverFd, 1) == 0, "http test socket listening");

  std::thread server([serverFd]() {
    pollfd ready{};
    ready.fd = serverFd;
    ready.events = POLLIN;
    if (::poll(&ready, 1, 5000) <= 0) {
      ::close(serverFd);
      return;
    }
    const int clientFd = ::accept(serverFd, nullptr, nullptr);
    if (clientFd >= 0) {
      char buffer[1024];
      (void)::recv(clientFd, buffer, sizeof(buffer), 0);
      const char response[] =
          "HTTP/1.1 503 Service Unavailable\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
      (void)::send(clientFd, response, std::strlen(response), 0);
      ::close(clientFd);
    }
    ::close(serverFd);
  });

  nexus::core::HttpClient client({
      .url = "http://127.0.0.1:" + std::to_string(port) + "/api/games/session",
      .useStubTransport = false,
  });
  const auto result = client.post(R"({"mode_id":"basketball_dunk","score":10})");
  server.join();

  require(result.isErr(), "real HTTP 503 rejected");
  require(client.postedRequests().size() == 1, "real HTTP 503 recorded post");
  require(client.postedRequests().front().statusCode == 503, "real HTTP 503 status recorded");
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
  http_stub_post_rejects_non_success_status();
#if defined(__unix__) || defined(__APPLE__)
  http_real_post_rejects_non_success_status();
#endif
  std::fprintf(stderr, "PASS: nexus_realtime_test\n");
  return 0;
}
