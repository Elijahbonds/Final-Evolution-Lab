// REST + WS client for the Supabase match-relay Edge Function
#pragma once

#include "nexus/core/http_client.h"
#include "nexus/core/result.h"
#include "nexus/net/net_session.h"

#include <nlohmann/json.hpp>
#include <string>
#include <string_view>

namespace nexus::gameplay {

struct LobbyInfo {
  std::string id;
  std::string roomCode;
  std::string hostUserId;
  std::string modeId;
  std::string status;
};

struct MatchmakingClientConfig {
  std::string relayBaseUrl{"http://127.0.0.1:8000"};
  std::string wsRelayUrl{"ws://127.0.0.1:8787/ws/relay"};
  bool        useStubTransport{true};
};

/// Creates and joins multiplayer lobbies via the Supabase match-relay Edge Function.
/// The caller wires the returned NetSessionConfig into a NetSession and calls
/// connect() to open the real-time relay channel.
class MatchmakingClient {
public:
  explicit MatchmakingClient(MatchmakingClientConfig config = {});

  /// POST /match-relay/create → lobby info with room_code
  [[nodiscard]] auto createLobby(std::string_view modeId, std::string_view userId)
      -> Result<LobbyInfo>;

  /// POST /match-relay/join → lobby info for an existing room
  [[nodiscard]] auto joinLobby(std::string_view roomCode, std::string_view userId)
      -> Result<LobbyInfo>;

  /// POST /match-relay/ready → marks this player ready; relay starts match when
  /// all players are ready.
  [[nodiscard]] auto setReady(std::string_view roomCode, std::string_view userId)
      -> Result<void>;

  /// Populate `outConfig` for a NetSession that connects to the relay WS for
  /// the given room.  The caller must then call netSession.connect().
  [[nodiscard]] auto buildRelayConfig(std::string_view roomCode,
                                      std::string_view userId,
                                      net::NetSessionConfig& outConfig) const -> Result<void>;

  void setConfig(MatchmakingClientConfig config);
  [[nodiscard]] auto config() const -> const MatchmakingClientConfig& { return m_config; }

private:
  [[nodiscard]] auto post(std::string_view path, const nlohmann::json& body)
      -> Result<nlohmann::json>;
  [[nodiscard]] static auto parseLobbyInfo(const nlohmann::json& j) -> LobbyInfo;

  MatchmakingClientConfig m_config;
  core::HttpClient        m_http;
};

} // namespace nexus::gameplay
