#include "nexus/core/http_client.h"
#include "nexus/core/websocket_client.h"

#include <cstdio>
#include <cstdlib>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <string>
#include <thread>
#include <unistd.h>

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

void http_live_post_surfaces_non2xx() {
  const int port = 18000 + static_cast<int>(getpid() % 1000);
  const auto scriptPath = std::filesystem::temp_directory_path() /
                          ("nexus_http503_server_" + std::to_string(getpid()) + ".py");
  {
    std::ofstream script(scriptPath);
    script << "from http.server import BaseHTTPRequestHandler, HTTPServer\n"
              "class Handler(BaseHTTPRequestHandler):\n"
              "  def do_POST(self):\n"
              "    self.send_response(503)\n"
              "    self.end_headers()\n"
              "  def log_message(self, *args): pass\n"
              "HTTPServer(('127.0.0.1', " << port << "), Handler).serve_forever()\n";
  }

  const std::string launch = "python3 '" + scriptPath.string() + "' >/dev/null 2>&1 & echo $!";
  FILE* serverPipe = popen(launch.c_str(), "r");
  require(serverPipe != nullptr, "spawn loopback 503 server");
  char pidBuffer[32] = {};
  require(std::fgets(pidBuffer, sizeof(pidBuffer), serverPipe) != nullptr, "read server pid");
  pclose(serverPipe);

  bool serverReady = false;
  for (int attempt = 0; attempt < 20; ++attempt) {
    const std::string probe =
        "curl -sS -o /dev/null -w '%{http_code}' -X POST --data '{}' http://127.0.0.1:" +
        std::to_string(port) + "/api/games/session 2>/dev/null";
    FILE* probePipe = popen(probe.c_str(), "r");
    if (probePipe != nullptr) {
      char probeBuffer[16] = {};
      if (std::fgets(probeBuffer, sizeof(probeBuffer), probePipe) != nullptr &&
          std::string(probeBuffer) == "503") {
        serverReady = true;
      }
      pclose(probePipe);
    }
    if (serverReady) {
      break;
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(50));
  }
  require(serverReady, "loopback 503 server ready");

  const std::string url = "http://127.0.0.1:" + std::to_string(port) + "/api/games/session";
  nexus::core::HttpClient client({
      .url = url,
      .useStubTransport = false,
  });
  const auto result = client.post(R"({"mode_id":"basketball_dunk","score":10})");
  require(result.isErr(), "live POST rejects non-2xx");
  require(client.postedRequests().size() == 1, "live POST recorded attempt");
  require(client.postedRequests().front().statusCode == 503, "live POST captured HTTP 503");

  if (pidBuffer[0] != '\0') {
    const std::string killCmd = "kill " + std::string(pidBuffer) + " >/dev/null 2>&1";
    (void)std::system(killCmd.c_str());
  }
  std::error_code ec;
  std::filesystem::remove(scriptPath, ec);
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
  http_live_post_surfaces_non2xx();
  std::fprintf(stderr, "PASS: nexus_realtime_test\n");
  return 0;
}
