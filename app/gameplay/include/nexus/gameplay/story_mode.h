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
  std::string_view introQuote;     // displayed before fight
  std::string_view defeatedQuote;  // displayed on defeat
};

inline constexpr std::array<BossConfig, 5> kZoneBosses{{
  { "Hype Master",     60.0F, 0.9F, 0.65F, "shard_carnival_hype",
    "You think you belong on this court? Prove it.",
    "Not bad... the crowd's yours today."                                             },
  { "The Lockdown",    80.0F, 1.0F, 0.80F, "shard_lockdown_key",
    "Nobody drives through my lane. Nobody.",
    "You got heart. I'll give you that."                                              },
  { "Grind King",      70.0F, 1.1F, 0.75F, "shard_grind_crown",
    "The rails are mine. You can't hang at this speed.",
    "Smooth. Real smooth. Welcome to the Apron."                                     },
  { "Sunset Sentinel", 90.0F, 1.0F, 0.85F, "shard_sunset_seal",
    "You've come far, but the beach has teeth.",
    "The ocean saw it. So did I. You earned this."                                   },
  { "The Architect",  120.0F, 1.2F, 0.95F, "shard_architect_core",
    "I built every rule on this board. Let's see if you can break them all.",
    "The Boardwalk is yours now. Build something worth remembering."                 },
}};

// ─────────────────────────────────────────────────────────────────────────────
// NPC types inhabiting the boardwalk
// ─────────────────────────────────────────────────────────────────────────────
enum class StoryNpcType : std::uint8_t {
  kTrainer   = 0,  // teaches a move or gives a PRQ tip
  kVendor    = 1,  // sells gear (costs shards)
  kSpectator = 2,  // crowd flavor — cheers / reacts to your moves
  kRival     = 3,  // challenges you to a mini-game
};

struct StoryNpc {
  std::string_view id;
  std::string_view displayName;
  StoryNpcType     type;
  Vec3             worldPos;
  std::string_view greetLine;      // first thing they say
  std::string_view actionLine;     // shown when interaction is triggered
  float            interactRadius; // metres — must be within this to interact
  int              shardCost;      // 0 = free; vendor items cost shards
};

inline constexpr std::array<StoryNpc, 8> kBoardwalkNpcs{{
  { "npc_coach_ray",     "Coach Ray",   StoryNpcType::kTrainer,
    {-2.0F, 0.0F, -8.0F}, "Hit the rails and feel the flow.",
    "Hold Rail Snap for 0.3 s to snap to any nearby grind rail.",     3.5F, 0 },

  { "npc_keisha",        "Keisha",      StoryNpcType::kTrainer,
    { 2.5F, 0.0F, -8.0F}, "Jump, then activate Glide in the air.",
    "Double-tap Jump mid-air to activate KH1-style glide.",           3.5F, 0 },

  { "npc_shop_omar",     "Omar's Gear", StoryNpcType::kVendor,
    {-10.0F,0.0F, -5.0F}, "Fresh threads, fresh game.",
    "Unlock the 'Venice Legend' outfit for 150 shards.",              4.0F, 150 },

  { "npc_shop_dana",     "Dana's Lab",  StoryNpcType::kVendor,
    { 10.0F,0.0F, -5.0F}, "Stats matter. Let me upgrade you.",
    "Boost your Flight Energy cap for 200 shards.",                   4.0F, 200 },

  { "npc_rival_mitch",   "Mitch",       StoryNpcType::kRival,
    { 0.0F, 0.0F,  0.0F}, "Think you can out-grind me?",
    "Challenge: Rail trick score battle. 90 s. First to 300 wins.",   4.0F, 0 },

  { "npc_crowd_jess",    "Jess",        StoryNpcType::kSpectator,
    { 5.0F, 0.0F, -6.0F}, "That move was nasty! Do it again!",
    "",                                                                2.5F, 0 },

  { "npc_crowd_benji",   "Benji",       StoryNpcType::kSpectator,
    {-5.0F, 0.0F, -6.0F}, "I heard you already cleared the Apron. Respect.",
    "",                                                                2.5F, 0 },

  { "npc_photographer",  "Tanya",       StoryNpcType::kSpectator,
    { 0.0F, 0.0F, -11.0F},"Let me snap a photo. The lighting's perfect.",
    "You've been featured on the FEL Boardwalk Wall.",                 3.0F, 0 },
}};

// ─────────────────────────────────────────────────────────────────────────────
// Shard inventory (typed breakdown)
// ─────────────────────────────────────────────────────────────────────────────
struct ShardInventory {
  float carnival{0.0F};   // shard_carnival_hype rewards
  float combat{0.0F};     // boss fight victory shards
  float grind{0.0F};      // rail trick score shards
  float flight{0.0F};     // flight zone bonus shards
  float bonus{0.0F};      // flat bonus space shards

