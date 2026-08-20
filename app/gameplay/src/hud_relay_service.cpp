#include "nexus/gameplay/hud_relay_service.h"

#include "nexus/core/log.h"

#include <cstddef>
#include <utility>

namespace nexus::gameplay {

namespace {

constexpr std::size_t kMaxPendingHudFrames = 120;
constexpr std::size_t kPendingHudFramesAfterTrim = 60;

nexus::core::WebSocketClient makeRelayClient(const HudRelayConfig& config) {
  return nexus::core::WebSocketClient{
      nexus::core::WebSocketClientConfig{
          .url = config.websocketUrl,
          .autoReconnect = config.autoReconnect,
          .useStubTransport = config.useStubTransport,
      },
  };
}

void trimPendingHudFrames(std::vector<nlohmann::json>& pendingFrames) {
  if (pendingFrames.size() > kMaxPendingHudFrames) {
    pendingFrames.erase(pendingFrames.begin(),
                        pendingFrames.begin() +
                            static_cast<std::ptrdiff_t>(pendingFrames.size() -
                                                        kPendingHudFramesAfterTrim));
  }
}

} // namespace

HudRelayService::HudRelayService(HudRelayConfig config)
    : m_config(std::move(config)),
      m_relay(makeRelayClient(m_config)) {}

auto HudRelayService::connectRelay() -> nexus::Result<void> {
  m_relay.setUrl(m_config.websocketUrl);
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
  m_config.websocketUrl = std::move(url);
  m_relay.setUrl(m_config.websocketUrl);
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
  trimPendingFrames();

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
  trimPendingFrames();

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

void HudRelayService::trimPendingFrames() {
  trimPendingHudFrames(m_pendingFrames);
}

} // namespace nexus::gameplay
