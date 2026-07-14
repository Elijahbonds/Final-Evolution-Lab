// FEL Story Mode — "Court Carnival: Legends of the Boardwalk"
//
// Design references:
//   Movement feel:  Kingdom Hearts 1 action RPG traversal — lock-on, action commands,
//                   platforming through themed worlds.  High PRQ pushes toward Sonic
//                   Adventure Battle 2 speed — sprint, rail grind, air boost.
//   Map streaming:  KH1 / God of War PSP portal loading — only the active stage zone
//                   geometry is hot in memory; others are suspended or unloaded.
//   Board game:     The court is a 3D board; rolling dice moves the player token
//                   across spaces.  Landing on a boss space triggers that zone's
//                   boss encounter.  Carnival/rail/flight spaces give mini-bonuses.
//
// Gameplay loop (one full run):
//   1. Player starts at boardwalk zone (kBoardwalk).
//   2. Roll dice → move token N spaces → land on space → resolve space effect.
//   3. Traverse to that space using run / rail grind / flight (PRQ-scaled speed).
//   4. Boss space: stage streams in, boss fight triggers (combat system).
//   5. Defeat all 4 zone bosses → Final Boss on kRooftopRow.
//   6. Story complete on final boss defeat.
#pragma once

#include "nexus/core/result.h"
#include "nexus/gameplay/arcade_physics.h"
#include "nexus/gameplay/arena_3d_space.h"
#include "nexus/gameplay/combat_system.h"
#include "nexus/gameplay/enemy_ai.h"
#include "nexus/gameplay/flight_system.h"
#include "nexus/gameplay/health_system.h"
#include "nexus/gameplay/prq_engine.h"
#include "nexus/gameplay/rail_grind_system.h"
#include "nexus/gameplay/stage_stream_manager.h"

#include <nlohmann/json.hpp>
#include <array>
#include <cstdint>
#include <optional>
#include <random>
#include <string>
#include <string_view>
#include <vector>

// GCC 13.3 workaround: forward-declare enum classes before large STL includes.
namespace nexus { namespace gameplay {
  enum class StoryPhase : std::uint8_t;
  enum class BoardSpaceType : std::uint8_t;
} } // namespace nexus::gameplay

namespace nexus::gameplay {

// ── Story phase machine ───────────────────────────────────────────────────────
enum class StoryPhase : std::uint8_t {
  kBoardTraversal = 0,  // rolling dice, moving token, exploring
  kRailSection    = 1,  // mid-traversal rail grind bonus
  kFlightSection  = 2,  // mid-traversal flight bonus
  kBossFight      = 3,  // boss encounter active
  kBossDefeated   = 4,  // brief victory moment before next roll
  kStageComplete  = 5,  // all bosses in a zone beaten
  kFinalBoss      = 6,  // rooftop row final encounter
  kStoryComplete  = 7,  // all bosses defeated — credits
};

// ── 3D board game space types ─────────────────────────────────────────────────
enum class BoardSpaceType : std::uint8_t {
  kCarnival  = 0,  // trigger a carnival mini-game (rolls bonus)
  kRailZone  = 1,  // rail grind section for score
  kFlightZone= 2,  // flight section for score
  kBossZone  = 3,  // triggers boss fight in this zone
  kBonus     = 4,  // flat FEL shard bonus
  kObstacle  = 5,  // take HP damage
};

// Board space — one tile on the 3D board
struct BoardSpace {
  BoardSpaceType type;
  Vec3           worldPos;    // centre position (metres, court-space)
  StageZoneId    zone;        // which streaming zone this tile belongs to
  float          bonusValue;  // shards for kBonus/kCarnival; damage for kObstacle
  bool           bossCleared; // once the boss here is defeated, stays false trigger
};

// 20-space board looping around the expanded Venice Beach court
inline constexpr std::array<BoardSpace, 20> kBoardSpaces{{
  // Zone: Boardwalk (spaces 0–4)
  { BoardSpaceType::kCarnival,   { 0.0F, 0.0F, -9.0F}, StageZoneId::kBoardwalk,   20.0F, false },
  { BoardSpaceType::kRailZone,   {-6.0F, 1.2F, -9.5F}, StageZoneId::kBoardwalk,   15.0F, false },
  { BoardSpaceType::kBonus,      {-12.0F,0.0F, -6.0F}, StageZoneId::kBoardwalk,   30.0F, false },
  { BoardSpaceType::kRailZone,   {-12.0F,1.2F,  0.0F}, StageZoneId::kBoardwalk,   15.0F, false },
  { BoardSpaceType::kObstacle,   {-12.0F,0.0F,  6.0F}, StageZoneId::kBoardwalk,   10.0F, false },

  // Zone: Court Floor (spaces 5–8)
  { BoardSpaceType::kCarnival,   { 0.0F, 0.0F,  7.8F}, StageZoneId::kCourtFloor,  20.0F, false },
  { BoardSpaceType::kBossZone,   { 0.0F, 0.0F,  0.0F}, StageZoneId::kCourtFloor,   0.0F, false },
  { BoardSpaceType::kBonus,      { 7.8F, 0.0F,  0.0F}, StageZoneId::kCourtFloor,  25.0F, false },
  { BoardSpaceType::kObstacle,   { 7.8F, 0.0F, -7.5F}, StageZoneId::kCourtFloor,  15.0F, false },

  // Zone: Skate Apron (spaces 9–12)
  { BoardSpaceType::kRailZone,   { 8.5F, 0.0F, -4.0F}, StageZoneId::kSkateApron,  15.0F, false },
  { BoardSpaceType::kFlightZone, { 8.5F, 0.6F,  4.5F}, StageZoneId::kSkateApron,  20.0F, false },
  { BoardSpaceType::kBossZone,   { 0.0F, 0.0F,  8.0F}, StageZoneId::kSkateApron,   0.0F, false },
  { BoardSpaceType::kBonus,      {-8.5F, 0.0F,  4.5F}, StageZoneId::kSkateApron,  25.0F, false },

  // Zone: Beach Access (spaces 13–16)
  { BoardSpaceType::kFlightZone, {-9.5F, 0.0F,  8.5F}, StageZoneId::kBeachAccess, 20.0F, false },
  { BoardSpaceType::kCarnival,   {-6.0F, 0.0F, 11.0F}, StageZoneId::kBeachAccess, 20.0F, false },
  { BoardSpaceType::kBossZone,   { 0.0F, 0.0F, 12.0F}, StageZoneId::kBeachAccess,  0.0F, false },
  { BoardSpaceType::kObstacle,   { 6.0F, 0.0F, 11.0F}, StageZoneId::kBeachAccess, 12.0F, false },

  // Zone: Rooftop Row (spaces 17–19)
  { BoardSpaceType::kRailZone,   { 6.0F, 5.5F,  0.0F}, StageZoneId::kRooftopRow,  15.0F, false },
  { BoardSpaceType::kFlightZone, { 0.0F, 6.5F,  0.0F}, StageZoneId::kRooftopRow,  25.0F, false },
  { BoardSpaceType::kBossZone,   {-6.0F, 5.5F,  0.0F}, StageZoneId::kRooftopRow,   0.0F, false },
}};

// Boss config per zone (matched by zone id order)
struct BossConfig {
  std::string_view name;
  float            maxHp;
  float            speedScale;
  float            aggression;
  std::string_view defeatedShard;  // reward shard type
};

inline constexpr std::array<BossConfig, 5> kZoneBosses{{
  { "Hype Master",      60.0F, 0.9F, 0.65F, "shard_carnival_hype"   },  // kBoardwalk (no boss on boardwalk — skip)
  { "The Lockdown",     80.0F, 1.0F, 0.80F, "shard_lockdown_key"    },  // kCourtFloor
  { "Grind King",       70.0F, 1.1F, 0.75F, "shard_grind_crown"     },  // kSkateApron
  { "Sunset Sentinel",  90.0F, 1.0F, 0.85F, "shard_sunset_seal"     },  // kBeachAccess
  { "The Architect",   120.0F, 1.2F, 0.95F, "shard_architect_core"  },  // kRooftopRow (final)
}};

// ─────────────────────────────────────────────────────────────────────────────
class StoryMode {
public:
  static constexpr int kBoardSpaceCount = 20;
  static constexpr int kBossCount = 4;  // excluding boardwalk; final boss separate

