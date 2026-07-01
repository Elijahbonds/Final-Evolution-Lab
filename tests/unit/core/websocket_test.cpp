#include "nexus/core/http_client.h"
#include "nexus/core/websocket_client.h"

#include <atomic>
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

class SingleResponseHttpServer {
public:
  explicit SingleResponseHttpServer(int statusCode) : m_statusCode(statusCode) {
    m_listenFd = ::socket(AF_INET, SOCK_STREAM, 0);
    require(m_listenFd >= 0, "create http test socket");

    int reuse = 1;
    (void)::setsockopt(m_listenFd, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));

    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    addr.sin_port = 0;
    require(::bind(m_listenFd, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) == 0,
            "bind http test socket");
    require(::listen(m_listenFd, 1) == 0, "listen http test socket");

    socklen_t len = sizeof(addr);
    require(::getsockname(m_listenFd, reinterpret_cast<sockaddr*>(&addr), &len) == 0,
            "resolve http test port");
    m_port = ntohs(addr.sin_port);

    m_thread = std::thread([this] { serveOnce(); });
  }

  ~SingleResponseHttpServer() {
    if (m_listenFd >= 0) {
      (void)::shutdown(m_listenFd, SHUT_RDWR);
      ::close(m_listenFd);
      m_listenFd = -1;
    }
    if (m_thread.joinable()) {
      m_thread.join();
    }
  }

  [[nodiscard]] auto url() const -> std::string {
    return "http://127.0.0.1:" + std::to_string(m_port) + "/api/games/session";
  }

  [[nodiscard]] auto sawPostBody() const -> bool { return m_sawPostBody.load(); }

private:
  void serveOnce() {
    const int clientFd = ::accept(m_listenFd, nullptr, nullptr);
    if (clientFd < 0) {
      return;
    }

    std::string request;
    char buffer[512];
    const ssize_t bytesRead = ::read(clientFd, buffer, sizeof(buffer));
    if (bytesRead > 0) {
      request.assign(buffer, static_cast<std::size_t>(bytesRead));
      m_sawPostBody.store(request.find("mode_id") != std::string::npos ||
                          request.find("Content-Length:") != std::string::npos);
    }

    const std::string reason = m_statusCode >= 200 && m_statusCode < 300 ? "Created" : "Rejected";
    const std::string response = "HTTP/1.1 " + std::to_string(m_statusCode) + " " + reason +
                                 "\r\nContent-Type: application/json\r\nContent-Length: 2\r\n"
                                 "Connection: close\r\n\r\n{}";
    (void)::send(clientFd, response.data(), response.size(), 0);
    ::close(clientFd);
  }

  int m_statusCode{200};
  int m_listenFd{-1};
  int m_port{0};
  std::atomic_bool m_sawPostBody{false};
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

void http_real_post_accepts_success_status() {
  SingleResponseHttpServer server(201);
  nexus::core::HttpClient client({
      .url = server.url(),
      .useStubTransport = false,
  });

  const auto result = client.post(R"({"mode_id":"basketball_dunk","score":10})");
  require(result.isOk(), "real http post accepts 2xx");
  require(result.value() == 201, "real http post returns backend status");
  require(client.postedRequests().size() == 1, "real http recorded post");
  require(client.postedRequests().front().statusCode == 201, "real http records 2xx status");
  require(server.sawPostBody(), "real http server observed request body");
}

void http_real_post_rejects_error_status() {
  SingleResponseHttpServer server(422);
  nexus::core::HttpClient client({
      .url = server.url(),
      .useStubTransport = false,
  });

  const auto result = client.post(R"({"mode_id":"basketball_dunk","score":99999})");
  require(result.isErr(), "real http post rejects non-2xx");
  require(client.postedRequests().size() == 1, "real http rejection recorded post");
  require(client.postedRequests().front().statusCode == 422, "real http records rejection status");
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
  http_real_post_accepts_success_status();
  http_real_post_rejects_error_status();
  std::fprintf(stderr, "PASS: nexus_realtime_test\n");
  return 0;
}
