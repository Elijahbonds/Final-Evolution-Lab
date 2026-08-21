// NEXUS port of archived FEL HUD relay subsystem
#pragma once

#include "nexus/core/result.h"
#include "nexus/core/websocket_client.h"

#include <nlohmann/json.hpp>
#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

namespace nexus::gameplay {

class HudRelayService {
public:
  HudRelayService();

  auto connectRelay() -> nexus::Result<void>;
  void disconnectRelay();
  [[nodiscard]] auto relayState() const -> nexus::core::WebSocketClientState;
  [[nodiscard]] auto lastRelayError() const -> const nexus::core::WebSocketErrorEnvelope&;

  void setWebSocketUrl(std::string url);
  void setStubTransportEnabled(bool enabled);
  void emitTickFrame(const nlohmann::json& framePayload);
  void broadcastMessage(std::string_view messageType, const nlohmann::json& payload = {});
  [[nodiscard]] auto latestFrame() const -> const nlohmann::json&;
  [[nodiscard]] auto pollFrame() const -> nlohmann::json;
  [[nodiscard]] auto pendingFrames() const -> std::span<const nlohmann::json>;
  [[nodiscard]] auto sentTransportFrames() const -> std::span<const std::string>;
  void clearPendingFrames();

private:
  std::string m_websocketUrl{"ws://127.0.0.1:8787/ws/hud"};
  bool m_useStubTransport{true};
  nexus::core::WebSocketClient m_relay;
  nlohmann::json m_latestFrame{nlohmann::json::object()};
  std::uint64_t m_frameSequence{0};
  std::vector<nlohmann::json> m_pendingFrames;
};

} // namespace nexus::gameplay
