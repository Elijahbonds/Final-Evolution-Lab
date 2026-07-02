#include "nexus/gameplay/hud_relay_service.h"

#include "nexus/core/log.h"

#include <cctype>
#include <cstdlib>
#include <string>
#include <string_view>
#include <utility>

namespace nexus::gameplay {

namespace {

constexpr std::string_view kDefaultHudWebSocketUrl{"ws://127.0.0.1:8787/ws/hud"};

auto trimCopy(std::string_view value) -> std::string {
  while (!value.empty() && std::isspace(static_cast<unsigned char>(value.front())) != 0) {
    value.remove_prefix(1);
  }
  while (!value.empty() && std::isspace(static_cast<unsigned char>(value.back())) != 0) {
    value.remove_suffix(1);
  }
  return std::string(value);
}

auto hudWebSocketUrlFromEnv() -> std::string {
  for (const char* key : {"FEL_HUD_WS_URL", "NEXUS_HUD_WS_URL"}) {
    const char* value = std::getenv(key);
    if (value == nullptr) {
      continue;
    }
    std::string trimmed = trimCopy(value);
    if (!trimmed.empty()) {
      return trimmed;
    }
  }
  return {};
}

struct HudRelayInitialConfig {
  std::string url{std::string(kDefaultHudWebSocketUrl)};
  bool useStubTransport{true};
};

auto initialHudRelayConfig() -> HudRelayInitialConfig {
  HudRelayInitialConfig config;
  if (std::string envUrl = hudWebSocketUrlFromEnv(); !envUrl.empty()) {
    config.url = std::move(envUrl);
    config.useStubTransport = false;
  }
  return config;
}

nexus::core::WebSocketClient makeRelayClient(std::string url, bool useStubTransport) {
  return nexus::core::WebSocketClient{
      nexus::core::WebSocketClientConfig{
          .url = std::move(url),
          .autoReconnect = true,
          .useStubTransport = useStubTransport,
      },
  };
}

} // namespace

HudRelayService::HudRelayService() {
  HudRelayInitialConfig config = initialHudRelayConfig();
  m_websocketUrl = std::move(config.url);
  m_useStubTransport = config.useStubTransport;
  m_relay = makeRelayClient(m_websocketUrl, m_useStubTransport);
}

auto HudRelayService::connectRelay() -> nexus::Result<void> {
  m_relay.setUrl(m_websocketUrl);
  m_relay.setStubTransportEnabled(m_useStubTransport);
  return m_relay.connect();
}

void HudRelayService::disconnectRelay() {
  m_relay.disconnect();
}

auto HudRelayService::relayState() const -> nexus::core::WebSocketClientState {
  return m_relay.state();
}

auto HudRelayService::lastRelayError() const -> const nexus::core::WebSocketErrorEnvelope& {
  return m_relay.lastError();
}

void HudRelayService::setWebSocketUrl(std::string url) {
  m_websocketUrl = std::move(url);
  m_relay.setUrl(m_websocketUrl);
}

void HudRelayService::emitTickFrame(const nlohmann::json& framePayload) {
  ++m_frameSequence;
  m_latestFrame = {
      {"type", "fel.hud.frame"},
      {"event", "fel.hud.frame"},
      {"seq", m_frameSequence},
      {"payload", framePayload},
  };
  m_pendingFrames.push_back(m_latestFrame);
  if (m_pendingFrames.size() > 120) {
    m_pendingFrames.erase(m_pendingFrames.begin(), m_pendingFrames.begin() + 60);
  }

  if (m_relay.state() != nexus::core::WebSocketClientState::kConnected) {
    (void)m_relay.connect();
  }
  const auto sendResult = m_relay.send(m_latestFrame.dump());
  if (sendResult.isErr()) {
    NEXUS_LOG_WARN(nexus::LogChannel::kRenderer,
                   "HUD relay WebSocket send failed: " + sendResult.error());
  }
}

void HudRelayService::broadcastMessage(std::string_view messageType,
                                       const nlohmann::json& payload) {
  nlohmann::json frame = {
      {"type", std::string(messageType)},
      {"event", std::string(messageType)},
      {"payload", payload},
  };
  m_pendingFrames.push_back(frame);

  if (m_relay.state() != nexus::core::WebSocketClientState::kConnected) {
    (void)m_relay.connect();
  }
  const auto sendResult = m_relay.send(frame.dump());
  if (sendResult.isErr()) {
    NEXUS_LOG_WARN(nexus::LogChannel::kRenderer,
                   "HUD relay broadcast failed: " + sendResult.error());
  }
}

auto HudRelayService::latestFrame() const -> const nlohmann::json& {
  return m_latestFrame;
}

auto HudRelayService::pollFrame() const -> nlohmann::json {
  if (m_latestFrame.empty()) {
    return {
        {"type", "fel.hud.frame"},
        {"event", "fel.hud.frame"},
        {"seq", 0},
        {"payload", nlohmann::json::object()},
    };
  }
  return m_latestFrame;
}

auto HudRelayService::pendingFrames() const -> std::span<const nlohmann::json> {
  return m_pendingFrames;
}

auto HudRelayService::sentTransportFrames() const -> std::span<const std::string> {
  return m_relay.sentFrames();
}

void HudRelayService::clearPendingFrames() {
  m_pendingFrames.clear();
}

} // namespace nexus::gameplay
