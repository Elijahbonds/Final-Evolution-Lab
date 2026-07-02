// NEXUS port of archived FEL bridge routing (fel_bridge_service)
#pragma once

#include "nexus/core/http_client.h"
#include "nexus/core/result.h"
#include "nexus/core/websocket_client.h"

#include <nlohmann/json.hpp>
#include <string>
#include <string_view>
#include <vector>

namespace nexus::gameplay {

struct FelBridgeConfig {
  std::string websocketUrl{"ws://127.0.0.1:8787/ws/vault"};
  std::string sessionReceiptUrl{"http://127.0.0.1:8000/api/games/session"};
  bool focusKeepaliveEnabled{false};
  float keepaliveIntervalSeconds{0.5F};
  bool autoReconnect{true};
  bool useStubTransport{true};
  int stubHttpStatusCode{200};
};

class FelBridgeService {
public:
  explicit FelBridgeService(FelBridgeConfig config = {});

  auto connectTransport() -> nexus::Result<void>;
  void disconnectTransport();
  [[nodiscard]] auto transportState() const -> nexus::core::WebSocketClientState;
  [[nodiscard]] auto lastTransportError() const -> const nexus::core::WebSocketErrorEnvelope&;

  void setWebSocketUrl(std::string url);
  void setFocusKeepaliveEnabled(bool enabled, float intervalSeconds = 0.5F);
  void notifyVenueTravel(std::string_view venueToken, std::string_view modeId);
  void broadcastMapLoaded(std::string_view mapToken, std::string_view modeId, float prqScore = 0.0F);
  void emitVaultSessionSnapshot(std::string_view modeId,
                                float prqScore,
                                float comboStreak,
                                float comboMeter);
  void sendMatchScore(int32_t scoreA, int32_t scoreB, const nlohmann::json& extraFields = {});
  auto postSessionPayload(const nlohmann::json& receiptBody) -> nexus::Result<int>;
  void tickFocusKeepalive(double deltaSeconds);
  void tickVaultTelemetry(std::string_view modeId,
                          float prqScore,
                          float comboStreak,
                          float comboMeter,
                          double deltaSeconds);

  [[nodiscard]] auto activeVenueToken() const -> std::string_view;
  [[nodiscard]] auto activeArenaGameModeId() const -> std::string_view;
  [[nodiscard]] auto outboundMessages() const -> std::span<const nlohmann::json>;
  [[nodiscard]] auto sentTransportFrames() const -> std::span<const std::string>;
  [[nodiscard]] auto postedSessionRequests() const
      -> std::span<const nexus::core::HttpPostRecord>;
  void clearOutboundMessages();

private:
  void enqueueJson(nlohmann::json payload);
  static auto applyDualVaultEnvelope(nlohmann::json& payload) -> void;
  static auto mapLegacyTypeToEvent(std::string_view legacyType) -> std::string;

  FelBridgeConfig m_config;
  nexus::core::WebSocketClient m_transport;
  nexus::core::HttpClient m_sessionHttp;
  std::string m_activeVenueToken;
  std::string m_activeArenaGameModeId;
  std::vector<nlohmann::json> m_outboundMessages;
  double m_secondsSinceKeepalive{0.0};
  double m_secondsSinceTelemetry{0.0};
};

} // namespace nexus::gameplay