  void reset();
  void update(double deltaSeconds);

  // ── Board game commands ──────────────────────────────────────────────────
  // Roll dice → move token → return landing-space result.
  auto rollAndMove() -> Result<nlohmann::json>;

  // ── Traversal commands ──────────────────────────────────────────────────
  auto jump() -> Result<nlohmann::json>;
  auto activateFlight() -> Result<nlohmann::json>;
  auto triggerFlightBoost() -> Result<nlohmann::json>;
  auto tryGrindSnap(float playerX, float playerY, float playerZ) -> Result<nlohmann::json>;
  auto grindTrick(std::string_view trickName) -> Result<nlohmann::json>;
  auto exitGrind() -> Result<nlohmann::json>;

  // ── Combat commands (boss fight phase) ──────────────────────────────────
  auto bossCombat(CombatAction action) -> Result<nlohmann::json>;

  // Activate the boss zone for the current board space (if kBossZone and not cleared).
  auto enterBossZone() -> Result<nlohmann::json>;

  // ── Zone navigation ──────────────────────────────────────────────────────
  // Teleport / travel to a named zone (e.g. after landing on a kRailZone space).
  auto travelToZone(StageZoneId zone) -> Result<nlohmann::json>;

  // ── State accessors ──────────────────────────────────────────────────────
  [[nodiscard]] auto phase()          const -> StoryPhase { return m_phase; }
  [[nodiscard]] auto tokenPosition()  const -> int        { return m_tokenPos; }
  [[nodiscard]] auto totalShards()    const -> float      { return m_totalShards; }
  [[nodiscard]] auto bossesDefeated() const -> int        { return m_bossesDefeated; }
  [[nodiscard]] auto isComplete()     const -> bool       { return m_phase == StoryPhase::kStoryComplete; }
  [[nodiscard]] auto stateJson()      const -> nlohmann::json;

private:
  void resolveSpaceLanding(int spaceIndex);
  void checkStoryComplete();
  [[nodiscard]] auto currentPhysics() const -> ArcadePhysicsParams;
  [[nodiscard]] static auto spaceTypeLabel(BoardSpaceType t) -> const char*;
  [[nodiscard]] static auto storyPhaseLabel(StoryPhase p) -> const char*;

  StoryPhase      m_phase{StoryPhase::kBoardTraversal};
  int             m_tokenPos{0};        // current board space index (0–19)
  float           m_totalShards{0.0F};
  int             m_bossesDefeated{0};
  int             m_diceRolls{0};
  int             m_lastDice{0};

  HealthSystem    m_health;
  EnemyAI         m_boss;
  StageStreamManager m_streamMgr;
  RailGrindSystem m_rail;
  FlightSystem    m_flight;

  // Board-space defeat tracker (parallel to kBoardSpaces)
  std::array<bool, 20> m_spaceCleared{};
};

} // namespace nexus::gameplay
