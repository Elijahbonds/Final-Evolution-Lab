// Karate Endless — Naruto Storm-style 3D arena combat.
// Free movement + lock-on + chakra meter + jutsu special attacks + dynamic camera.
#pragma once

#include "nexus/core/result.h"
#include "nexus/gameplay/arena_3d_space.h"
#include "nexus/gameplay/combat_system.h"
#include "nexus/gameplay/enemy_ai.h"
#include "nexus/gameplay/health_system.h"
#include "nexus/gameplay/remote_player_state.h"
#include "nexus/gameplay/wave_spawner.h"

#include <nlohmann/json.hpp>
#include <array>
#include <cstdint>
#include <optional>
#include <string>
#include <vector>

// GCC 13.3 workaround: forward-declare enum classes before large STL includes.
namespace nexus { namespace gameplay {
  enum class KarateWavePhase : std::uint8_t;
} } // namespace nexus::gameplay

namespace nexus::gameplay {

enum class KarateWavePhase : std::uint8_t {
  kCombat       = 0,
  kIntermission = 1,
  kJutsu        = 2,  // player executing jutsu special — brief cinematic pause
  kVictory      = 3,
  kDefeat       = 4,
};

struct KaratePlayerSlot {
  HealthSystem health;
  int  comboChain{0};
  int  maxComboChain{0};
};

struct KaratePerkState {
  bool speed{false};
  bool power{false};
  bool guard{false};
};

// ── Camera3D ─────────────────────────────────────────────────────────────────
// COD-style tight over-the-shoulder TPS camera with optional lock-on.
// Default: orbits close behind the player at shoulder height (~1.8 m).
// Lock-on: stays behind player but looks toward the locked enemy.
// Jutsu: zooms in for a brief cinematic.
struct Camera3D {
  Vec3  position{0.0F, 1.8F, -4.0F};   // world-space camera pos
  Vec3  target{0.0F, 1.2F, 0.0F};      // look-at point
  float fovDegrees{75.0F};
  bool  cinematic{false};  // true during jutsu — renderer may add lens flare / blur

  // playerYaw: horizontal facing in degrees (0 = +Z). Used to orbit
  // camera behind the player in their local space.
  void trackPlayer(Vec3 playerPos, Vec3 lockedEnemyPos, bool hasLockOn,
                   bool jutsuing, float playerYaw, double dt) noexcept;
};

// ─────────────────────────────────────────────────────────────────────────────
class KarateEndlessMode {
public:
  static constexpr int   kMaxPlayers            = 4;
  static constexpr int   kTargetWave            = 10;
  static constexpr float kPlayerMoveSpeed       = 7.0F;   // m/s
  static constexpr float kDashSpeed             = 18.0F;  // m/s burst
  static constexpr float kDashDuration          = 0.18F;  // seconds
  static constexpr float kDashCooldown          = 0.6F;   // seconds
  static constexpr float kChakraPerHit          = 15.0F;
  static constexpr float kChakraPerCounter      = 25.0F;
  static constexpr float kChakraCostJutsu       = 80.0F;
  static constexpr float kChakraMax             = 100.0F;
  static constexpr float kJutsuHpDamage         = 80.0F;  // damages all nearby enemies

  void reset();
  void configureCoop(int playerCount);
  void update(double deltaSeconds);

  // ── Movement ──────────────────────────────────────────────────────────────
  // dx/dz each in [-1,1]. Moves the active player in 3D arena space.
  auto movePlayer(float dx, float dz, double deltaSeconds) -> Result<nlohmann::json>;

  // Directional dash — quick burst through enemies. Uses dash cooldown.
  // direction: "forward" | "back" | "left" | "right"
  auto dash(std::string_view direction) -> Result<nlohmann::json>;

  // ── Lock-on ───────────────────────────────────────────────────────────────
  // Cycles through alive enemies to lock camera and auto-face.
  // Call with no arg (or -1) to release lock.
  auto lockOn(int enemyIndex = -1) -> Result<nlohmann::json>;

  // ── Combat actions ────────────────────────────────────────────────────────
  auto performAction(CombatAction action, int playerIndex = -1) -> Result<CombatOutcome>;

  // ── Jutsu ─────────────────────────────────────────────────────────────────
  // Fires when chakra >= kChakraCostJutsu.  Cinematic one-shot to nearest enemy cluster.
  auto jutsu() -> Result<nlohmann::json>;

