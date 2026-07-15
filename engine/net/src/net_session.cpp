#include "nexus/net/net_session.h"

#include "nexus/core/log.h"

#include <chrono>
#include <utility>

namespace nexus::net {

namespace {
auto nowSeconds() -> double {
  const auto now = std::chrono::steady_clock::now().time_since_epoch();
  return std::chrono::duration<double>(now).count();
}
} // namespace

NetSession::NetSession(NetSessionConfig config)
    : m_config(std::move(config)),
      m_ws(core::WebSocketClientConfig{
          .url              = m_config.relayUrl,
          .autoReconnect    = true,
          .useStubTransport = m_config.useStubTransport,
      }) {}

auto NetSession::connect() -> Result<void> {
  if (m_config.mode == NetSessionMode::kSolo ||
      m_config.mode == NetSessionMode::kLocalMulti) {
    m_state = NetSessionState::kReady;
    NEXUS_LOG_INFO(nexus::LogChannel::kCore,
                   "NetSession ready mode=" +
                       std::string(m_config.mode == NetSessionMode::kSolo
                                       ? "solo"
                                       : "local_multi"));
    return Result<void>::ok();
  }

  // Online: open WebSocket relay channel
  m_state = NetSessionState::kConnecting;
  const auto wsResult = m_ws.connect();
  if (wsResult.isErr()) {
    m_state = NetSessionState::kError;
    return wsResult;
  }

  // Send lobby-join event so the relay knows this peer is present
  NetMessage joinMsg;
  joinMsg.kind      = NetMessageKind::kLobbyEvent;
  joinMsg.senderId  = m_config.localUserId;
  joinMsg.roomCode  = m_config.roomCode;
  joinMsg.timestamp = nowSeconds();
  joinMsg.payload   = {{"event", "joined"}, {"user_id", m_config.localUserId}};
  (void)m_ws.send(joinMsg.toJson().dump());

  m_state = NetSessionState::kReady;
  NEXUS_LOG_INFO(nexus::LogChannel::kCore,
                 "NetSession online ready room=" + m_config.roomCode);
  return Result<void>::ok();
}

void NetSession::disconnect() {
  m_ws.disconnect();
  m_localOutbox.clear();
  m_state = NetSessionState::kEnded;
}

auto NetSession::send(const NetMessage& message) -> Result<void> {
  if (m_config.mode == NetSessionMode::kSolo) {
    return Result<void>::ok();
  }

  if (m_config.mode == NetSessionMode::kLocalMulti) {
    // Local: queue for poll() to flush into the bus (simulates round-trip)
    m_localOutbox.push_back(message);
    return Result<void>::ok();
  }

  // Online: serialize over WebSocket
  return m_ws.send(message.toJson().dump());
}

void NetSession::poll() {
  // Drain local outbox into the bus (local/stub mode)
  for (auto& msg : m_localOutbox) {
    m_bus.push(std::move(msg));
  }
  m_localOutbox.clear();

  // In a future real implementation, received WS frames would be parsed here
  // and pushed into m_bus.  Stub transport has no inbound; real TCP transport
  // would call recv() and parse frames in this block.
}

void NetSession::setRoomCode(std::string code) {
  m_config.roomCode = std::move(code);
  m_ws.setUrl(m_config.relayUrl + "/" + m_config.roomCode);
}

void NetSession::setMode(NetSessionMode mode) {
  m_config.mode = mode;
}

void NetSession::setStubTransportEnabled(bool enabled) {
  m_config.useStubTransport = enabled;
  m_ws.setStubTransportEnabled(enabled);
}

} // namespace nexus::net
