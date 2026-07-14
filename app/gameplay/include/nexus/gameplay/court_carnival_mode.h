// Court Carnival — Venice Beach party-board mini-game mash-up (court_carnival)
// Runs as a 3D board game: players roll dice, move their token across 12 spaces
// arranged around the court, and land on spaces that trigger mini-games.  Each
// space has a world-space position (in metres, court-space) so the renderer can
// animate the token hop.
#pragma once

#include "nexus/core/result.h"
#include "nexus/gameplay/arena_3d_space.h"
#include "nexus/gameplay/throw_catch_physics.h"

#include <nlohmann/json.hpp>
#include <array>
#include <cstdint>
#include <string>

// GCC 13.3 workaround: forward-declare enum classes before large STL includes.
namespace nexus { namespace gameplay {
  enum class CarnivalPad : std::uint8_t;
  enum class CarnivalPhase : std::uint8_t;
  enum class CarnivalSpaceType : std::uint8_t;
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

// Board space type — what happens when your token lands here.
enum class CarnivalSpaceType : std::uint8_t {
  kTrickShot   = 0,  // trigger the trick-shot pad mini-game
  kHotPotato   = 1,  // trigger hot-potato mini-game
  kRhythmBoard = 2,  // trigger rhythm-board mini-game
  kAtwLandmark = 3,  // around-the-world landmark challenge
  kBonus       = 4,  // flat bonus points (no pad game)
  kObstacle    = 5,  // opponent scores 1 free point
};

// A single space on the 3D board — world position + type.
struct CarnivalBoardSpace {
  CarnivalSpaceType type;
  Vec3              worldPos;   // metres, court-space (origin = centre logo)
  int               bonusValue; // extra points for kBonus; 0 otherwise
};

// 12-space board loop around the Venice Beach court.
// Positions derived from court_carnival_environment_layout.md (÷100 for metres).
inline constexpr std::array<CarnivalBoardSpace, 12> kCarnivalBoard{{
  { CarnivalSpaceType::kTrickShot,   { 6.5F, 0.0F,  0.0F},  0 },  // South baseline (CMP_04)
  { CarnivalSpaceType::kAtwLandmark, { 6.2F, 0.0F, -6.6F},  0 },  // Right corner (ATW_01)
  { CarnivalSpaceType::kBonus,       { 4.8F, 0.0F, -5.2F},  5 },  // Right wing bonus
  { CarnivalSpaceType::kRhythmBoard, { 0.0F, 0.0F, -7.6F},  0 },  // North apron (CMP_05)
  { CarnivalSpaceType::kHotPotato,   {-4.2F, 0.0F, -7.6F},  0 },  // North-west kiosk (CMP_01)
  { CarnivalSpaceType::kObstacle,    {-5.6F, 0.0F,  0.0F},  0 },  // West free-throw obstacle
  { CarnivalSpaceType::kRhythmBoard, {-4.2F, 0.0F,  7.6F},  0 },  // South-west kiosk (CMP_03)
  { CarnivalSpaceType::kBonus,       { 0.0F, 0.0F,  7.6F},  5 },  // South apron bonus (CMP_06)
  { CarnivalSpaceType::kAtwLandmark, { 4.8F, 0.0F,  5.2F},  0 },  // Left wing (ATW_06)
  { CarnivalSpaceType::kTrickShot,   { 6.2F, 0.0F,  6.6F},  0 },  // Left corner (ATW_07)
  { CarnivalSpaceType::kHotPotato,   { 0.0F, 0.0F,  0.0F},  0 },  // Top of key (ATW_04)
  { CarnivalSpaceType::kBonus,       { 3.0F, 0.0F,  3.1F}, 10 },  // Left elbow bonus
}};

class CourtCarnivalMode {
public:
  static constexpr int kWinScore       = 15;
  static constexpr int kRoundsToWin    = 5;
  static constexpr int kBoardSpaceCount = 12;

  void reset();
  void update(double deltaSeconds);

  auto triggerPad(CarnivalPad pad, float timingNormalized) -> Result<nlohmann::json>;

  // Roll dice AND move token on the 3D board.  Returns landing space info
  // (type, world position, triggered pad) so the caller knows what to resolve.
  auto rollDice() -> Result<nlohmann::json>;

  /// Bonus points when throw-catch pulse aligns with active hot-potato round.
  void onThrowPulse(const ThrowPulseEnvelope& pulse);

  [[nodiscard]] auto playerScore()     const -> int { return m_playerScore; }
  [[nodiscard]] auto opponentScore()   const -> int { return m_opponentScore; }
  [[nodiscard]] auto tokenPosition()   const -> int { return m_tokenPos; }
  [[nodiscard]] auto isMatchComplete() const -> bool {
    return m_phase == CarnivalPhase::kMatchWon;
  }
  [[nodiscard]] auto stateJson() const -> nlohmann::json;

private:
  [[nodiscard]] static auto padLabel(CarnivalPad pad) -> const char*;
  [[nodiscard]] static auto spaceTypeLabel(CarnivalSpaceType t) -> const char*;
  [[nodiscard]] static auto spaceTopad(CarnivalSpaceType t) -> CarnivalPad;
  [[nodiscard]] auto scorePad(CarnivalPad pad, float timingNormalized) -> int;
  void beginRound(CarnivalPad pad);
  void completeRound(int points);
  void resolveSpaceLanding(int spaceIndex);

  CarnivalPhase m_phase{CarnivalPhase::kLobby};
  CarnivalPad   m_activePad{CarnivalPad::kTrickShot};
  float         m_phaseTimer{0.0F};
  float         m_roundDurationSeconds{8.0F};
  int           m_playerScore{0};
  int           m_opponentScore{0};
  int           m_roundsWon{0};
  int           m_diceRolls{0};
  int           m_lastDiceValue{0};
  int           m_tokenPos{0};            // current space index (0–11)
  std::uint32_t m_hotPotatoThrows{0};
};

} // namespace nexus::gameplay

