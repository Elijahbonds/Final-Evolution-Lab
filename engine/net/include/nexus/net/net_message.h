// NEXUS multiplayer — typed, JSON-framed network message
#pragma once

#include <cstdint>
#include <string>
#include <string_view>

// GCC 13.3 workaround: forward-declare enum classes before large STL includes.
namespace nexus { namespace net {
  enum class NetMessageKind : std::uint8_t;
} } // namespace nexus::net

#include <nlohmann/json.hpp>

namespace nexus::net {

enum class NetMessageKind : std::uint8_t {
  kPlayerInput   = 0,  // joystick / button / action intent from any player
  kGameStateSync = 1,  // authoritative snapshot from host (~20 Hz)
  kLobbyEvent    = 2,  // join / leave / ready transitions
  kMatchResult   = 3,  // final per-player scores; triggers endSession for all
};

struct NetMessage {
  NetMessageKind kind{NetMessageKind::kPlayerInput};
  std::string    senderId;   // userId of the originating peer
  std::string    roomCode;   // lobby room code
  nlohmann::json payload{nlohmann::json::object()};
  double         timestamp{0.0};  // monotonic seconds at send time

  [[nodiscard]] auto toJson()  const -> nlohmann::json;
  [[nodiscard]] static auto fromJson(const nlohmann::json& j) -> NetMessage;
  [[nodiscard]] static auto kindFromString(std::string_view s) -> NetMessageKind;
  [[nodiscard]] static auto kindToString(NetMessageKind kind) -> std::string_view;
};

} // namespace nexus::net
