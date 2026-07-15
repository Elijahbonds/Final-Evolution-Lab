// NEXUS multiplayer — local 2-player input router
#pragma once

#include "nexus/net/net_message.h"
#include "nexus/net/net_session.h"

#include <nlohmann/json.hpp>
#include <string>
#include <string_view>

namespace nexus::net {

/// Routes second-player commands (touch zone B / gamepad 2) as NetMessages into
/// the shared NetMessageBus so game modes receive them identically to online
/// opponent state — no per-mode special-casing required.
///
/// Call dispatchPlayer2Input() from the platform input layer whenever player 2
/// performs an action.  The message is injected as kPlayerInput and visible to
/// the gameplay update loop via NetSession::bus().drain().
class LocalMultiplayerRouter {
public:
  explicit LocalMultiplayerRouter(NetSession& session);

  /// Inject a kPlayerInput message from player 2 into the net bus.
  /// `action`  — e.g. "submit_answer", "shoot", "tackle", "charge_begin"
  /// `payload` — action parameters (mode-specific JSON object)
  void dispatchPlayer2Input(std::string_view action,
                            const nlohmann::json& payload = nlohmann::json::object());

  /// Inject a kGameStateSync message.  Used when this device is the host and
  /// needs to push authoritative state to a local second screen.
  void dispatchStateSync(const nlohmann::json& statePayload);

  /// Inject a kMatchResult message (e.g. at end of a local session).
  void dispatchMatchResult(const nlohmann::json& resultPayload);

  void setPlayer2Id(std::string id);
  [[nodiscard]] auto player2Id() const -> std::string_view { return m_player2Id; }

private:
  NetSession& m_session;
  std::string m_player2Id{"local_p2"};
};

} // namespace nexus::net
