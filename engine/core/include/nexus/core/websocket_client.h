#pragma once

#include "nexus/core/result.h"

#include <cstdint>
#include <span>
#include <string>
#include <string_view>
#include <vector>

namespace nexus::core {

enum class WebSocketClientState : std::uint8_t {
  kDisconnected,
  kConnecting,
  kConnected,
  kError,
};

struct WebSocketErrorEnvelope {
  std::string code;
  std::string message;
  std::string endpoint;
};

struct WebSocketClientConfig {
  std::string url{"ws://127.0.0.1:8787/ws/vault"};
  bool autoReconnect{true};
  /// When true, connect/send succeed without network; tests must opt in explicitly.
  bool useStubTransport{false};
};

/// Minimal WebSocket client for FEL bridge outbound and HUD /ws/hud relay.
/// Stub transport queues frames in-process; real TCP handshake when stub is off.
class WebSocketClient {
public:
  explicit WebSocketClient(WebSocketClientConfig config = {});

  auto connect() -> Result<void>;
  /// Disconnect then connect; increments reconnect attempt counter on success.
  auto reconnect() -> Result<void>;
  void disconnect();
  auto send(std::string_view payload) -> Result<void>;

  [[nodiscard]] auto state() const -> WebSocketClientState;
  [[nodiscard]] auto lastError() const -> const WebSocketErrorEnvelope&;
  [[nodiscard]] auto sentFrames() const -> std::span<const std::string>;
  [[nodiscard]] auto configuredUrl() const -> std::string_view;
  [[nodiscard]] auto reconnectAttemptCount() const -> std::uint32_t;
  void clearSentFrames();
  void resetReconnectAttempts();

  void setUrl(std::string url);
  void setStubTransportEnabled(bool enabled);

private:
  auto connectTcp() -> Result<void>;
  auto sendTcpFrame(std::string_view payload) -> Result<void>;
  void setError(std::string_view code, std::string_view message);

  auto tryAutoReconnect() -> Result<void>;

  WebSocketClientConfig m_config;
  WebSocketClientState m_state{WebSocketClientState::kDisconnected};
  WebSocketErrorEnvelope m_lastError;
  std::vector<std::string> m_sentFrames;
  int m_socketFd{-1};
  std::uint32_t m_reconnectAttempts{0};
};

} // namespace nexus::core
