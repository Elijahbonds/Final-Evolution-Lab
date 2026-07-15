#include "nexus/net/net_message.h"

namespace nexus::net {

auto NetMessage::kindToString(NetMessageKind kind) -> std::string_view {
  switch (kind) {
  case NetMessageKind::kPlayerInput:   return "player_input";
  case NetMessageKind::kGameStateSync: return "game_state_sync";
  case NetMessageKind::kLobbyEvent:    return "lobby_event";
  case NetMessageKind::kMatchResult:   return "match_result";
  }
  return "player_input";
}

auto NetMessage::kindFromString(std::string_view s) -> NetMessageKind {
  if (s == "game_state_sync") return NetMessageKind::kGameStateSync;
  if (s == "lobby_event")     return NetMessageKind::kLobbyEvent;
  if (s == "match_result")    return NetMessageKind::kMatchResult;
  return NetMessageKind::kPlayerInput;
}

auto NetMessage::toJson() const -> nlohmann::json {
  return {
      {"kind",      kindToString(kind)},
      {"sender_id", senderId},
      {"room_code", roomCode},
      {"payload",   payload},
      {"timestamp", timestamp},
  };
}

auto NetMessage::fromJson(const nlohmann::json& j) -> NetMessage {
  NetMessage msg;
  if (j.contains("kind") && j["kind"].is_string()) {
    msg.kind = kindFromString(j["kind"].get<std::string>());
  }
  if (j.contains("sender_id") && j["sender_id"].is_string()) {
    msg.senderId = j["sender_id"].get<std::string>();
  }
  if (j.contains("room_code") && j["room_code"].is_string()) {
    msg.roomCode = j["room_code"].get<std::string>();
  }
  if (j.contains("payload") && j["payload"].is_object()) {
    msg.payload = j["payload"];
  }
  if (j.contains("timestamp") && j["timestamp"].is_number()) {
    msg.timestamp = j["timestamp"].get<double>();
  }
  return msg;
}

} // namespace nexus::net
