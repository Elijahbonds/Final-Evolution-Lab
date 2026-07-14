// Spec §2.2 P0 — Dunk Contest: free court movement, charge → launch → dunk → score
#pragma once

#include <cstdint>

// GCC 13.3 workaround: forward-declare enum classes before large STL includes.
namespace nexus { namespace gameplay {
  enum class DunkStyle : std::uint8_t;
  enum class DunkPhase : std::uint8_t;
} } // namespace nexus::gameplay

#include "nexus/core/result.h"
#include "nexus/gameplay/arcade_physics.h"
#include "nexus/gameplay/arena_3d_space.h"
#include "nexus/gameplay/qte_system.h"

#include <nlohmann/json.hpp>
#include <string>
#include <vector>

namespace nexus::gameplay {

enum class DunkStyle : std::uint8_t {
  kStandard = 0,
  kFlashy = 1,
  kPower = 2,
  kSignature = 3,
  // Signature dunk library — free-asset clip names (Meshy/Mixamo)
  k360Scoop             = 4,  // dunk_360_scoop            — 1.8× pts
  k360Eastbay           = 5,  // dunk_360_eastbay           — 2.0× pts
  k360FakeEastbay       = 6,  // dunk_360_fake_eastbay      — 1.6× pts
  kOffBackboardWindmill = 7,  // dunk_off_board_windmill    — 2.2× pts
};

enum class DunkPhase : std::uint8_t {
  kFreeDribble  = 0,  // player moves freely on court before committing
  kCharging     = 1,  // charge button held — gathering power at current pos
  kLaunch       = 2,  // released — sprinting toward hoop
  kAirborne     = 3,  // in the air — apex QTE window
  kScored       = 4,  // brief celebration
  kMatchWon     = 5,
};

struct DunkResult {
  DunkStyle style{DunkStyle::kStandard};
  float hangTimeSeconds{0.0F};
  QTEGrade timingGrade{QTEGrade::kMiss};
  int points{0};
  float launchDistanceMeters{0.0F};  // how far player was from hoop at launch
};

class DunkContestMode {
public:
  static constexpr int kWinScore = 21;

  // Court geometry (half-court): hoop at baseline z=0, player dribbles in z<0 zone
  static constexpr Vec3  kHoopPos        { 0.0F, 3.05F,  0.0F };
  static constexpr float kCourtHalfWidth { 7.5F };   // NBA lane is ~3.66 m wide; give some room
  static constexpr float kCourtDepth     {-14.0F};   // how far back the player can dribble
  static constexpr float kDribbleSpeed   { 6.0F };   // m/s walking/dribbling
  static constexpr float kApproachSpeed  { 9.5F };   // m/s sprint to hoop after launch

  void reset();
  void update(double deltaSeconds, const ArcadePhysicsParams& physics);

  // ── Free-movement dribble ─────────────────────────────────────────────────
  // dx/dz each in [-1, 1] — drives player on court while in kFreeDribble phase.
  // Returns current stateJson so the renderer can update position immediately.
  auto movePlayer(float dx, float dz, double deltaSeconds) -> Result<nlohmann::json>;

  // ── Dunk sequence ─────────────────────────────────────────────────────────
  // Call from any position during kFreeDribble. Locks position and starts charge.
  auto onChargeBegin() -> Result<void>;
  auto onChargeRelease(float normalizedPower) -> Result<void>;
  auto onApexTap() -> Result<QTEGrade>;

  // Select a signature dunk before (or right as) you start charging.
  auto selectSignatureDunk(DunkStyle style) -> Result<void>;

  // Load custom dunk animation (from user's saved dunk library)
  auto onRegisterSignature(const std::string& animationId,
                           const nlohmann::json& keyframes) -> Result<void>;

  [[nodiscard]] auto playerScore()  const -> int       { return m_playerScore; }
  [[nodiscard]] auto opponentScore()const -> int       { return m_opponentScore; }
  [[nodiscard]] auto phase()        const -> DunkPhase { return m_phase; }
  [[nodiscard]] auto chargePower()  const -> float     { return m_chargePower; }
  [[nodiscard]] auto isMatchComplete() const -> bool   { return m_phase == DunkPhase::kMatchWon; }
  [[nodiscard]] auto stateJson()    const -> nlohmann::json;
  [[nodiscard]] auto dunkHistory()  const -> const std::vector<DunkResult>& { return m_dunkHistory; }
  [[nodiscard]] auto signatureAnimationId() const -> const std::string& { return m_signatureAnimationId; }
  [[nodiscard]] auto playerState3D() const -> const CharacterState3D& { return m_player3D; }

private:
  [[nodiscard]] static auto styleMultiplier(DunkStyle style) -> float;
  [[nodiscard]] static auto styleAnimClip(DunkStyle style) -> std::string_view;
  [[nodiscard]] auto calculateDunkPoints(const DunkResult& dunk,
                                         const ArcadePhysicsParams& physics) const -> int;
  void completeDunk(const ArcadePhysicsParams& physics);
  void advanceGhostOpponent();
  void update3DPositions(double deltaSeconds);
  void clampPlayerToCourtBounds();

  DunkPhase m_phase{DunkPhase::kFreeDribble};
  float m_chargePower{0.0F};
  float m_airTimeSeconds{0.0F};
  float m_phaseTimer{0.0F};
  int   m_playerScore{0};
  int   m_opponentScore{0};
  float m_ghostTimer{0.0F};
  int   m_ghostDunks{0};
  DunkStyle m_pendingStyle{DunkStyle::kStandard};
  QTESystem m_qte;
  QTEGrade  m_lastApexGrade{QTEGrade::kMiss};
  std::vector<DunkResult> m_dunkHistory;
  std::string m_signatureAnimationId{""};
  nlohmann::json m_signatureKeyframes{nlohmann::json::array()};

  // 3D court state
  CharacterState3D m_player3D{{0.0F, 0.0F, -8.0F}};   // start mid-paint
  CharacterState3D m_opponent3D{{3.5F, 0.0F, -8.0F}}; // ghost opponent on opposite side
};

} // namespace nexus::gameplay
