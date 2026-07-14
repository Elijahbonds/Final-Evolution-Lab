#include "nexus/gameplay/matchmaking_client.h"

#include "nexus/core/log.h"

#include <utility>

namespace nexus::gameplay {

MatchmakingClient::MatchmakingClient(MatchmakingClientConfig config)
    : m_config(std::move(config)),
      m_http(core::HttpClientConfig{
          .url              = m_config.relayBaseUrl + "/match-relay/create",
          .useStubTransport = m_config.useStubTransport,
      }) {}

void MatchmakingClient::setConfig(MatchmakingClientConfig config) {
  m_config = std::move(config);
  m_http.setUrl(m_config.relayBaseUrl + "/match-relay/create");
  m_http.setStubTransportEnabled(m_config.useStubTransport);
}

auto MatchmakingClient::createLobby(std::string_view modeId,
                                     std::string_view userId) -> Result<LobbyInfo> {
  const auto result = post("/match-relay/create",
                           {{"mode_id", modeId}, {"host_user_id", userId}});
  if (result.isErr()) {
    return Result<LobbyInfo>::err(result.error());
  }
  return Result<LobbyInfo>::ok(parseLobbyInfo(result.value()));
}

auto MatchmakingClient::joinLobby(std::string_view roomCode,
                                   std::string_view userId) -> Result<LobbyInfo> {
  const auto result = post("/match-relay/join",
                           {{"room_code", roomCode}, {"user_id", userId}});
  if (result.isErr()) {
    return Result<LobbyInfo>::err(result.error());
  }
  return Result<LobbyInfo>::ok(parseLobbyInfo(result.value()));
}

auto MatchmakingClient::setReady(std::string_view roomCode,
                                  std::string_view userId) -> Result<void> {
  const auto result = post("/match-relay/ready",
                           {{"room_code", roomCode}, {"user_id", userId}});
  if (result.isErr()) {
    return Result<void>::err(result.error());
  }
  return Result<void>::ok();
}

auto MatchmakingClient::buildRelayConfig(std::string_view roomCode,
                                          std::string_view userId,
                                          net::NetSessionConfig& outConfig) const
    -> Result<void> {
  if (roomCode.empty()) {
    return Result<void>::err("room_code is required to build relay config");
  }
  outConfig.mode             = net::NetSessionMode::kOnline;
  outConfig.roomCode         = std::string(roomCode);
  outConfig.localUserId      = std::string(userId);
  outConfig.relayUrl         = m_config.wsRelayUrl + "/" + std::string(roomCode);
  outConfig.useStubTransport = m_config.useStubTransport;
  return Result<void>::ok();
}

// ── Private helpers ──────────────────────────────────────────────────────────

auto MatchmakingClient::post(std::string_view path,
                              const nlohmann::json& body) -> Result<nlohmann::json> {
  m_http.setUrl(m_config.relayBaseUrl + std::string(path));
  const auto statusResult = m_http.post(body.dump());
  if (statusResult.isErr()) {
    return Result<nlohmann::json>::err(statusResult.error());
  }
  // In stub mode HttpClient returns 200 without a real body; return a minimal
  // stub lobby so callers have a valid LobbyInfo to work with.
  if (m_config.useStubTransport) {
    return Result<nlohmann::json>::ok({
        {"id",           "stub-lobby-id"},
        {"room_code",    body.value("room_code", "STUB01")},
        {"host_user_id", body.value("host_user_id", body.value("user_id", "anon"))},
        {"mode_id",      body.value("mode_id", "")},
        {"status",       "waiting"},
    });
  }
  // In production: the HTTP response body would be deserialized here.
  // For now we surface a placeholder since HttpClient only returns a status code.
  NEXUS_LOG_WARN(nexus::LogChannel::kCore,
                 "MatchmakingClient: real HTTP response body not yet parsed");
  return Result<nlohmann::json>::ok(nlohmann::json::object());
}

auto MatchmakingClient::parseLobbyInfo(const nlohmann::json& j) -> LobbyInfo {
  LobbyInfo info;
  if (j.is_object()) {
    info.id          = j.value("id", "");
    info.roomCode    = j.value("room_code", "");
    info.hostUserId  = j.value("host_user_id", "");
    info.modeId      = j.value("mode_id", "");
    info.status      = j.value("status", "");
  }
  return info;
}

} // namespace nexus::gameplay
