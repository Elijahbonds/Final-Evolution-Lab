// Spec §2.2 P0 — Dunk Contest charge → jump → dunk → score loop
#pragma once

#include <cstdint>
#include "nexus/core/result.h"
#include "nexus/gameplay/arcade_physics.h"
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

  void reset();
  void update(double deltaSeconds, const ArcadePhysicsParams& physics);

  auto onChargeBegin() -> Result<void>;
  auto onChargeRelease(float normalizedPower) -> Result<void>;
  auto onApexTap() -> Result<QTEGrade>;

  [[nodiscard]] auto playerScore() const -> int { return m_playerScore; }
  [[nodiscard]] auto opponentScore() const -> int { return m_opponentScore; }
  [[nodiscard]] auto phase() const -> DunkPhase { return m_phase; }
  [[nodiscard]] auto chargePower() const -> float { return m_chargePower; }
  [[nodiscard]] auto isMatchComplete() const -> bool { return m_phase == DunkPhase::kMatchWon; }
  [[nodiscard]] auto stateJson() const -> nlohmann::json;
  [[nodiscard]] auto dunkHistory() const -> const std::vector<DunkResult>& { return m_dunkHistory; }
  auto onRegisterSignature(const std::string& animationId, const nlohmann::json& keyframes) -> Result<void>;
  [[nodiscard]] auto signatureAnimationId() const -> const std::string& { return m_signatureAnimationId; }

private:
  [[nodiscard]] static auto styleMultiplier(DunkStyle style) -> float;
  [[nodiscard]] auto calculateDunkPoints(const DunkResult& dunk,
                                           const ArcadePhysicsParams& physics) const -> int;
  void completeDunk(const ArcadePhysicsParams& physics);

  DunkPhase m_phase{DunkPhase::kIdle};
  float m_chargePower{0.0F};
  float m_airTimeSeconds{0.0F};
  float m_phaseTimer{0.0F};
  int m_playerScore{0};
  int m_opponentScore{15};
  DunkStyle m_pendingStyle{DunkStyle::kStandard};
  QTESystem m_qte;
  QTEGrade m_lastApexGrade{QTEGrade::kMiss};
  std::vector<DunkResult> m_dunkHistory;
  std::string m_signatureAnimationId{""};
  nlohmann::json m_signatureKeyframes{nlohmann::json::array()};
};

} // namespace nexus::gameplay
