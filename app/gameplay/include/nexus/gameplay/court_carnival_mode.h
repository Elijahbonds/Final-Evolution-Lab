// Court Carnival — Venice Beach party-board mini-game mash-up (court_carnival)
#pragma once

#include "nexus/core/result.h"
#include "nexus/gameplay/throw_catch_physics.h"

#include <nlohmann/json.hpp>
#include <cstdint>
#include <string>

// GCC 13.3 workaround: forward-declare enum classes before large STL includes.
namespace nexus { namespace gameplay {
  enum class CarnivalPad : std::uint8_t;
  enum class CarnivalPhase : std::uint8_t;
} } // namespace nexus::gameplay

namespace nexus::gameplay {

enum class CarnivalPad : std::uint8_t {
  kTrickShot = 0,
  kHotPotato = 1,
  kRhythmBoard = 2,
  kAtwLandmark = 3,
};

enum class CarnivalPhase : std::uint8_t {
  kLobby = 0,
  kActiveRound = 1,
  kRoundScored = 2,
  kMatchWon = 3,
};

class CourtCarnivalMode {
public:
  static constexpr int kWinScore = 15;
  static constexpr int kRoundsToWin = 5;

  void reset();
  void update(double deltaSeconds);

  auto triggerPad(CarnivalPad pad, float timingNormalized) -> Result<nlohmann::json>;
  auto rollDice() -> Result<nlohmann::json>;

  /// Bonus points when throw-catch pulse aligns with active hot-potato round.
  void onThrowPulse(const ThrowPulseEnvelope& pulse);

  [[nodiscard]] auto playerScore() const -> int { return m_playerScore; }
  [[nodiscard]] auto opponentScore() const -> int { return m_opponentScore; }
  [[nodiscard]] auto isMatchComplete() const -> bool {
    return m_phase == CarnivalPhase::kMatchWon;
  }
  [[nodiscard]] auto stateJson() const -> nlohmann::json;

private:
  [[nodiscard]] static auto padLabel(CarnivalPad pad) -> const char*;
  [[nodiscard]] auto scorePad(CarnivalPad pad, float timingNormalized) -> int;
  void beginRound(CarnivalPad pad);
  void completeRound(int points);

  CarnivalPhase m_phase{CarnivalPhase::kLobby};
  CarnivalPad m_activePad{CarnivalPad::kTrickShot};
  float m_phaseTimer{0.0F};
  float m_roundDurationSeconds{8.0F};
  int m_playerScore{0};
  int m_opponentScore{0};
  int m_roundsWon{0};
  int m_diceRolls{0};
  int m_lastDiceValue{0};
  std::uint32_t m_hotPotatoThrows{0};
};

} // namespace nexus::gameplay
