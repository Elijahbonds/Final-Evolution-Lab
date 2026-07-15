// NEXUS multiplayer — top-level network session (online + local)
#pragma once

#include "nexus/core/result.h"
#include "nexus/core/websocket_client.h"
#include "nexus/net/net_message.h"
#include "nexus/net/net_message_bus.h"

#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

// GCC 13.3 workaround: forward-declare enum classes before large STL includes.
namespace nexus { namespace net {
  enum class NetSessionMode  : std::uint8_t;
  enum class NetSessionState : std::uint8_t;
} } // namespace nexus::net

namespace nexus::net {

enum class NetSessionMode : std::uint8_t {
  kSolo       = 0,  // single-player; bus remains empty
  kLocalMulti = 1,  // local 2-player; no network; inputs routed in-process
  kOnline     = 2,  // remote peers via WebSocket relay
};

enum class NetSessionState : std::uint8_t {
  kIdle       = 0,
  kConnecting = 1,
  kReady      = 2,
  kActive     = 3,
  kEnded      = 4,
  kError      = 5,
};

struct NetSessionConfig {
  NetSessionMode mode{NetSessionMode::kSolo};
  std::string    roomCode;
  std::string    localUserId;
  std::string    relayUrl{"ws://127.0.0.1:8787/ws/relay"};
  /// When true, WS transport is stub (unit tests / headless CI).
  bool           useStubTransport{true};
  int            maxPlayers{2};
};

/// Owns the WebSocket relay connection for online sessions.
/// For kLocalMulti, send() pushes directly into the local NetMessageBus.
/// For kSolo, send() is a no-op and the bus stays empty.
/// The gameplay update loop calls poll() once per tick; in stub/local mode this
/// drains the internal send-queue into the bus so tests observe round-trip
/// delivery without network I/O.
class NetSession {
public:
  explicit NetSession(NetSessionConfig config = {});

  auto connect()    -> Result<void>;
  void disconnect();

  /// Broadcast a message to all peers (online) or push to local bus (local/solo).
  auto send(const NetMessage& message) -> Result<void>;

  /// Per-tick poll: flush stub/local outbox into the message bus.
  void poll();

  [[nodiscard]] auto mode()     const -> NetSessionMode   { return m_config.mode; }
  [[nodiscard]] auto state()    const -> NetSessionState  { return m_state; }
  [[nodiscard]] auto roomCode() const -> std::string_view { return m_config.roomCode; }
  [[nodiscard]] auto bus()            -> NetMessageBus&   { return m_bus; }
  [[nodiscard]] auto bus()      const -> const NetMessageBus& { return m_bus; }

  void setRoomCode(std::string code);
  void setMode(NetSessionMode mode);
  void setStubTransportEnabled(bool enabled);

private:
  NetSessionConfig          m_config;
  NetSessionState           m_state{NetSessionState::kIdle};
  core::WebSocketClient     m_ws;
  NetMessageBus             m_bus;
  /// Outbound messages queued in stub/local mode, drained to bus by poll().
  std::vector<NetMessage>   m_localOutbox;
};

} // namespace nexus::net
