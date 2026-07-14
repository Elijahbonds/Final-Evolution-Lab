// Full 3D soccer mode — 3v3 half-field with ball physics, ghost defenders, and
// a scoring goal at z = kFieldDepth/2.  Replaces OutcomeSportMode for "soccer".
#pragma once

#include <cstdint>

// GCC 13.3 workaround: forward-declare enum classes before large STL includes.
namespace nexus { namespace gameplay {
  enum class SoccerPhase : std::uint8_t;
} } // namespace nexus::gameplay

#include "nexus/core/result.h"
#include "nexus/gameplay/arena_3d_space.h"
#include "nexus/gameplay/remote_player_state.h"

#include <nlohmann/json.hpp>
#include <array>
#include <cstdint>

namespace nexus::gameplay {

enum class SoccerPhase : std::uint8_t {
  kKickoff   = 0,
  kActive    = 1,
  kGoal      = 2,   // brief celebration pause
  kOpGoal    = 3,   // opponent scored
  kMatchOver = 4,
};

// Ghost defender AI — simple line-of-sight chaser
struct SoccerDefender {
  Vec3  position{};
  float speed{5.0F};
  bool  engaged{false};   // within tackle range

  void update(Vec3 ballPos, double dt) noexcept;
};

class SoccerMode {
public:
  static constexpr int kGoalsToWin  = 3;
  static constexpr int kDefenders   = 3;

  // Field: 40 m wide (x), 25 m deep (z); goal at z = +12.5 m
  static constexpr float kFieldHalfW = 20.0F;
  static constexpr float kFieldHalfD = 12.5F;
  static constexpr Vec3  kGoalCenter { 0.0F, 0.0F,  12.5F };
  static constexpr Vec3  kKickoffPos { 0.0F, 0.0F,  -6.0F };
  static constexpr float kGoalWidth  = 7.32F;  // FIFA standard

  void reset();
  void update(double deltaSeconds);

  // ── Player actions ────────────────────────────────────────────────────────
  // move: dx/dz in [-1,1] — drives player position on the field
  auto move(float dx, float dz) -> Result<nlohmann::json>;
  // shoot: power in [0,1]; direction offset [-1,1]
  auto shoot(float power, float direction) -> Result<nlohmann::json>;
  // pass: short lateral pass to a virtual teammate
  auto pass(float direction) -> Result<nlohmann::json>;
  // tackle: slide tackle the nearest defender
  auto tackle() -> Result<nlohmann::json>;
  // header: jump header when ball is in the air
  auto header() -> Result<nlohmann::json>;

  [[nodiscard]] auto stateJson() const -> nlohmann::json;
  [[nodiscard]] auto isMatchOver() const -> bool { return m_phase == SoccerPhase::kMatchOver; }
  [[nodiscard]] auto playerGoals() const -> int { return m_playerGoals; }
  [[nodiscard]] auto opponentGoals() const -> int { return m_opGoals; }

  /// Apply a goal event received from a remote / local-2P opponent.
  void applyRemoteGoal();

  /// Apply an authoritative state sync from the host peer.
  void applyRemoteStateSync(const nlohmann::json& state);

  /// Register a remote player whose goals drive the opponent slot instead of
  /// ghost pressure AI.  Pass nullptr to revert to ghost AI.
  void setRemoteOpponent(const RemotePlayerState* state);

private:
  void resetKickoff();
  void spawnDefenders();
  void updateDefenders(double dt);
  void updateBallPhysics(double dt);
  [[nodiscard]] auto isShotOnTarget(float direction) const -> bool;
  [[nodiscard]] auto nearestDefenderDist() const -> float;

  SoccerPhase m_phase{SoccerPhase::kKickoff};
  float m_phaseTimer{0.0F};

  CharacterState3D m_player{kKickoffPos};
  Vec3  m_ballPos{kKickoffPos};
  Vec3  m_ballVelocity{};
  bool  m_playerHasBall{true};

  std::array<SoccerDefender, kDefenders> m_defenders{};
  int m_playerGoals{0};
  int m_opGoals{0};
  int m_matchTick{0};
  float m_lastAction{0.0F};  // seconds since last player action (opponent pressure timer)

  // Non-owning pointer; null → ghost AI, non-null → real remote peer.
  const RemotePlayerState* m_remoteOpponent{nullptr};
};

} // namespace nexus::gameplay
