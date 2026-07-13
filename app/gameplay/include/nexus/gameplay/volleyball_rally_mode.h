// Volleyball Rally — Sand_Court rally-scoring beach volleyball simulator (volleyball)
#pragma once

#include "nexus/core/result.h"

#include <nlohmann/json.hpp>
#include <cstdint>
#include <string_view>

namespace nexus::gameplay {

enum class VolleyballPhase : std::uint8_t {
  kServe = 0,  // server is about to serve
  kRally = 1,  // ball in play — set/spike cycle
  kMatchOver = 2,
};

enum class SetType : std::uint8_t {
  kHigh = 0,   // slow, easier to hit
  kQuick = 1,  // fast, tighter timing window
  kBack = 2,   // back-set, surprise angle
};

class VolleyballRallyMode {
public:
  static constexpr int kPointsToWinSet = 25;
  static constexpr int kSetsToWinMatch = 2; // best of 3

  void reset();
  void update(double deltaSeconds);

  // serve: power [0,1], placement [-1 left … +1 right]
  auto serve(float power, float placement) -> Result<nlohmann::json>;
  // set: accuracy [0,1], set_type: "high" | "quick" | "back"
  auto set_(float accuracy, std::string_view setType) -> Result<nlohmann::json>;
  // spike: timing [0,1], power [0,1], angle: "line" | "cross" | "tip"
  auto spike(float timing, float power, std::string_view angle) -> Result<nlohmann::json>;

  [[nodiscard]] auto playerSets() const -> int32_t { return m_playerSets; }
  [[nodiscard]] auto opponentSets() const -> int32_t { return m_opponentSets; }
  [[nodiscard]] auto playerPoints() const -> int32_t { return m_playerPoints; }
  [[nodiscard]] auto opponentPoints() const -> int32_t { return m_opponentPoints; }
  [[nodiscard]] auto aces() const -> int32_t { return m_aces; }
  [[nodiscard]] auto kills() const -> int32_t { return m_kills; }
  [[nodiscard]] auto phase() const -> VolleyballPhase { return m_phase; }
  [[nodiscard]] auto isMatchOver() const -> bool { return m_phase == VolleyballPhase::kMatchOver; }
  [[nodiscard]] auto isVictory() const -> bool {
    return isMatchOver() && m_playerSets >= kSetsToWinMatch;
  }
  [[nodiscard]] auto stateJson() const -> nlohmann::json;

private:
  void awardPoint(bool playerWon);
  void checkSetEnd();
  [[nodiscard]] auto opponentDefendsSpike(float timing, std::string_view angle) const -> bool;
  [[nodiscard]] auto opponentReturnServe(float power, float placement) const -> bool;

  VolleyballPhase m_phase{VolleyballPhase::kServe};
  bool m_playerServing{true};
  int32_t m_playerPoints{0};
  int32_t m_opponentPoints{0};
  int32_t m_playerSets{0};
  int32_t m_opponentSets{0};
  int32_t m_totalRallies{0};
  int32_t m_aces{0};
  int32_t m_kills{0};
  int32_t m_blocks{0};     // successful opponent blocks
  int32_t m_digStreak{0};  // consecutive rally exchanges
  bool m_setReady{false};  // set() was called, spike may follow
  SetType m_pendingSet{SetType::kHigh};
};

} // namespace nexus::gameplay
