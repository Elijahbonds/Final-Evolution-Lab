// Court Carnival — Venice Beach party-board mini-game mash-up (court_carnival)
// Inspirator: Mario Party / WarioWare / Jackbox Party Pack
// Additions: star system (stars purchased at ATW spaces), item cards (Boost/Steal/Warp),
//            ShootingDrill and SpeedDribble mini-games, chaos event every 4th round.
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
#include <optional>
#include <string>

// GCC 13.3 workaround: forward-declare enum classes before large STL includes.
namespace nexus { namespace gameplay {
  enum class CarnivalPad       : std::uint8_t;
  enum class CarnivalPhase     : std::uint8_t;
  enum class CarnivalSpaceType : std::uint8_t;
  enum class CarnivalItemCard  : std::uint8_t;
} } // namespace nexus::gameplay

namespace nexus::gameplay {

enum class CarnivalPad : std::uint8_t {
  kTrickShot     = 0,
  kHotPotato     = 1,
  kRhythmBoard   = 2,
  kAtwLandmark   = 3,
  kShootingDrill = 4,  // new: timed 3-point shooting challenge (basketball-themed)
  kSpeedDribble  = 5,  // new: speed-dribble through cones against a ghost timer
};

enum class CarnivalPhase : std::uint8_t {
  kLobby       = 0,
  kActiveRound = 1,
  kRoundScored = 2,
  kChaosEvent  = 3,  // chaos event every 4th round
  kMatchWon    = 4,
};

// Board space type — what happens when your token lands here.
enum class CarnivalSpaceType : std::uint8_t {
  kTrickShot     = 0,
  kHotPotato     = 1,
  kRhythmBoard   = 2,
  kAtwLandmark   = 3,  // ATW landmark: purchase a star here (costs 5 dice points)
  kBonus         = 4,  // flat bonus points
  kObstacle      = 5,  // opponent scores 1 free point
  kShootingDrill = 6,  // new basketball-themed mini-game
  kSpeedDribble  = 7,  // new speed-dribble mini-game
};

// Item cards — one card max per player per round.
enum class CarnivalItemCard : std::uint8_t {
  kNone  = 0,
  kBoost = 1,  // Roll 2 dice, take the better result.
  kSteal = 2,  // Take 3 points from the leading player.
  kWarp  = 3,  // Teleport token to any ATW landmark space.
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
  { CarnivalSpaceType::kTrickShot,     { 6.5F, 0.0F,  0.0F},  0 },  // South baseline
  { CarnivalSpaceType::kAtwLandmark,   { 6.2F, 0.0F, -6.6F},  0 },  // Right corner (ATW_01)
  { CarnivalSpaceType::kShootingDrill, { 4.8F, 0.0F, -5.2F},  0 },  // Right wing (new)
  { CarnivalSpaceType::kRhythmBoard,   { 0.0F, 0.0F, -7.6F},  0 },  // North apron
  { CarnivalSpaceType::kHotPotato,     {-4.2F, 0.0F, -7.6F},  0 },  // North-west kiosk
  { CarnivalSpaceType::kObstacle,      {-5.6F, 0.0F,  0.0F},  0 },  // West free-throw
  { CarnivalSpaceType::kRhythmBoard,   {-4.2F, 0.0F,  7.6F},  0 },  // South-west kiosk
  { CarnivalSpaceType::kSpeedDribble,  { 0.0F, 0.0F,  7.6F},  0 },  // South apron (new)
  { CarnivalSpaceType::kAtwLandmark,   { 4.8F, 0.0F,  5.2F},  0 },  // Left wing (ATW_06)
  { CarnivalSpaceType::kTrickShot,     { 6.2F, 0.0F,  6.6F},  0 },  // Left corner
  { CarnivalSpaceType::kHotPotato,     { 0.0F, 0.0F,  0.0F},  0 },  // Top of key
  { CarnivalSpaceType::kBonus,         { 3.0F, 0.0F,  3.1F}, 10 },  // Left elbow bonus
}};

class CourtCarnivalMode {
public:
  static constexpr int kWinScore        = 15;
  static constexpr int kRoundsToWin     = 5;
  static constexpr int kBoardSpaceCount = 12;
  static constexpr int kStarCost        = 5;   // dice points spent to purchase a star at ATW
  static constexpr int kStarsToWin      = 3;   // stars required to win (Mario Party style)
  static constexpr int kChaosRoundInterval = 4; // every 4th round triggers a chaos event
  static constexpr int kItemStealAmount    = 3;  // points stolen from leader via Steal card

  void reset();
  void update(double deltaSeconds);

  auto triggerPad(CarnivalPad pad, float timingNormalized) -> Result<nlohmann::json>;

  // Roll dice AND move token on the 3D board.  Returns landing space info
  // (type, world position, triggered pad) so the caller knows what to resolve.
  auto rollDice() -> Result<nlohmann::json>;

  /// Buy a star at the current ATW space (costs kStarCost dice points accumulated).
  /// Only available when standing on an kAtwLandmark space.
  auto purchaseStar() -> Result<nlohmann::json>;

  /// Play an item card before rolling dice.
  auto playItemCard(CarnivalItemCard card) -> Result<nlohmann::json>;

  /// Bonus points when throw-catch pulse aligns with active hot-potato round.
  void onThrowPulse(const ThrowPulseEnvelope& pulse);

  [[nodiscard]] auto playerScore()     const -> int  { return m_playerScore; }
  [[nodiscard]] auto opponentScore()   const -> int  { return m_opponentScore; }
  [[nodiscard]] auto playerStars()     const -> int  { return m_playerStars; }
  [[nodiscard]] auto opponentStars()   const -> int  { return m_opponentStars; }
  [[nodiscard]] auto tokenPosition()   const -> int  { return m_tokenPos; }
  [[nodiscard]] auto playerItemCard()  const -> CarnivalItemCard { return m_playerCard; }
  [[nodiscard]] auto isMatchComplete() const -> bool {
    return m_phase == CarnivalPhase::kMatchWon;
  }
  [[nodiscard]] auto stateJson() const -> nlohmann::json;

private:
  [[nodiscard]] static auto padLabel(CarnivalPad pad)           -> const char*;
  [[nodiscard]] static auto spaceTypeLabel(CarnivalSpaceType t) -> const char*;
  [[nodiscard]] static auto cardLabel(CarnivalItemCard c)       -> const char*;
  [[nodiscard]] static auto spaceTopad(CarnivalSpaceType t)     -> CarnivalPad;
  [[nodiscard]] auto scorePad(CarnivalPad pad, float timingNormalized) -> int;
  void beginRound(CarnivalPad pad);
  void completeRound(int points);
  void resolveSpaceLanding(int spaceIndex);
  void triggerChaosEvent();
  void distributeItemCard();   // award a random item card to the player each round

  CarnivalPhase     m_phase{CarnivalPhase::kLobby};
  CarnivalPad       m_activePad{CarnivalPad::kTrickShot};
  CarnivalItemCard  m_playerCard{CarnivalItemCard::kNone};
  float m_phaseTimer{0.0F};
  float m_roundDurationSeconds{8.0F};
  int   m_playerScore{0};
  int   m_opponentScore{0};
  int   m_playerStars{0};
  int   m_opponentStars{0};
  int   m_roundsWon{0};
  int   m_diceRolls{0};
  int   m_lastDiceValue{0};
  int   m_tokenPos{0};
  int   m_roundCount{0};       // total rounds elapsed; tracks chaos event timing
  int   m_accumulatedDicePoints{0};  // running total for star purchase threshold
  std::uint32_t m_hotPotatoThrows{0};
};

} // namespace nexus::gameplay

