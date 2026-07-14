// Spec §2.2 P0 — Dunk Contest charge → jump → dunk → score loop
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
  // Signature dunk library — mo-cap replacements, free-asset clip names
  k360Scoop           = 4,  // dunk_360_scoop           — 1.8× pts
  k360Eastbay         = 5,  // dunk_360_eastbay          — 2.0× pts
  k360FakeEastbay     = 6,  // dunk_360_fake_eastbay     — 1.6× pts
  kOffBackboardWindmill = 7, // dunk_off_board_windmill  — 2.2× pts
};

enum class DunkPhase : std::uint8_t {
  kIdle = 0,
  kCharging = 1,
  kLaunch = 2,
  kAirborne = 3,
  kScored = 4,
  kMatchWon = 5,
};

struct DunkResult {
  DunkStyle style{DunkStyle::kStandard};
  float hangTimeSeconds{0.0F};
  QTEGrade timingGrade{QTEGrade::kMiss};
  int points{0};
};

class DunkContestMode {
public:
  static constexpr int kWinScore = 21;

  // Hoop position in 3D court space (NBA standard: 3.05 m height, baseline z = 0)
  static constexpr Vec3 kHoopPos{0.0F, 3.05F, 0.0F};
  // Player starts their approach from the paint edge
  static constexpr Vec3 kApproachStartPos{0.0F, 0.0F, -10.0F};

  void reset();
  void update(double deltaSeconds, const ArcadePhysicsParams& physics);

  auto onChargeBegin() -> Result<void>;
  auto onChargeRelease(float normalizedPower) -> Result<void>;
  auto onApexTap() -> Result<QTEGrade>;
  // Select a signature dunk style before charging.  Returns error if style
  // is not one of the k360* / kOffBackboard variants.
  auto selectSignatureDunk(DunkStyle style) -> Result<void>;

  [[nodiscard]] auto playerScore() const -> int { return m_playerScore; }
  [[nodiscard]] auto opponentScore() const -> int { return m_opponentScore; }
  [[nodiscard]] auto phase() const -> DunkPhase { return m_phase; }
  [[nodiscard]] auto chargePower() const -> float { return m_chargePower; }
  [[nodiscard]] auto isMatchComplete() const -> bool { return m_phase == DunkPhase::kMatchWon; }
  [[nodiscard]] auto stateJson() const -> nlohmann::json;
  [[nodiscard]] auto dunkHistory() const -> const std::vector<DunkResult>& { return m_dunkHistory; }
  auto onRegisterSignature(const std::string& animationId, const nlohmann::json& keyframes) -> Result<void>;
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

  DunkPhase m_phase{DunkPhase::kIdle};
  float m_chargePower{0.0F};
  float m_airTimeSeconds{0.0F};
  float m_phaseTimer{0.0F};
  int m_playerScore{0};
  int m_opponentScore{0};
  float m_ghostTimer{0.0F};
  int m_ghostDunks{0};
  DunkStyle m_pendingStyle{DunkStyle::kStandard};
  QTESystem m_qte;
  QTEGrade m_lastApexGrade{QTEGrade::kMiss};
  std::vector<DunkResult> m_dunkHistory;
  std::string m_signatureAnimationId{""};
  nlohmann::json m_signatureKeyframes{nlohmann::json::array()};

  // 3D state — drives renderer positioning and animation
  CharacterState3D m_player3D{kApproachStartPos};
  CharacterState3D m_opponent3D{{4.0F, 0.0F, -10.0F}};
};

} // namespace nexus::gameplay
