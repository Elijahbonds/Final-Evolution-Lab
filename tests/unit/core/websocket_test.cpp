#include "nexus/core/http_client.h"
#include "nexus/core/websocket_client.h"

#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

#include <atomic>
#include <cerrno>
#include <cstdint>
#include <cstring>
#include <cstdio>
#include <cstdlib>
#include <sstream>
#include <string>
#include <thread>

namespace {

void require(bool condition, const char* message) {
  if (!condition) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    std::exit(1);
  }
}

void closeFd(int& fd) {
  if (fd >= 0) {
    close(fd);
    fd = -1;
  }
}

class OneShotHttpServer {
public:
  explicit OneShotHttpServer(int statusCode) : m_statusCode(statusCode) {
    m_socketFd = ::socket(AF_INET, SOCK_STREAM, 0);
    require(m_socketFd >= 0, "test http server socket");

    int reuse = 1;
    (void)setsockopt(m_socketFd, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));

    sockaddr_in address{};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = 0;
    require(::bind(m_socketFd, reinterpret_cast<sockaddr*>(&address), sizeof(address)) == 0,
            "test http server bind");
    require(::listen(m_socketFd, 1) == 0, "test http server listen");

    socklen_t length = sizeof(address);
    require(::getsockname(m_socketFd, reinterpret_cast<sockaddr*>(&address), &length) == 0,
            "test http server getsockname");
    m_port = ntohs(address.sin_port);
    m_thread = std::thread([this] { serveOnce(); });
  }

  ~OneShotHttpServer() {
    if (m_thread.joinable()) {
      if (!m_finished.load()) {
        int unblockFd = ::socket(AF_INET, SOCK_STREAM, 0);
        if (unblockFd >= 0) {
          sockaddr_in address{};
          address.sin_family = AF_INET;
          address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
          address.sin_port = htons(m_port);
          (void)::connect(unblockFd, reinterpret_cast<sockaddr*>(&address), sizeof(address));
          closeFd(unblockFd);
        }
      }
      m_thread.join();
    }
    closeFd(m_socketFd);
  }

  [[nodiscard]] auto url(std::string path) const -> std::string {
    std::ostringstream stream;
    stream << "http://127.0.0.1:" << m_port << path;
    return stream.str();
  }

private:
  [[nodiscard]] auto reasonPhrase() const -> const char* {
    if (m_statusCode == 204) {
      return "No Content";
    }
    if (m_statusCode == 503) {
      return "Service Unavailable";
    }
    return "OK";
  }

  void serveOnce() {
    sockaddr_in clientAddress{};
    socklen_t clientLength = sizeof(clientAddress);
    int clientFd = ::accept(m_socketFd, reinterpret_cast<sockaddr*>(&clientAddress), &clientLength);
    if (clientFd >= 0) {
      char requestBuffer[1024]{};
      (void)::recv(clientFd, requestBuffer, sizeof(requestBuffer), 0);
      std::ostringstream response;
      response << "HTTP/1.1 " << m_statusCode << ' ' << reasonPhrase() << "\r\n"
               << "Content-Length: 0\r\n"
               << "Connection: close\r\n\r\n";
      const std::string responseText = response.str();
      (void)::send(clientFd, responseText.data(), responseText.size(), 0);
      closeFd(clientFd);
    }
    closeFd(m_socketFd);
    m_finished.store(true);
  }

  int m_statusCode{200};
  int m_socketFd{-1};
  std::uint16_t m_port{0};
  std::atomic<bool> m_finished{false};
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

void http_live_post_captures_success_status() {
  OneShotHttpServer server(204);
  nexus::core::HttpClient client({
      .url = server.url("/api/games/session"),
      .useStubTransport = false,
  });
  const auto result = client.post(R"({"mode_id":"basketball_dunk","score":10})");
  require(result.isOk(), "http live post 204 ok");
  require(result.value() == 204, "http live status 204 captured");
  require(client.postedRequests().size() == 1, "http live recorded post");
  require(client.postedRequests().front().statusCode == 204, "http live record stores 204");
}

void http_live_post_rejects_non2xx_status() {
  OneShotHttpServer server(503);
  nexus::core::HttpClient client({
      .url = server.url("/api/games/session"),
      .useStubTransport = false,
  });
  const auto result = client.post(R"({"mode_id":"basketball_dunk","score":10})");
  require(result.isErr(), "http live post 503 rejected");
  require(result.error().find("503") != std::string::npos, "http live 503 error mentions status");
  require(client.postedRequests().size() == 1, "http live 503 recorded post");
  require(client.postedRequests().front().statusCode == 503, "http live record stores 503");
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
  http_live_post_captures_success_status();
  http_live_post_rejects_non2xx_status();
  std::fprintf(stderr, "PASS: nexus_realtime_test\n");
  return 0;
}
