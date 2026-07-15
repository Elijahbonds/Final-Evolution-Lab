// Remote (or local 2nd-player) state injected into game modes to bypass ghost AI
#pragma once

#include <cstdint>
#include <string>

#include <nlohmann/json.hpp>

namespace nexus::gameplay {

/// Snapshot of a remote player's authoritative state pushed via NetMessageBus.
/// Game modes accept a `const RemotePlayerState*` on their update() or
/// applyRemoteState() call; when non-null, ghost AI is bypassed in favour of
/// the real peer's data.
struct RemotePlayerState {
  std::string playerId;
  float       score{0.0F};      // generic running score
  int32_t     correct{0};       // brain_brawl: questions answered correctly
  int32_t     hp{100};          // karate: current hit-points
  int32_t     goals{0};         // soccer: goals scored
  int32_t     dunkScore{0};     // dunk_contest: accumulated points
  nlohmann::json extra{nlohmann::json::object()};  // mode-specific extras

  [[nodiscard]] static auto fromJson(const nlohmann::json& j) -> RemotePlayerState;
  [[nodiscard]] auto toJson() const -> nlohmann::json;
};

} // namespace nexus::gameplay
