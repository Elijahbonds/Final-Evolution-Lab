#include "nexus/gameplay/dunk_contest_mode.h"

#include <algorithm>
#include <cmath>

namespace nexus::gameplay {

namespace {

constexpr float kApproachSpeedMin = 6.0F;
constexpr float kApproachSpeedMax = 9.0F;
constexpr float kLaunchSpeedMin = 8.0F;
constexpr float kLaunchSpeedMax = 14.0F;
constexpr float kHangGravityScale = 0.65F;
constexpr float kChargeRate = 1.8F;

} // namespace

void DunkContestMode::reset() {
  m_phase = DunkPhase::kIdle;
  m_chargePower = 0.0F;
  m_airTimeSeconds = 0.0F;
  m_phaseTimer = 0.0F;
  m_playerScore = 0;
  m_opponentScore = 15;
  m_pendingStyle = DunkStyle::kStandard;
  m_dunkHistory.clear();
}

void DunkContestMode::update(double deltaSeconds, const ArcadePhysicsParams& physics) {
  m_phaseTimer += static_cast<float>(deltaSeconds);

  if (m_phase == DunkPhase::kCharging) {
    m_chargePower = std::clamp(m_chargePower + static_cast<float>(deltaSeconds) * kChargeRate,
                               0.0F,
                               1.0F);
    if (m_chargePower >= 0.85F) {
      m_pendingStyle = DunkStyle::kSignature;
    } else if (m_chargePower >= 0.65F) {
      m_pendingStyle = DunkStyle::kPower;
    } else if (m_chargePower >= 0.45F) {
      m_pendingStyle = DunkStyle::kFlashy;
    } else {
      m_pendingStyle = DunkStyle::kStandard;
    }
    return;
  }

  if (m_phase == DunkPhase::kLaunch) {
    if (m_phaseTimer >= 0.15F) {
      m_phase = DunkPhase::kAirborne;
      m_phaseTimer = 0.0F;
      m_airTimeSeconds = 0.0F;
      const float launchSpeed =
          kLaunchSpeedMin + (kLaunchSpeedMax - kLaunchSpeedMin) * m_chargePower;
      const float hangBase = launchSpeed / 9.81F;
      m_airTimeSeconds = hangBase * physics.hangTimeMultiplier * (1.0F / kHangGravityScale);
      m_qte.startApexWindow(std::max(0.35F, m_airTimeSeconds * 0.35F));
    }
    return;
  }

  if (m_phase == DunkPhase::kAirborne) {
    m_qte.update(deltaSeconds);
    m_airTimeSeconds = std::max(0.0F, m_airTimeSeconds - static_cast<float>(deltaSeconds));
    if (m_airTimeSeconds <= 0.0F || m_phaseTimer >= 1.2F) {
      completeDunk(physics);
    }
    return;
  }

  if (m_phase == DunkPhase::kScored && m_phaseTimer >= 0.35F) {
    m_phase = DunkPhase::kIdle;
    m_phaseTimer = 0.0F;
  }
}

auto DunkContestMode::onChargeBegin() -> Result<void> {
  if (m_phase == DunkPhase::kMatchWon) {
    return Result<void>::err("dunk contest already won");
  }
  if (m_phase != DunkPhase::kIdle && m_phase != DunkPhase::kScored) {
    return Result<void>::err("dunk charge only valid from idle");
  }
  m_phase = DunkPhase::kCharging;
  m_chargePower = 0.0F;
  m_phaseTimer = 0.0F;
  return Result<void>::ok();
}

auto DunkContestMode::onChargeRelease(float normalizedPower) -> Result<void> {
  if (m_phase != DunkPhase::kCharging) {
    return Result<void>::err("release requires active charge");
  }
  m_chargePower = std::clamp(normalizedPower > 0.0F ? normalizedPower : m_chargePower, 0.05F, 1.0F);
  m_phase = DunkPhase::kLaunch;
  m_phaseTimer = 0.0F;
  (void)kApproachSpeedMin;
  (void)kApproachSpeedMax;
  return Result<void>::ok();
}

auto DunkContestMode::onApexTap() -> Result<QTEGrade> {
  if (m_phase != DunkPhase::kAirborne) {
    return Result<QTEGrade>::ok(QTEGrade::kMiss);
  }
  const QTEGrade grade = m_qte.onTap();
  m_lastApexGrade = grade;
  return Result<QTEGrade>::ok(grade);
}

auto DunkContestMode::styleMultiplier(DunkStyle style) -> float {
  switch (style) {
  case DunkStyle::kFlashy:
    return 1.2F;
  case DunkStyle::kPower:
    return 1.3F;
  case DunkStyle::kSignature:
    return 1.5F;
  case DunkStyle::kStandard:
  default:
    return 1.0F;
  }
}

auto DunkContestMode::calculateDunkPoints(const DunkResult& dunk,
                                          const ArcadePhysicsParams& physics) const -> int {
  const float hangPoints = dunk.hangTimeSeconds * 2.0F * physics.hangTimeMultiplier;
  const float trickPoints = 2.0F * styleMultiplier(dunk.style);
  const float timingBonus = QTESystem::timingBonus(dunk.timingGrade);
  const int raw = static_cast<int>(std::round(hangPoints + trickPoints + timingBonus));
  return std::max(1, raw);
}

void DunkContestMode::completeDunk(const ArcadePhysicsParams& physics) {
  DunkResult dunk{};
  dunk.style = m_pendingStyle;
  dunk.hangTimeSeconds = std::max(0.4F, m_airTimeSeconds + m_phaseTimer * 0.25F);
  dunk.timingGrade = m_lastApexGrade;
  m_lastApexGrade = QTEGrade::kMiss;
  dunk.points = calculateDunkPoints(dunk, physics);
  if (!m_signatureAnimationId.empty()) {
    dunk.points += 2; // Custom signature dunk bonus
  }
  m_dunkHistory.push_back(dunk);
  m_playerScore += dunk.points;

  m_phase = DunkPhase::kScored;
  m_phaseTimer = 0.0F;

  if (m_playerScore >= kWinScore) {
    m_phase = DunkPhase::kMatchWon;
  }
}

auto DunkContestMode::onRegisterSignature(const std::string& animationId, const nlohmann::json& keyframes) -> Result<void> {
  m_signatureAnimationId = animationId;
  m_signatureKeyframes = keyframes;
  return Result<void>::ok();
}

auto DunkContestMode::stateJson() const -> nlohmann::json {
  nlohmann::json dunks = nlohmann::json::array();
  for (const DunkResult& dunk : m_dunkHistory) {
    dunks.push_back({
        {"style", static_cast<int>(dunk.style)},
        {"hang_time", dunk.hangTimeSeconds},
        {"timing_grade", QTESystem::gradeLabel(dunk.timingGrade)},
        {"points", dunk.points},
    });
  }

  return {
      {"phase", static_cast<int>(m_phase)},
      {"player_score", m_playerScore},
      {"opponent_score", m_opponentScore},
      {"charge_power", m_chargePower},
      {"win_target", kWinScore},
      {"match_complete", isMatchComplete()},
      {"dunk_details", std::move(dunks)},
      {"signature_animation_id", m_signatureAnimationId},
      {"signature_keyframes", m_signatureKeyframes},
  };
}

} // namespace nexus::gameplay
