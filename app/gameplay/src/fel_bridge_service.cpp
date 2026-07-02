#include "nexus/gameplay/fel_bridge_service.h"

#include "nexus/core/log.h"
#include "nexus/gameplay/arena_mode_registry.h"

#include <chrono>

namespace nexus::gameplay {

namespace {

[[nodiscard]] auto unixTimestampSeconds() -> std::int64_t {
  return std::chrono::duration_cast<std::chrono::seconds>(
             std::chrono::system_clock::now().time_since_epoch())
      .count();
}

} // namespace

FelBridgeService::FelBridgeService(FelBridgeConfig config)
    : m_config(std::move(config)),
      m_transport(nexus::core::WebSocketClientConfig{
          .url = m_config.websocketUrl,
          .autoReconnect = m_config.autoReconnect,
          .useStubTransport = m_config.useStubTransport,
      }),
      m_sessionHttp(nexus::core::HttpClientConfig{
          .url = m_config.sessionReceiptUrl,
          .useStubTransport = m_config.useStubTransport,
      }) {}

auto FelBridgeService::connectTransport() -> nexus::Result<void> {
  m_transport.setUrl(m_config.websocketUrl);
  return m_transport.connect();
}

void FelBridgeService::disconnectTransport() {
  m_transport.disconnect();
}

auto FelBridgeService::transportState() const -> nexus::core::WebSocketClientState {
  return m_transport.state();
}

auto FelBridgeService::lastTransportError() const -> const nexus::core::WebSocketErrorEnvelope& {
  return m_transport.lastError();
}

void FelBridgeService::setWebSocketUrl(std::string url) {
  m_config.websocketUrl = std::move(url);
  m_transport.setUrl(m_config.websocketUrl);
  m_outboundMessages.clear();
}

void FelBridgeService::setFocusKeepaliveEnabled(bool enabled, float intervalSeconds) {
  m_config.focusKeepaliveEnabled = enabled;
  m_config.keepaliveIntervalSeconds = std::max(0.05F, intervalSeconds);
}

void FelBridgeService::notifyVenueTravel(std::string_view venueToken, std::string_view modeId) {
  if (m_activeVenueToken == venueToken && m_activeArenaGameModeId == modeId) {
    return;
  }

  m_activeVenueToken = std::string(venueToken);
  m_activeArenaGameModeId = std::string(modeId);
  NEXUS_LOG_INFO(nexus::LogChannel::kAI,
                 "Venue travel venue=" + m_activeVenueToken + " mode=" + m_activeArenaGameModeId);

  enqueueJson({
      {"type", "venue_travel"},
      {"event", "venue_travel"},
      {"venue", m_activeVenueToken},
      {"mode", m_activeArenaGameModeId},
      {"t", unixTimestampSeconds()},
  });
}

void FelBridgeService::broadcastMapLoaded(std::string_view mapToken,
                                          std::string_view modeId,
                                          float prqScore) {
  nlohmann::json payload = {
      {"type", "map_loaded"},
      {"event", "map_loaded"},
      {"map", std::string(mapToken)},
      {"mode", std::string(modeId)},
      {"arena_game_mode_id", std::string(modeId)},
      {"venue_token", ArenaModeRegistry::venueTokenForMode(modeId)},
      {"vault_display_mode", ArenaModeRegistry::vaultDisplayModeForMode(modeId)},
      {"nexus_mesh_path", ArenaModeRegistry::nexusMeshPathForMode(modeId)},
      {"legacy_ue_map_alias", ArenaModeRegistry::legacyUeMapAliasForMode(modeId)},
      {"prq", prqScore},
      {"t", unixTimestampSeconds()},
  };
  enqueueJson(std::move(payload));
}

void FelBridgeService::emitVaultSessionSnapshot(std::string_view modeId,
                                                float prqScore,
                                                float comboStreak,
                                                float comboMeter) {
  nlohmann::json payload = {
      {"type", "vault_session"},
      {"event", "session_start"},
      {"t", unixTimestampSeconds()},
      {"arena_game_mode_id", std::string(modeId)},
      {"venue_token", ArenaModeRegistry::venueTokenForMode(modeId)},
      {"vault_display_mode", ArenaModeRegistry::vaultDisplayModeForMode(modeId)},
      {"nexus_mesh_path", ArenaModeRegistry::nexusMeshPathForMode(modeId)},
      {"legacy_ue_map_alias", ArenaModeRegistry::legacyUeMapAliasForMode(modeId)},
      {"prq", prqScore},
      {"combo_streak", comboStreak},
      {"combo_meter", comboMeter},
  };
  enqueueJson(std::move(payload));
}

void FelBridgeService::sendMatchScore(int32_t scoreA,
                                      int32_t scoreB,
                                      const nlohmann::json& extraFields) {
  nlohmann::json payload = {
      {"type", "match_score_final"},
      {"event", "session_end"},
      {"score_a", scoreA},
      {"score_b", scoreB},
      {"t", unixTimestampSeconds()},
  };
  if (!extraFields.empty()) {
    payload["extra"] = extraFields;
    if (extraFields.contains("mode_id")) {
      nlohmann::json receipt = extraFields;
      if (!receipt.contains("score")) {
        receipt["score"] = scoreA;
      }
      (void)postSessionPayload(receipt);
    }
  }
  enqueueJson(std::move(payload));
}

auto FelBridgeService::postSessionPayload(const nlohmann::json& receiptBody) -> nexus::Result<int> {
  m_sessionHttp.setUrl(m_config.sessionReceiptUrl);
  const auto result = m_sessionHttp.post(receiptBody.dump());
  if (result.isErr()) {
    NEXUS_LOG_WARN(nexus::LogChannel::kAI,
                   "FEL bridge session POST failed: " + result.error());
    return result;
  }
  NEXUS_LOG_INFO(nexus::LogChannel::kAI,
                 "FEL bridge session POST ok mode=" + receiptBody.value("mode_id", "unknown"));
  return result;
}

void FelBridgeService::tickFocusKeepalive(double deltaSeconds) {
  if (!m_config.focusKeepaliveEnabled) {
    return;
  }
  m_secondsSinceKeepalive += deltaSeconds;
  if (m_secondsSinceKeepalive < m_config.keepaliveIntervalSeconds) {
    return;
  }
  m_secondsSinceKeepalive = 0.0;
  enqueueJson({
      {"type", "focus_keepalive"},
      {"event", "ping"},
      {"source", "nexus"},
      {"t", unixTimestampSeconds()},
  });
}

void FelBridgeService::tickVaultTelemetry(std::string_view modeId,
                                          float prqScore,
                                          float comboStreak,
                                          float comboMeter,
                                          double deltaSeconds) {
  constexpr double kTelemetryInterval = 0.1;
  m_secondsSinceTelemetry += deltaSeconds;
  if (m_secondsSinceTelemetry < kTelemetryInterval) {
    return;
  }
  m_secondsSinceTelemetry = 0.0;

  enqueueJson({
      {"type", "vault_telemetry"},
      {"event", "session_update"},
      {"prq", prqScore},
      {"combo_streak", comboStreak},
      {"combo_meter", comboMeter},
      {"arena_game_mode_id", std::string(modeId)},
      {"venue_token", ArenaModeRegistry::venueTokenForMode(modeId)},
      {"vault_display_mode", ArenaModeRegistry::vaultDisplayModeForMode(modeId)},
      {"t", unixTimestampSeconds()},
  });
}

auto FelBridgeService::activeVenueToken() const -> std::string_view {
  return m_activeVenueToken;
}

auto FelBridgeService::activeArenaGameModeId() const -> std::string_view {
  return m_activeArenaGameModeId;
}

auto FelBridgeService::outboundMessages() const -> std::span<const nlohmann::json> {
  return m_outboundMessages;
}

auto FelBridgeService::sentTransportFrames() const -> std::span<const std::string> {
  return m_transport.sentFrames();
}

auto FelBridgeService::postedSessionRequests() const
    -> std::span<const nexus::core::HttpPostRecord> {
  return m_sessionHttp.postedRequests();
}

void FelBridgeService::clearOutboundMessages() {
  m_outboundMessages.clear();
}

void FelBridgeService::enqueueJson(nlohmann::json payload) {
  applyDualVaultEnvelope(payload);
  m_outboundMessages.push_back(payload);

  if (m_transport.state() != nexus::core::WebSocketClientState::kConnected) {
    (void)m_transport.connect();
  }

  const std::string serialized = payload.dump();
  const auto sendResult = m_transport.send(serialized);
  if (sendResult.isErr()) {
    NEXUS_LOG_WARN(nexus::LogChannel::kAI,
                   "FEL bridge outbound WebSocket send failed: " + sendResult.error());
  }
}

auto FelBridgeService::applyDualVaultEnvelope(nlohmann::json& payload) -> void {
  const bool hasType = payload.contains("type");
  const bool hasEvent = payload.contains("event");
  if (hasType && !hasEvent) {
    payload["event"] = mapLegacyTypeToEvent(payload["type"].get<std::string>());
  } else if (hasEvent && !hasType) {
    payload["type"] = payload["event"];
  }
}

auto FelBridgeService::mapLegacyTypeToEvent(std::string_view legacyType) -> std::string {
  if (legacyType == "vault_session") {
    return "session_start";
  }
  if (legacyType == "match_score_final") {
    return "session_end";
  }
  if (legacyType == "focus_keepalive") {
    return "ping";
  }
  if (legacyType == "vault_telemetry") {
    return "session_update";
  }
  return std::string(legacyType);
}

} // namespace nexus::gameplay
