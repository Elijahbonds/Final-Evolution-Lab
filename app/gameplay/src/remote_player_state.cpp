#include "nexus/gameplay/remote_player_state.h"

namespace nexus::gameplay {

auto RemotePlayerState::fromJson(const nlohmann::json& j) -> RemotePlayerState {
  RemotePlayerState s;
  if (j.contains("player_id") && j["player_id"].is_string()) {
    s.playerId = j["player_id"].get<std::string>();
  }
  if (j.contains("score") && j["score"].is_number()) {
    s.score = j["score"].get<float>();
  }
  if (j.contains("correct") && j["correct"].is_number_integer()) {
    s.correct = j["correct"].get<int32_t>();
  }
  if (j.contains("hp") && j["hp"].is_number_integer()) {
    s.hp = j["hp"].get<int32_t>();
  }
  if (j.contains("goals") && j["goals"].is_number_integer()) {
    s.goals = j["goals"].get<int32_t>();
  }
  if (j.contains("dunk_score") && j["dunk_score"].is_number_integer()) {
    s.dunkScore = j["dunk_score"].get<int32_t>();
  }
  if (j.contains("extra") && j["extra"].is_object()) {
    s.extra = j["extra"];
  }
  return s;
}

auto RemotePlayerState::toJson() const -> nlohmann::json {
  return {
      {"player_id",  playerId},
      {"score",      score},
      {"correct",    correct},
      {"hp",         hp},
      {"goals",      goals},
      {"dunk_score", dunkScore},
      {"extra",      extra},
  };
}

} // namespace nexus::gameplay