  // ── Wave / perk commands (legacy interface preserved) ─────────────────────
  auto handleWaveCommand(const nlohmann::json& params) -> Result<nlohmann::json>;

  [[nodiscard]] auto score()           const -> int   { return m_score; }
  [[nodiscard]] auto chakra()          const -> float { return m_chakra; }
  [[nodiscard]] auto jutsuReady()      const -> bool  { return m_chakra >= kChakraCostJutsu; }
  [[nodiscard]] auto comboMultiplier() const -> float { return m_comboMultiplier; }
  [[nodiscard]] auto isSessionOver()   const -> bool;
  [[nodiscard]] auto isVictory()       const -> bool { return m_phase == KarateWavePhase::kVictory; }
  [[nodiscard]] auto wavePhase()       const -> KarateWavePhase { return m_phase; }
  [[nodiscard]] auto stateJson()       const -> nlohmann::json;

  /// Apply an action event received from a remote / local-2P peer.
  /// action: "light_strike" | "heavy_strike" | "block" | "dodge" | "jutsu"
  void applyRemoteAction(std::string_view action);

  /// Register a remote player whose HP drives the player-vs-player overlay.
  /// Pass nullptr to revert to AI-only mode.
  void setRemoteOpponent(const RemotePlayerState* state);

private:
  void spawnActiveEnemies();
  void onEnemyDefeated();
  void onWaveCleared();
  void advanceActivePlayer();
  void updateEnemyAI(double dt);
  void updateCamera(double dt);

  [[nodiscard]] auto activeSlot()       -> KaratePlayerSlot&;
  [[nodiscard]] auto activeSlot() const -> const KaratePlayerSlot&;
  [[nodiscard]] auto allPlayersDefeated() const -> bool;
  [[nodiscard]] auto wavePhaseLabel()   const -> std::string_view;
  [[nodiscard]] auto scaledOpponentCount(int base) const -> int;
  [[nodiscard]] auto damageMultiplier()       const -> float;
  [[nodiscard]] auto damageTakenMultiplier()  const -> float;
  [[nodiscard]] auto lockedEnemyPos()         const -> std::optional<Vec3>;
  [[nodiscard]] auto nearestAliveEnemyIndex() const -> int;  // -1 if none

  // ── Player slots ──────────────────────────────────────────────────────────
  std::array<KaratePlayerSlot, kMaxPlayers> m_players{};
  int m_playerCount{1};
  int m_activePlayer{0};

  // ── Wave / enemies ────────────────────────────────────────────────────────
  WaveSpawner          m_waves;
  std::vector<EnemyAI> m_enemies;
  KaratePerkState      m_perks{};
  bool m_perkClaimedThisIntermission{false};

  // ── Game state ────────────────────────────────────────────────────────────
  KarateWavePhase m_phase{KarateWavePhase::kCombat};
  int   m_comboChain{0};
  int   m_maxComboChain{0};
  int   m_criticalHits{0};
  float m_comboMultiplier{1.0F};
  int   m_score{0};
  int   m_opponentsDefeated{0};

  // ── Naruto Storm mechanics ─────────────────────────────────────────────────
  float m_chakra{0.0F};
  int   m_lockedEnemyIndex{-1};
  float m_dashTimer{0.0F};        // time remaining in current dash burst
  float m_dashCooldownTimer{0.0F};
  Vec3  m_dashDirection{};

  // Jutsu phase timer — kJutsu phase lasts ~0.8 s (cinematic)
  float m_jutsuTimer{0.0F};
  static constexpr float kJutsuduration = 0.8F;

  // ── 3D world state ────────────────────────────────────────────────────────
  CharacterState3D m_player3D{{0.0F, 0.0F, -4.0F}};
  std::string      m_lastAnimAction{"idle"};
  std::array<CharacterState3D, kMaxPlayers> m_enemy3D{};
  Camera3D m_camera{};

  // ── Idle animation cycling ────────────────────────────────────────────────
  // Rotates through idle variants every kIdleVariantInterval seconds so the
  // character never stands perfectly still. Index cycles 0–3:
  //   0 = karate_idle_stance, 1 = idle_breathe, 2 = idle_stretch,
  //   3 = idle_shift_weight
  float m_idleTimer{0.0F};
  int   m_idleVariantIndex{0};
  static constexpr float kIdleVariantInterval = 5.0F;  // seconds between rotations

  // Non-owning pointer; null → AI-only, non-null → real remote peer overlay.
  const RemotePlayerState* m_remoteOpponent{nullptr};
};

} // namespace nexus::gameplay