  [[nodiscard]] auto total() const -> float {
    return carnival + combat + grind + flight + bonus;
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// Story camera — 3rd-person follow cam (KH1-style)
// ─────────────────────────────────────────────────────────────────────────────
struct StoryCamera {
  Vec3  position{0.0F, 4.5F, -10.0F};  // world-space position
  Vec3  target{};                        // look-at point (usually player position + offset)
  float fovDegrees{65.0F};
  float yawDegrees{0.0F};   // horizontal orbit
  float pitchDegrees{-12.0F}; // slight downward tilt

  // Update to follow the player with a lazy orbit (soft-lock style).
  void follow(Vec3 playerPos, float playerYaw, double dt) noexcept;
};

// ─────────────────────────────────────────────────────────────────────────────
// Zone descriptions shown on first visit
// ─────────────────────────────────────────────────────────────────────────────
struct ZoneNarrative {
  std::string_view zoneName;
  std::string_view description;
  std::string_view objective;
};

inline constexpr std::array<ZoneNarrative, 5> kZoneNarratives{{
  { "The Boardwalk",
    "Venice Beach at golden hour. Locals run this stretch — you'll need to earn their respect.",
    "Explore the Boardwalk. Talk to Coach Ray and Keisha to learn the ropes." },
  { "Court Floor",
    "The main court. Every legend has passed through here. The Lockdown controls it.",
    "Find The Lockdown's Boss Zone and enter. Win the fight to claim the Court." },
  { "Skate Apron",
    "Concrete waves, steel rails, and the Grind King waiting at the top.",
    "Ride the rails. Score 300 on a grind run, then face the Grind King." },
  { "Beach Access",
    "Wide open sky meets the surf. The Sunset Sentinel guards the shoreline.",
    "Use the Flight Zone to soar. Reach the Sentinel's perch and settle this." },
  { "Rooftop Row",
    "The Architect's domain. Sky-high rails, impossible jumps, and the final test.",
    "Clear the rooftop rail and flight sections. Then face The Architect." },
}};

// ─────────────────────────────────────────────────────────────────────────────
// Active objective (updated on each space/boss resolution)
// ─────────────────────────────────────────────────────────────────────────────
struct StoryObjective {
  std::string text;
  std::string hint;         // optional gameplay hint
  bool        completed{false};

  void set(std::string_view t, std::string_view h = {}) {
    text      = std::string(t);
    hint      = std::string(h);
    completed = false;
  }
};

// ─────────────────────────────────────────────────────────────────────────────
class StoryMode {
public:
  static constexpr int kBoardSpaceCount = 20;
  static constexpr int kBossCount = 4;  // excluding boardwalk; final boss separate

  void reset();
  void update(double deltaSeconds);

  // ── Free movement (directional input between board actions) ─────────────
  // dx/dz: -1..+1 analogue stick values in world-space XZ plane.
  // Moves the player avatar, updates animation clip, advances camera.
  auto move(float dx, float dz) -> Result<nlohmann::json>;

  // ── NPC interaction ──────────────────────────────────────────────────────
  // Triggers the nearest NPC within interact radius. Returns dialogue + effect.
  auto interact() -> Result<nlohmann::json>;

  // ── Board game commands ──────────────────────────────────────────────────
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
  auto enterBossZone() -> Result<nlohmann::json>;

  // ── Zone navigation ──────────────────────────────────────────────────────
  auto travelToZone(StageZoneId zone) -> Result<nlohmann::json>;

  // ── State accessors ──────────────────────────────────────────────────────
  [[nodiscard]] auto phase()          const -> StoryPhase  { return m_phase; }
  [[nodiscard]] auto tokenPosition()  const -> int         { return m_tokenPos; }
  [[nodiscard]] auto totalShards()    const -> float       { return m_shards.total(); }
  [[nodiscard]] auto bossesDefeated() const -> int         { return m_bossesDefeated; }
  [[nodiscard]] auto isComplete()     const -> bool        { return m_phase == StoryPhase::kStoryComplete; }
  [[nodiscard]] auto stateJson()      const -> nlohmann::json;

private:
  void resolveSpaceLanding(int spaceIndex);
  void checkStoryComplete();
  void refreshObjective();
  [[nodiscard]] auto currentPhysics() const -> ArcadePhysicsParams;
  [[nodiscard]] static auto spaceTypeLabel(BoardSpaceType t) -> const char*;
  [[nodiscard]] static auto storyPhaseLabel(StoryPhase p) -> const char*;
  [[nodiscard]] auto nearestNpc() const -> const StoryNpc*;

  StoryPhase      m_phase{StoryPhase::kBoardTraversal};
  int             m_tokenPos{0};
  int             m_bossesDefeated{0};
  int             m_diceRolls{0};
  int             m_lastDice{0};

  ShardInventory  m_shards{};
  StoryObjective  m_objective{};
  StoryCamera     m_camera{};

  // Player avatar in 3D world space
  CharacterState3D m_player3D{};
  // Boss avatar (active during boss fight)
  CharacterState3D m_boss3D{};

  HealthSystem    m_health;
  EnemyAI         m_boss;
  StageStreamManager m_streamMgr;
  RailGrindSystem m_rail;
  FlightSystem    m_flight;

  std::array<bool, 20> m_spaceCleared{};
};

} // namespace nexus::gameplay
