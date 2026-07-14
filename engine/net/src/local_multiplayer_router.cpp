#include "nexus/net/local_multiplayer_router.h"

#include <chrono>
#include <utility>

namespace nexus::net {

namespace {
auto nowSeconds() -> double {
  const auto now = std::chrono::steady_clock::now().time_since_epoch();
  return std::chrono::duration<double>(now).count();
}
} // namespace

LocalMultiplayerRouter::LocalMultiplayerRouter(NetSession& session)
    : m_session(session) {}

void LocalMultiplayerRouter::dispatchPlayer2Input(std::string_view action,
                                                   const nlohmann::json& payload) {
  NetMessage msg;
  msg.kind      = NetMessageKind::kPlayerInput;
  msg.senderId  = m_player2Id;
  msg.roomCode  = std::string(m_session.roomCode());
  msg.timestamp = nowSeconds();
  msg.payload   = payload;
  msg.payload["action"] = std::string(action);
  (void)m_session.send(msg);
}

void LocalMultiplayerRouter::dispatchStateSync(const nlohmann::json& statePayload) {
  NetMessage msg;
  msg.kind      = NetMessageKind::kGameStateSync;
  msg.senderId  = m_player2Id;
  msg.roomCode  = std::string(m_session.roomCode());
  msg.timestamp = nowSeconds();
  msg.payload   = statePayload;
  (void)m_session.send(msg);
}

void LocalMultiplayerRouter::dispatchMatchResult(const nlohmann::json& resultPayload) {
  NetMessage msg;
  msg.kind      = NetMessageKind::kMatchResult;
  msg.senderId  = m_player2Id;
  msg.roomCode  = std::string(m_session.roomCode());
  msg.timestamp = nowSeconds();
  msg.payload   = resultPayload;
  (void)m_session.send(msg);
}

void LocalMultiplayerRouter::setPlayer2Id(std::string id) {
  m_player2Id = std::move(id);
}

} // namespace nexus::net
