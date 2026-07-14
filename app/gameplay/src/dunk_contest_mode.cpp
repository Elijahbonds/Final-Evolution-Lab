#include "nexus/gameplay/dunk_contest_mode.h"
#include "nexus/gameplay/character_anim_state.h"

#include <algorithm>
#include <cmath>
#include <string>

namespace nexus::gameplay {

namespace {

constexpr float kChargeRate        = 1.8F;
constexpr float kHangGravityScale  = 0.65F;
constexpr float kLaunchSpeedMin    = 8.0F;
constexpr float kLaunchSpeedMax    = 14.0F;
constexpr float kGhostDunkInterval = 7.0F;  // ghost dunks every 7 s

} // namespace

// ─────────────────────────────────────────────────────────────────────────────
void DunkContestMode::reset() {
  m_phase           = DunkPhase::kFreeDribble;
  m_chargePower     = 0.0F;
  m_airTimeSeconds  = 0.0F;
  m_phaseTimer      = 0.0F;
  m_playerScore     = 0;
  m_opponentScore   = 0;
  m_ghostTimer      = 0.0F;
  m_ghostDunks      = 0;
  m_pendingStyle    = DunkStyle::kStandard;
  m_dunkHistory.clear();
  m_player3D   = CharacterState3D{{0.0F, 0.0F, -8.0F}};
  m_player3D.setClip(std::string(clips::kDunkApproach));
  m_opponent3D = CharacterState3D{{3.5F, 0.0F, -8.0F}};
  m_opponent3D.setClip(std::string(clips::kDunkApproach));
}

// ─────────────────────────────────────────────────────────────────────────────
auto DunkContestMode::movePlayer(float dx, float dz, double deltaSeconds) -> Result<nlohmann::json> {
  if (m_phase != DunkPhase::kFreeDribble) {
    return Result<nlohmann::json>::err("move only available while dribbling");
  }
  // Normalise input so diagonal isn't faster
  const float len = std::sqrt(dx * dx + dz * dz);
  if (len > 1e-4F) {
    dx /= len;
    dz /= len;
  }
  const float dt = static_cast<float>(deltaSeconds);
  m_player3D.position.x += dx * kDribbleSpeed * dt;
  m_player3D.position.z += dz * kDribbleSpeed * dt;
  clampPlayerToCourtBounds();

  // Facing — dribble always faces toward hoop (z = 0)
  const Vec3 toHoop = (kHoopPos - m_player3D.position).normalized();
  if (toHoop.x != 0.0F || toHoop.z != 0.0F) {
    m_player3D.yawDegrees = std::atan2(toHoop.x, toHoop.z) * (180.0F / 3.14159265F);
  }

  const bool moving = len > 0.05F;
  m_player3D.setClip(moving ? std::string(clips::kDunkApproach) : std::string(clips::kIdle));

  return Result<nlohmann::json>::ok(stateJson());
}

// ─────────────────────────────────────────────────────────────────────────────
void DunkContestMode::clampPlayerToCourtBounds() {
  m_player3D.position.x = std::max(-kCourtHalfWidth,
                           std::min(m_player3D.position.x, kCourtHalfWidth));
  m_player3D.position.z = std::max(kCourtDepth,
                           std::min(m_player3D.position.z, -0.5F)); // can't walk past hoop
}

// ─────────────────────────────────────────────────────────────────────────────
auto DunkContestMode::onChargeBegin() -> Result<void> {
  if (m_phase == DunkPhase::kMatchWon) {
    return Result<void>::err("dunk contest already won");
  }
  if (m_phase != DunkPhase::kFreeDribble && m_phase != DunkPhase::kScored) {
    return Result<void>::err("charge only from dribble or after scoring");
  }
  m_phase       = DunkPhase::kCharging;
  m_chargePower = 0.0F;
  m_phaseTimer  = 0.0F;
  m_player3D.setClip(std::string(clips::kDunkCharge));
  return Result<void>::ok();
}

// ─────────────────────────────────────────────────────────────────────────────
auto DunkContestMode::onChargeRelease(float normalizedPower) -> Result<void> {
  if (m_phase != DunkPhase::kCharging) {
    return Result<void>::err("release requires active charge");
  }
  m_chargePower = std::clamp(normalizedPower > 0.0F ? normalizedPower : m_chargePower,
                              0.05F, 1.0F);
  // Auto-select style by power if no signature was pre-selected
  if (m_pendingStyle < DunkStyle::k360Scoop) {
    if      (m_chargePower >= 0.85F) m_pendingStyle = DunkStyle::kSignature;
    else if (m_chargePower >= 0.65F) m_pendingStyle = DunkStyle::kPower;
    else if (m_chargePower >= 0.45F) m_pendingStyle = DunkStyle::kFlashy;
    else                             m_pendingStyle = DunkStyle::kStandard;
  }
  m_phase      = DunkPhase::kLaunch;
  m_phaseTimer = 0.0F;
  m_player3D.setClip(std::string(clips::kDunkLaunch), false);
  return Result<void>::ok();
}

// ─────────────────────────────────────────────────────────────────────────────
auto DunkContestMode::onApexTap() -> Result<QTEGrade> {
  if (m_phase != DunkPhase::kAirborne) {
    return Result<QTEGrade>::ok(QTEGrade::kMiss);
  }
  const QTEGrade grade = m_qte.onTap();
  m_lastApexGrade = grade;
  return Result<QTEGrade>::ok(grade);
}

// ─────────────────────────────────────────────────────────────────────────────
auto DunkContestMode::selectSignatureDunk(DunkStyle style) -> Result<void> {
  if (style < DunkStyle::k360Scoop) {
    return Result<void>::err("use k360Scoop/k360Eastbay/k360FakeEastbay/kOffBackboardWindmill");
  }
  if (m_phase != DunkPhase::kFreeDribble && m_phase != DunkPhase::kCharging) {
    return Result<void>::err("select signature dunk while dribbling or charging");
  }
  m_pendingStyle = style;
  return Result<void>::ok();
}

// ─────────────────────────────────────────────────────────────────────────────
auto DunkContestMode::onRegisterSignature(const std::string& animationId,
                                          const nlohmann::json& keyframes) -> Result<void> {
  m_signatureAnimationId = animationId;
  m_signatureKeyframes   = keyframes;
  return Result<void>::ok();
}

// ─────────────────────────────────────────────────────────────────────────────
auto DunkContestMode::styleMultiplier(DunkStyle style) -> float {
  switch (style) {
  case DunkStyle::kFlashy:               return 1.2F;
  case DunkStyle::kPower:                return 1.3F;
  case DunkStyle::kSignature:            return 1.5F;
  case DunkStyle::k360Scoop:             return 1.8F;
  case DunkStyle::k360Eastbay:           return 2.0F;
  case DunkStyle::k360FakeEastbay:       return 1.6F;
  case DunkStyle::kOffBackboardWindmill: return 2.2F;
  case DunkStyle::kStandard: default:    return 1.0F;
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

// ─────────────────────────────────────────────────────────────────────────────
void DunkContestMode::update(double deltaSeconds, const ArcadePhysicsParams& physics) {
  m_phaseTimer += static_cast<float>(deltaSeconds);

  if (m_phase == DunkPhase::kCharging) {
    m_chargePower = std::clamp(m_chargePower + static_cast<float>(deltaSeconds) * kChargeRate,
                               0.0F, 1.0F);
    update3DPositions(deltaSeconds);
    return;
  }

  if (m_phase == DunkPhase::kLaunch) {
    if (m_phaseTimer >= 0.15F) {
      m_phase      = DunkPhase::kAirborne;
      m_phaseTimer = 0.0F;
      m_airTimeSeconds = 0.0F;
      const float launchSpeed =
          kLaunchSpeedMin + (kLaunchSpeedMax - kLaunchSpeedMin) * m_chargePower;
      const float hangBase = launchSpeed / 9.81F;
      m_airTimeSeconds = hangBase * physics.hangTimeMultiplier * (1.0F / kHangGravityScale);
      m_qte.startApexWindow(std::max(0.35F, m_airTimeSeconds * 0.35F));
    }
    update3DPositions(deltaSeconds);
    return;
  }

  if (m_phase == DunkPhase::kAirborne) {
    m_qte.update(deltaSeconds);
    m_airTimeSeconds = std::max(0.0F, m_airTimeSeconds - static_cast<float>(deltaSeconds));
    if (m_airTimeSeconds <= 0.0F || m_phaseTimer >= 1.2F) {
      completeDunk(physics);
    }
    update3DPositions(deltaSeconds);
    return;
  }

  if (m_phase == DunkPhase::kScored && m_phaseTimer >= 0.5F) {
    m_phase      = DunkPhase::kFreeDribble;
    m_phaseTimer = 0.0F;
    // Return to a new spot on the court — vary x so the player doesn't just
    // teleport back to the same launch angle every time
    const float newX = (m_ghostDunks % 2 == 0) ? -3.0F : 3.0F;
    m_player3D   = CharacterState3D{{newX, 0.0F, -8.0F}};
    m_player3D.setClip(std::string(clips::kDunkApproach));
    m_pendingStyle = DunkStyle::kStandard;
  }

  // Ghost opponent scores while player is dribbling / between dunks
  if (m_phase == DunkPhase::kFreeDribble) {
    m_ghostTimer += static_cast<float>(deltaSeconds);
    if (m_ghostTimer >= kGhostDunkInterval) {
      m_ghostTimer = 0.0F;
      advanceGhostOpponent();
    }
  }

  update3DPositions(deltaSeconds);
}

// ─────────────────────────────────────────────────────────────────────────────
void DunkContestMode::update3DPositions(double deltaSeconds) {
  constexpr float kGravity = 9.81F;

  switch (m_phase) {
  case DunkPhase::kFreeDribble:
    // Animation is set by movePlayer(); default to idle if standing still
    if (m_player3D.animClip.name.empty()) {
      m_player3D.setClip(std::string(clips::kIdle));
    }
    break;

  case DunkPhase::kCharging:
    m_player3D.setClip(std::string(clips::kDunkCharge));
    break;

  case DunkPhase::kLaunch:
    // Sprint from current position toward hoop
    m_player3D.moveToward({kHoopPos.x, 0.0F, kHoopPos.z}, kApproachSpeed, deltaSeconds);
    if (m_player3D.velocity.y == 0.0F) {
      m_player3D.velocity.y = 7.0F * m_chargePower;
    }
    m_player3D.setClip(std::string(clips::kDunkLaunch), false);
    break;

  case DunkPhase::kAirborne: {
    m_player3D.applyGravity(kGravity, deltaSeconds);
    m_player3D.moveToward({kHoopPos.x, m_player3D.position.y, kHoopPos.z},
                          kApproachSpeed, deltaSeconds);
    m_player3D.setClip(std::string(styleAnimClip(m_pendingStyle)), false);
    break;
  }

  case DunkPhase::kScored:
    m_player3D.velocity = {};
    m_player3D.setClip(std::string(clips::kDunkScore), false);
    break;

  case DunkPhase::kMatchWon:
    m_player3D.setClip(std::string(clips::kDunkScore), false, 0.7F);
    break;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
auto DunkContestMode::calculateDunkPoints(const DunkResult& dunk,
                                          const ArcadePhysicsParams& physics) const -> int {
  const float hangPts  = dunk.hangTimeSeconds * 2.0F * physics.hangTimeMultiplier;
  const float trickPts = 2.0F * styleMultiplier(dunk.style);
  const float timingB  = QTESystem::timingBonus(dunk.timingGrade);
  // Bonus for launching from far out — NBA theatrics
  const float distB    = std::min(dunk.launchDistanceMeters * 0.15F, 2.0F);
  const int raw = static_cast<int>(std::round(hangPts + trickPts + timingB + distB));
  return std::max(1, raw);
}

void DunkContestMode::completeDunk(const ArcadePhysicsParams& physics) {
  DunkResult dunk{};
  dunk.style              = m_pendingStyle;
  dunk.hangTimeSeconds    = std::max(0.4F, m_airTimeSeconds + m_phaseTimer * 0.25F);
  dunk.timingGrade        = m_lastApexGrade;
  dunk.launchDistanceMeters = m_player3D.position.distanceTo(kHoopPos);
  m_lastApexGrade         = QTEGrade::kMiss;
  dunk.points             = calculateDunkPoints(dunk, physics);
  if (!m_signatureAnimationId.empty()) {
    dunk.points += 2; // user-loaded signature bonus
  }
  m_dunkHistory.push_back(dunk);
  m_playerScore += dunk.points;

  m_phase      = DunkPhase::kScored;
  m_phaseTimer = 0.0F;

  if (m_playerScore >= kWinScore) {
    m_phase = DunkPhase::kMatchWon;
  }
}

void DunkContestMode::advanceGhostOpponent() {
  if (m_phase == DunkPhase::kMatchWon) return;
  // Ghost AI disabled when a real remote peer is registered.
  if (m_remoteOpponent != nullptr) {
    m_opponentScore = m_remoteOpponent->dunkScore;
    if (m_opponentScore >= kWinScore) {
      m_phase = DunkPhase::kMatchWon;
    }
    return;
  }
  const int base = 2 + std::min(m_ghostDunks / 3, 2);
  m_opponentScore += base;
  ++m_ghostDunks;
  if (m_opponentScore >= kWinScore) {
    m_phase = DunkPhase::kMatchWon;
  }
}

void DunkContestMode::applyRemoteScore(int opponentScore) {
  m_opponentScore = opponentScore;
  if (m_opponentScore >= kWinScore && m_phase != DunkPhase::kMatchWon) {
    m_phase = DunkPhase::kMatchWon;
  }
}

void DunkContestMode::setRemoteOpponent(const RemotePlayerState* state) {
  m_remoteOpponent = state;
  if (m_remoteOpponent != nullptr) {
    m_opponentScore = m_remoteOpponent->dunkScore;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
auto DunkContestMode::stateJson() const -> nlohmann::json {
  // Phase label
  const auto phaseLabel = [this]() -> std::string_view {
    switch (m_phase) {
    case DunkPhase::kFreeDribble: return "free_dribble";
    case DunkPhase::kCharging:    return "charging";
    case DunkPhase::kLaunch:      return "launch";
    case DunkPhase::kAirborne:    return "airborne";
    case DunkPhase::kScored:      return "scored";
    case DunkPhase::kMatchWon:    return "match_won";
    }
    return "free_dribble";
  }();

  nlohmann::json dunks = nlohmann::json::array();
  for (const DunkResult& d : m_dunkHistory) {
    dunks.push_back({
        {"style", static_cast<int>(d.style)},
        {"hang_time", d.hangTimeSeconds},
        {"timing_grade", QTESystem::gradeLabel(d.timingGrade)},
        {"points", d.points},
        {"launch_distance", d.launchDistanceMeters},
    });
  }

  return {
      {"phase", phaseLabel},
      {"player_score",   m_playerScore},
      {"opponent_score", m_opponentScore},
      {"charge_power",   m_chargePower},
      {"win_target",     kWinScore},
      {"match_complete", isMatchComplete()},
      {"dunk_details",   std::move(dunks)},
      {"ghost_dunks",    m_ghostDunks},
      {"signature_animation_id", m_signatureAnimationId},
      {"signature_keyframes",    m_signatureKeyframes},
      // 3D court state for the renderer
      {"player_3d", {
          {"x",          m_player3D.position.x},
          {"y",          m_player3D.position.y},
          {"z",          m_player3D.position.z},
          {"yaw",        m_player3D.yawDegrees},
          {"anim_clip",  m_player3D.animClip.name},
          {"anim_loop",  m_player3D.animClip.loop},
          {"anim_speed", m_player3D.animClip.speedScale},
      }},
      {"opponent_3d", {
          {"x",         m_opponent3D.position.x},
          {"y",         m_opponent3D.position.y},
          {"z",         m_opponent3D.position.z},
          {"anim_clip", m_opponent3D.animClip.name},
      }},
      {"hoop_3d", {
          {"x", kHoopPos.x},
          {"y", kHoopPos.y},
          {"z", kHoopPos.z},
      }},
      // Court bounds — renderer uses these to draw the court floor
      {"court_bounds", {
          {"half_width", kCourtHalfWidth},
          {"depth",      -kCourtDepth},
      }},
  };
}

} // namespace nexus::gameplay
