#include "nexus/core/websocket_client.h"

#include "nexus/core/log.h"

#include <arpa/inet.h>
#include <netdb.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

#include <cctype>
#include <cerrno>
#include <cstring>
#include <random>
#include <sstream>

namespace nexus::core {

namespace {

struct ParsedWsUrl {
  std::string host;
  std::string path;
  std::uint16_t port{80};
};

auto trim(std::string_view value) -> std::string_view {
  while (!value.empty() && std::isspace(static_cast<unsigned char>(value.front())) != 0) {
    value.remove_prefix(1);
  }
  while (!value.empty() && std::isspace(static_cast<unsigned char>(value.back())) != 0) {
    value.remove_suffix(1);
  }
  return value;
}

auto parseWebSocketUrl(std::string_view url) -> Result<ParsedWsUrl> {
  const std::string_view trimmed = trim(url);
  constexpr std::string_view kPrefix = "ws://";
  if (!trimmed.starts_with(kPrefix)) {
    return Result<ParsedWsUrl>::err("WebSocket URL must use ws:// scheme");
  }
  std::string_view remainder = trimmed.substr(kPrefix.size());
  const std::size_t slash = remainder.find('/');
  const std::string_view hostPort =
      slash == std::string_view::npos ? remainder : remainder.substr(0, slash);
  ParsedWsUrl parsed{};
  parsed.path = slash == std::string_view::npos ? "/" : std::string(remainder.substr(slash));

  const std::size_t colon = hostPort.find(':');
  if (colon == std::string_view::npos) {
    parsed.host = std::string(hostPort);
    parsed.port = 80;
  } else {
    parsed.host = std::string(hostPort.substr(0, colon));
    parsed.port = static_cast<std::uint16_t>(std::stoi(std::string(hostPort.substr(colon + 1))));
  }
  if (parsed.host.empty()) {
    return Result<ParsedWsUrl>::err("WebSocket URL missing host");
  }
  return Result<ParsedWsUrl>::ok(parsed);
}

auto closeSocket(int& fd) -> void {
  if (fd >= 0) {
    close(fd);
    fd = -1;
  }
}

auto randomWebSocketKey() -> std::string {
  static constexpr char kAlphabet[] =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  std::random_device rd;
  std::mt19937 gen(rd());
  std::uniform_int_distribution<int> dist(0, static_cast<int>(sizeof(kAlphabet) - 2));
  std::string key;
  key.reserve(16);
  for (int i = 0; i < 16; ++i) {
    key.push_back(kAlphabet[dist(gen)]);
  }
  return key;
}

auto encodeMaskedTextFrame(std::string_view payload) -> std::string {
  std::string frame;
  frame.reserve(payload.size() + 14);
  frame.push_back(static_cast<char>(0x81)); // FIN + text opcode

  const std::size_t len = payload.size();
  if (len <= 125) {
    frame.push_back(static_cast<char>(0x80 | static_cast<unsigned char>(len)));
  } else if (len <= 0xFFFF) {
    frame.push_back(static_cast<char>(0x80 | 126));
    frame.push_back(static_cast<char>((len >> 8) & 0xFF));
    frame.push_back(static_cast<char>(len & 0xFF));
  } else {
    frame.push_back(static_cast<char>(0x80 | 127));
    for (int shift = 56; shift >= 0; shift -= 8) {
      frame.push_back(static_cast<char>((len >> shift) & 0xFF));
    }
  }

  unsigned char mask[4];
  std::random_device rd;
  for (int i = 0; i < 4; ++i) {
    mask[i] = static_cast<unsigned char>(rd() & 0xFF);
    frame.push_back(static_cast<char>(mask[i]));
  }

  for (std::size_t i = 0; i < len; ++i) {
    frame.push_back(static_cast<char>(static_cast<unsigned char>(payload[i]) ^ mask[i % 4]));
  }
  return frame;
}

} // namespace

WebSocketClient::WebSocketClient(WebSocketClientConfig config) : m_config(std::move(config)) {}

auto WebSocketClient::connect() -> Result<void> {
  if (m_state == WebSocketClientState::kConnected) {
    return Result<void>::ok();
  }

  m_state = WebSocketClientState::kConnecting;
  m_lastError = {};

  if (m_config.useStubTransport) {
    m_state = WebSocketClientState::kConnected;
    NEXUS_LOG_INFO(LogChannel::kAI,
                   "WebSocket stub connected url=" + m_config.url + " (in-process transport)");
    return Result<void>::ok();
  }

  const auto tcpResult = connectTcp();
  if (tcpResult.isErr()) {
    m_state = WebSocketClientState::kError;
    return tcpResult;
  }

  m_state = WebSocketClientState::kConnected;
  NEXUS_LOG_INFO(LogChannel::kAI, "WebSocket connected url=" + m_config.url);
  return Result<void>::ok();
}

void WebSocketClient::disconnect() {
  closeSocket(m_socketFd);
  m_state = WebSocketClientState::kDisconnected;
  m_lastError = {};
}

auto WebSocketClient::reconnect() -> Result<void> {
  disconnect();
  const auto result = connect();
  if (result.isOk()) {
    ++m_reconnectAttempts;
  }
  return result;
}

auto WebSocketClient::tryAutoReconnect() -> Result<void> {
  if (!m_config.autoReconnect) {
    setError("not_connected", "WebSocket send rejected — call connect() first");
    return Result<void>::err(m_lastError.message);
  }
  return reconnect();
}

auto WebSocketClient::send(std::string_view payload) -> Result<void> {
  if (m_state != WebSocketClientState::kConnected) {
    if (m_config.autoReconnect) {
      const auto reconnectResult = tryAutoReconnect();
      if (reconnectResult.isErr()) {
        return reconnectResult;
      }
    } else {
      setError("not_connected", "WebSocket send rejected — call connect() first");
      return Result<void>::err(m_lastError.message);
    }
  }

  if (m_config.useStubTransport) {
    m_sentFrames.emplace_back(payload);
    return Result<void>::ok();
  }

  return sendTcpFrame(payload);
}

auto WebSocketClient::state() const -> WebSocketClientState {
  return m_state;
}

auto WebSocketClient::lastError() const -> const WebSocketErrorEnvelope& {
  return m_lastError;
}

auto WebSocketClient::sentFrames() const -> std::span<const std::string> {
  return m_sentFrames;
}

auto WebSocketClient::configuredUrl() const -> std::string_view {
  return m_config.url;
}

auto WebSocketClient::reconnectAttemptCount() const -> std::uint32_t {
  return m_reconnectAttempts;
}

void WebSocketClient::clearSentFrames() {
  m_sentFrames.clear();
}

void WebSocketClient::resetReconnectAttempts() {
  m_reconnectAttempts = 0;
}

void WebSocketClient::setUrl(std::string url) {
  if (m_state == WebSocketClientState::kConnected) {
    disconnect();
  }
  m_config.url = std::move(url);
}

void WebSocketClient::setStubTransportEnabled(bool enabled) {
  m_config.useStubTransport = enabled;
}

void WebSocketClient::setError(std::string_view code, std::string_view message) {
  m_lastError.code = std::string(code);
  m_lastError.message = std::string(message);
  m_lastError.endpoint = m_config.url;
  m_state = WebSocketClientState::kError;
  NEXUS_LOG_WARN(LogChannel::kAI,
                 "WebSocket error envelope code=" + m_lastError.code + " msg=" + m_lastError.message);
}

auto WebSocketClient::connectTcp() -> Result<void> {
  const auto parsedResult = parseWebSocketUrl(m_config.url);
  if (parsedResult.isErr()) {
    setError("invalid_url", parsedResult.error());
    return Result<void>::err(parsedResult.error());
  }
  const ParsedWsUrl& parsed = parsedResult.value();

  addrinfo hints{};
  hints.ai_family = AF_UNSPEC;
  hints.ai_socktype = SOCK_STREAM;
  addrinfo* result = nullptr;
  const std::string portString = std::to_string(parsed.port);
  if (getaddrinfo(parsed.host.c_str(), portString.c_str(), &hints, &result) != 0) {
    setError("dns_failed", "WebSocket host resolution failed for " + parsed.host);
    return Result<void>::err(m_lastError.message);
  }

  int connectedFd = -1;
  for (addrinfo* cursor = result; cursor != nullptr; cursor = cursor->ai_next) {
    connectedFd = socket(cursor->ai_family, cursor->ai_socktype, cursor->ai_protocol);
    if (connectedFd < 0) {
      continue;
    }
    if (::connect(connectedFd, cursor->ai_addr, cursor->ai_addrlen) == 0) {
      break;
    }
    closeSocket(connectedFd);
  }
  freeaddrinfo(result);

  if (connectedFd < 0) {
    setError("connect_failed", std::string("TCP connect failed: ") + std::strerror(errno));
    return Result<void>::err(m_lastError.message);
  }

  const std::string key = randomWebSocketKey();
  std::ostringstream request;
  request << "GET " << parsed.path << " HTTP/1.1\r\n"
          << "Host: " << parsed.host << ":" << parsed.port << "\r\n"
          << "Upgrade: websocket\r\n"
          << "Connection: Upgrade\r\n"
          << "Sec-WebSocket-Key: " << key << "\r\n"
          << "Sec-WebSocket-Version: 13\r\n"
          << "\r\n";

  const std::string requestString = request.str();
  if (::send(connectedFd, requestString.data(), requestString.size(), 0) < 0) {
    closeSocket(connectedFd);
    setError("handshake_send_failed", std::string("WebSocket handshake send failed: ") +
                                          std::strerror(errno));
    return Result<void>::err(m_lastError.message);
  }

  char response[512]{};
  const ssize_t received = ::recv(connectedFd, response, sizeof(response) - 1, 0);
  if (received <= 0) {
    closeSocket(connectedFd);
    setError("handshake_recv_failed", "WebSocket handshake response missing");
    return Result<void>::err(m_lastError.message);
  }
  response[received] = '\0';
  if (std::strstr(response, "101") == nullptr) {
    closeSocket(connectedFd);
    setError("handshake_rejected", "WebSocket server did not return 101 Switching Protocols");
    return Result<void>::err(m_lastError.message);
  }

  m_socketFd = connectedFd;
  return Result<void>::ok();
}

auto WebSocketClient::sendTcpFrame(std::string_view payload) -> Result<void> {
  if (m_socketFd < 0) {
    setError("socket_closed", "WebSocket TCP socket is not open");
    return Result<void>::err(m_lastError.message);
  }

  const std::string frame = encodeMaskedTextFrame(payload);
  if (::send(m_socketFd, frame.data(), frame.size(), 0) < 0) {
    setError("send_failed", std::string("WebSocket send failed: ") + std::strerror(errno));
    return Result<void>::err(m_lastError.message);
  }
  m_sentFrames.emplace_back(payload);
  return Result<void>::ok();
}

} // namespace nexus::core
