#include "nexus/gameplay/dunk_contest_mode.h"
#include "nexus/gameplay/character_anim_state.h"

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
// Ghost opponent dunks roughly every 7 seconds of idle time, scoring 2–4 pts each dunk.
constexpr float kGhostDunkInterval = 7.0F;

} // namespace

void DunkContestMode::reset() {
  m_phase = DunkPhase::kIdle;
  m_chargePower = 0.0F;
  m_airTimeSeconds = 0.0F;
  m_phaseTimer = 0.0F;
  m_playerScore = 0;
  m_opponentScore = 0;
  m_ghostTimer = 0.0F;
  m_ghostDunks = 0;
  m_pendingStyle = DunkStyle::kStandard;
  m_dunkHistory.clear();
  m_player3D = CharacterState3D{kApproachStartPos};
  m_player3D.setClip(std::string(clips::kDunkApproach));
  m_opponent3D = CharacterState3D{{4.0F, 0.0F, -10.0F}};
  m_opponent3D.setClip(std::string(clips::kDunkApproach));
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
    // Return player to approach start
    m_player3D = CharacterState3D{kApproachStartPos};
    m_player3D.setClip(std::string(clips::kDunkApproach));
  }

  // Ghost opponent dunks during idle time to create real score pressure.
  if (m_phase == DunkPhase::kIdle && m_phase != DunkPhase::kMatchWon) {
    m_ghostTimer += static_cast<float>(deltaSeconds);
    if (m_ghostTimer >= kGhostDunkInterval) {
      m_ghostTimer = 0.0F;
      advanceGhostOpponent();
    }
  }

  // Update 3D positions every frame
  update3DPositions(deltaSeconds);
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
  case DunkStyle::kFlashy:           return 1.2F;
  case DunkStyle::kPower:            return 1.3F;
  case DunkStyle::kSignature:        return 1.5F;
  case DunkStyle::k360Scoop:         return 1.8F;
  case DunkStyle::k360Eastbay:       return 2.0F;
  case DunkStyle::k360FakeEastbay:   return 1.6F;
  case DunkStyle::kOffBackboardWindmill: return 2.2F;
  case DunkStyle::kStandard:
  default:                           return 1.0F;
  }
}

auto DunkContestMode::styleAnimClip(DunkStyle style) -> std::string_view {
  switch (style) {
  case DunkStyle::k360Scoop:             return clips::kDunk360Scoop;
  case DunkStyle::k360Eastbay:           return clips::kDunk360Eastbay;
  case DunkStyle::k360FakeEastbay:       return clips::kDunk360FakeEastbay;
  case DunkStyle::kOffBackboardWindmill: return clips::kDunkOffBoardWindmill;
  default:                               return clips::kDunkAirborne;
  }
}

auto DunkContestMode::selectSignatureDunk(DunkStyle style) -> Result<void> {
  if (style < DunkStyle::k360Scoop) {
    return Result<void>::err("use k360Scoop, k360Eastbay, k360FakeEastbay, or kOffBackboardWindmill");
  }
  if (m_phase != DunkPhase::kIdle) {
    return Result<void>::err("select signature dunk from idle phase only");
  }
  m_pendingStyle = style;
  return Result<void>::ok();
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

void DunkContestMode::update3DPositions(double deltaSeconds) {
  constexpr float kApproachSpeed = 7.5F;  // m/s toward hoop
  constexpr float kJumpLaunchVy  = 7.0F;  // vertical launch velocity m/s
  constexpr float kGravity       = 9.81F;

  switch (m_phase) {
  case DunkPhase::kIdle:
    m_player3D.setClip(std::string(clips::kDunkApproach));
    break;

  case DunkPhase::kCharging:
    // Player gathers at start position
    m_player3D.setClip(std::string(clips::kDunkCharge));
    break;

  case DunkPhase::kLaunch:
    // Sprint toward hoop
    m_player3D.moveToward(kHoopPos, kApproachSpeed, deltaSeconds);
    m_player3D.setClip(std::string(clips::kDunkLaunch), false);
    // Launch vertical
    if (m_player3D.velocity.y == 0.0F) {
      m_player3D.velocity.y = kJumpLaunchVy * m_chargePower;
    }
    break;

  case DunkPhase::kAirborne: {
    // Apply gravity + lateral approach toward hoop
    m_player3D.applyGravity(kGravity, deltaSeconds);
    m_player3D.moveToward({kHoopPos.x, m_player3D.position.y, kHoopPos.z},
                          kApproachSpeed, deltaSeconds);
    const std::string sigClip = std::string(styleAnimClip(m_pendingStyle));
    m_player3D.setClip(sigClip, false);
    break;
  }

  case DunkPhase::kScored:
    m_player3D.position = kHoopPos + Vec3{0.0F, -kHoopPos.y, 0.3F};
    m_player3D.velocity = {};
    m_player3D.setClip(std::string(clips::kDunkScore), false);
    break;

  case DunkPhase::kMatchWon:
    m_player3D.setClip(std::string(clips::kDunkScore), false, 0.7F);
    break;
  }
}

(const std::string& animationId, const nlohmann::json& keyframes) -> Result<void> {
  m_signatureAnimationId = animationId;
  m_signatureKeyframes = keyframes;
  return Result<void>::ok();
}

void DunkContestMode::advanceGhostOpponent() {
  if (m_phase == DunkPhase::kMatchWon) {
    return;
  }
  // Ghost opponent skill scales with each successive dunk: early dunks score 2 pts,
  // later dunks may score 3–4 pts to mount pressure as the match progresses.
  const int base = 2 + std::min(m_ghostDunks / 3, 2);
  m_opponentScore += base;
  ++m_ghostDunks;
  if (m_opponentScore >= kWinScore) {
    m_phase = DunkPhase::kMatchWon;
  }
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
      {"ghost_dunks", m_ghostDunks},
      // 3D environment — renderer uses these to position & animate characters
      {"player_3d", {
          {"x", m_player3D.position.x},
          {"y", m_player3D.position.y},
          {"z", m_player3D.position.z},
          {"yaw", m_player3D.yawDegrees},
          {"anim_clip", m_player3D.animClip.name},
          {"anim_loop", m_player3D.animClip.loop},
          {"anim_speed", m_player3D.animClip.speedScale},
      }},
      {"opponent_3d", {
          {"x", m_opponent3D.position.x},
          {"y", m_opponent3D.position.y},
          {"z", m_opponent3D.position.z},
          {"yaw", m_opponent3D.yawDegrees},
          {"anim_clip", m_opponent3D.animClip.name},
      }},
      {"hoop_3d", {
          {"x", kHoopPos.x},
          {"y", kHoopPos.y},
          {"z", kHoopPos.z},
      }},
  };
}

} // namespace nexus::gameplay
