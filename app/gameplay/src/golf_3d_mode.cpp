#include "nexus/gameplay/golf_3d_mode.h"
#include "nexus/gameplay/prq_engine.h"

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <string>

namespace nexus::gameplay {

// ── GolfBall ──────────────────────────────────────────────────────────────────

void GolfBall::update(float gravity, float windX, float windZ, double dt) noexcept {
  if (!inFlight || landed) return;

  const float dtF = static_cast<float>(dt);
  // Wind applies horizontal drag
  velocity.x += windX * 0.1F * dtF;
  velocity.z += windZ * 0.1F * dtF;
  // Gravity
  velocity.y -= gravity * dtF;

  position.x += velocity.x * dtF;
  position.y += velocity.y * dtF;
  position.z += velocity.z * dtF;

  if (position.y <= 0.0F) {
    position.y = 0.0F;
    // Backspin reduces roll; topspin extends it — simplified here as roll
    const float rollFactor = std::clamp(1.0F - spinRpm / 3000.0F, 0.5F, 1.5F);
    velocity.x *= 0.25F * rollFactor;  // friction on landing
    velocity.z *= 0.25F * rollFactor;
    velocity.y = 0.0F;
    landed  = true;
    inFlight = false;
  }
}

auto GolfBall::lie() const -> GolfLie {
  if (position.y > 0.1F) return GolfLie::kFairway;  // in air — use fairway as default
  // Simplified: actual terrain sampling would be done by the renderer;
  // here we return fairway by default — modes set it explicitly.
  return GolfLie::kFairway;
}

// ── GolfHoleResult ────────────────────────────────────────────────────────────

auto GolfHoleResult::label() const -> std::string_view {
  const int rel = relativeToPar();
  if (rel <= -2) return "eagle";
  if (rel == -1) return "birdie";
  if (rel ==  0) return "par";
  if (rel ==  1) return "bogey";
  if (rel ==  2) return "double_bogey";
  return "triple_bogey_plus";
}

// ── Course layout ─────────────────────────────────────────────────────────────
// Nine holes designed in a flat 3D world; distances are in meters.
// 1 yard ≈ 0.914 m; a 400-yard par-4 ≈ 366 m.

auto Golf3DMode::buildCourse() -> std::array<GolfHole, kHoleCount> {
  return {{
    // Hole 1 — par 4, 300 m
    {{0.0F, 0.0F, 0.0F},   {0.0F, 0.0F, 300.0F},  0.0F,  4, 300.0F},
    // Hole 2 — par 3, 120 m (short iron)
    {{0.0F, 0.0F, 0.0F},   {20.0F, 0.0F, 120.0F}, 10.0F, 3, 120.0F},
    // Hole 3 — par 5, 480 m (dogleg)
    {{0.0F, 0.0F, 0.0F},   {-30.0F, 0.0F, 480.0F},-5.0F, 5, 480.0F},
    // Hole 4 — par 4, 320 m
    {{0.0F, 0.0F, 0.0F},   {15.0F, 0.0F, 320.0F},  5.0F, 4, 320.0F},
    // Hole 5 — par 3, 150 m (carry over water)
    {{0.0F, 0.0F, 0.0F},   {-10.0F, 0.0F, 150.0F},-5.0F, 3, 150.0F},
    // Hole 6 — par 4, 340 m
    {{0.0F, 0.0F, 0.0F},   {-25.0F, 0.0F, 340.0F},-7.0F, 4, 340.0F},
    // Hole 7 — par 5, 510 m
    {{0.0F, 0.0F, 0.0F},   {30.0F, 0.0F, 510.0F},  8.0F, 5, 510.0F},
    // Hole 8 — par 4, 280 m
    {{0.0F, 0.0F, 0.0F},   {0.0F, 0.0F, 280.0F},   0.0F, 4, 280.0F},
    // Hole 9 — par 4, 360 m (finishing hole)
    {{0.0F, 0.0F, 0.0F},   {-15.0F, 0.0F, 360.0F},-4.0F, 4, 360.0F},
  }};
}

// ── Reset ─────────────────────────────────────────────────────────────────────

void Golf3DMode::reset() {
  m_course            = buildCourse();
  m_currentHole       = 0;
  m_strokesThisHole   = 0;
  m_totalStrokes      = 0;
  m_phase             = GolfSwingPhase::kAddress;
  m_selectedClub      = GolfClub::kDriver;
  m_aimYaw            = m_course[0].fairwayYaw;
  m_powerMeter        = 0.0F;
  m_accuracyOffset    = 0.0F;
  m_powerLocked       = false;
  m_phaseTimer        = 0.0F;
  m_holeResults.clear();

  // Place player and ball on first tee
  m_player3D = CharacterState3D{m_course[0].teePos};
  m_player3D.setClip(std::string(clips::kGolfIdle));
  m_ball.position = m_course[0].teePos;
  m_ball.velocity = {};
  m_ball.inFlight = false;
  m_ball.landed   = false;
  m_ball.spinRpm  = 0.0F;

  // Random wind for hole 1
  // Use a deterministic seed per hole for reproducibility
  m_windX = (static_cast<float>(m_currentHole * 17 % 7) - 3.0F) * 0.5F;
  m_windZ = (static_cast<float>(m_currentHole * 13 % 5) - 2.0F) * 0.4F;

  // Camera: behind the player looking toward the pin
  m_camera.position = m_player3D.position + Vec3{0.0F, 2.5F, -5.0F};
  m_camera.target   = m_course[0].pinPos;
  m_camera.fovDegrees = 70.0F;
}

// ── Update ────────────────────────────────────────────────────────────────────

void Golf3DMode::update(double deltaSeconds) {
  m_phaseTimer += static_cast<float>(deltaSeconds);

  if (m_phase == GolfSwingPhase::kBackswing) {
    // Power meter auto-fills
    m_powerMeter = std::min(m_powerMeter + kPowerFillRate * static_cast<float>(deltaSeconds), 1.0F);
    if (m_powerMeter >= 1.0F && !m_powerLocked) {
      // Power auto-filled — set locked at 1.0 and transition to downswing.
      m_powerLocked = true;
      m_phase = GolfSwingPhase::kDownswing;
      m_phaseTimer = 0.0F;
    }
  }

  if (m_phase == GolfSwingPhase::kDownswing && m_powerLocked) {
    // Accuracy window closes after 0.5 s — swing fires automatically
    if (m_phaseTimer >= 0.5F) {
      resolveShotLaunch();
    }
  }

  if (m_phase == GolfSwingPhase::kFollowThrough && m_phaseTimer >= kFollowThruDur) {
    m_phase = GolfSwingPhase::kBallFlight;
    m_phaseTimer = 0.0F;
  }

  if (m_phase == GolfSwingPhase::kBallFlight) {
    m_ball.update(kGravity, m_windX, m_windZ, deltaSeconds);
    // Update camera to follow ball
    m_camera.position = m_ball.position + Vec3{0.0F, 8.0F, -15.0F};
    m_camera.target   = m_ball.position;
    if (m_ball.landed) {
      m_phase      = GolfSwingPhase::kBallLanded;
      m_phaseTimer = 0.0F;
      onBallLanded();
    }
  }

  if (m_phase == GolfSwingPhase::kBallLanded && m_phaseTimer >= kLandedPauseDur) {
    // Check win condition
    const float distToPin = m_ball.position.distanceTo(m_course[static_cast<std::size_t>(m_currentHole)].pinPos);
    if (distToPin <= 0.5F || m_strokesThisHole >= kMaxStrokesPerHole) {
      // Ball in hole (or pick-up rule: max strokes reached, advance with whatever score)
      GolfHoleResult res;
      res.holeNumber = m_currentHole + 1;
      res.par        = m_course[static_cast<std::size_t>(m_currentHole)].par;
      res.strokes    = m_strokesThisHole;
      m_holeResults.push_back(res);
      m_player3D.setClip(std::string(clips::kGolfCelebrate), false);
      advanceHole();
    } else {
      // Back to address for next shot
      m_phase          = GolfSwingPhase::kAddress;
      m_phaseTimer     = 0.0F;
      m_powerMeter     = 0.0F;
      m_powerLocked    = false;
      m_accuracyOffset = 0.0F;
      m_selectedClub   = autoClubForDistance(distToPin, m_ball.lie());
      m_player3D.setClip(std::string(clips::kGolfAddress));
    }
  }
}

// ── beginAddress ─────────────────────────────────────────────────────────────

auto Golf3DMode::beginAddress(bool autoSelectClub) -> Result<nlohmann::json> {
  if (m_phase == GolfSwingPhase::kRoundComplete) {
    return Result<nlohmann::json>::err("round complete");
  }
  if (m_phase != GolfSwingPhase::kWalking && m_phase != GolfSwingPhase::kAddress &&
      m_phase != GolfSwingPhase::kBallLanded) {
    return Result<nlohmann::json>::err("cannot address now");
  }

  const float distToPin = m_ball.position.distanceTo(
      m_course[static_cast<std::size_t>(m_currentHole)].pinPos);

  if (autoSelectClub) {
    m_selectedClub = autoClubForDistance(distToPin, m_ball.lie());
  }

  m_phase       = GolfSwingPhase::kAddress;
  m_phaseTimer  = 0.0F;
  m_powerMeter  = 0.0F;
  m_powerLocked = false;
  m_accuracyOffset = 0.0F;

  // Aim toward pin by default
  const Vec3 toPin = (m_course[static_cast<std::size_t>(m_currentHole)].pinPos
                      - m_ball.position).normalized();
  if (toPin.x != 0.0F || toPin.z != 0.0F) {
    m_aimYaw = std::atan2(toPin.x, toPin.z) * (180.0F / 3.14159265F);
  }

  m_player3D.setClip(std::string(clips::kGolfAddress));
  // Move player to ball
  m_player3D.position = m_ball.position;

  return Result<nlohmann::json>::ok(stateJson());
}

// ── adjustAim ────────────────────────────────────────────────────────────────

auto Golf3DMode::adjustAim(float deltaDegrees) -> Result<nlohmann::json> {
  if (m_phase != GolfSwingPhase::kAddress) {
    return Result<nlohmann::json>::err("aim adjustment only in address phase");
  }
  m_aimYaw = std::fmod(m_aimYaw + deltaDegrees, 360.0F);
  return Result<nlohmann::json>::ok(stateJson());
}

// ── selectClub ───────────────────────────────────────────────────────────────

auto Golf3DMode::selectClub(GolfClub club) -> Result<nlohmann::json> {
  if (m_phase != GolfSwingPhase::kAddress) {
    return Result<nlohmann::json>::err("club selection only in address phase");
  }
  if (m_ball.lie() == GolfLie::kGreen && club != GolfClub::kPutter) {
    return Result<nlohmann::json>::err("must use putter on green");
  }
  if (m_ball.lie() == GolfLie::kBunker && club == GolfClub::kDriver) {
    return Result<nlohmann::json>::err("cannot use driver from bunker");
  }
  m_selectedClub = club;
  return Result<nlohmann::json>::ok(stateJson());
}

// ── startSwing ───────────────────────────────────────────────────────────────

auto Golf3DMode::startSwing() -> Result<nlohmann::json> {
  if (m_phase != GolfSwingPhase::kAddress) {
    return Result<nlohmann::json>::err("swing can only start from address");
  }
  m_phase       = GolfSwingPhase::kBackswing;
  m_phaseTimer  = 0.0F;
  m_powerMeter  = 0.0F;
  m_powerLocked = false;

  const bool isPutt = (m_selectedClub == GolfClub::kPutter);
  m_player3D.setClip(isPutt ? std::string(clips::kGolfPutt)
                             : std::string(clips::kGolfBackswing),
                     false);
  return Result<nlohmann::json>::ok(stateJson());
}

// ── swingTap ─────────────────────────────────────────────────────────────────

auto Golf3DMode::swingTap() -> Result<nlohmann::json> {
  if (m_phase == GolfSwingPhase::kBackswing) {
    // First tap: locks power and starts downswing
    m_powerLocked = true;
    m_phase       = GolfSwingPhase::kDownswing;
    m_phaseTimer  = 0.0F;
    m_player3D.setClip(std::string(clips::kGolfSwing), false);
    return Result<nlohmann::json>::ok(stateJson());
  }

  if (m_phase == GolfSwingPhase::kDownswing && m_powerLocked) {
    // Second tap: set accuracy (timing relative to center of downswing window)
    // phaseTimer normalized [0, 0.5] — perfect at 0.25
    const float center = 0.25F;
    m_accuracyOffset = (m_phaseTimer - center) / center;  // [-1, +1]
    m_accuracyOffset = std::clamp(m_accuracyOffset, -1.0F, 1.0F);
    resolveShotLaunch();
    return Result<nlohmann::json>::ok(stateJson());
  }

  return Result<nlohmann::json>::err("tap not valid in current phase");
}

// ── movePlayer ───────────────────────────────────────────────────────────────

auto Golf3DMode::movePlayer(float dx, float dz, double deltaSeconds) -> Result<nlohmann::json> {
  if (m_phase != GolfSwingPhase::kWalking &&
      m_phase != GolfSwingPhase::kAddress &&
      m_phase != GolfSwingPhase::kBallLanded) {
    return Result<nlohmann::json>::err("cannot move during swing/flight");
  }

  const float len = std::sqrt(dx * dx + dz * dz);
  if (len > 1e-4F) { dx /= len; dz /= len; }

  constexpr float kWalkSpeed = 4.0F;  // m/s on foot
  const float dt = static_cast<float>(deltaSeconds);
  m_player3D.position.x += dx * kWalkSpeed * dt;
  m_player3D.position.z += dz * kWalkSpeed * dt;

  if (len > 0.05F) {
    m_player3D.setClip(std::string(clips::kGolfWalk));
    m_player3D.yawDegrees = std::atan2(dx, dz) * (180.0F / 3.14159265F);
    if (m_phase != GolfSwingPhase::kWalking) {
      m_phase = GolfSwingPhase::kWalking;
    }
  } else {
    m_player3D.setClip(std::string(clips::kGolfIdle));
  }

  return Result<nlohmann::json>::ok(stateJson());
}

// ── resolveShotLaunch ────────────────────────────────────────────────────────

void Golf3DMode::resolveShotLaunch() {
  ++m_strokesThisHole;
  ++m_totalStrokes;

  const float loft   = clubLoftDegrees(m_selectedClub);
  const float maxDist = clubMaxDistanceMeters(m_selectedClub);

  // PRQ power bonus: elite players get up to 15% extra distance
  const float prqBonus = 1.0F + PRQEngine::getScore() * 0.0015F;

  // Accuracy: 0 = straight, ±1 = hook/slice
  // Add a small random miss based on inaccuracy
  const float drift = m_accuracyOffset * 8.0F;  // max ±8° side drift

  const float totalYaw = (m_aimYaw + drift) * (3.14159265F / 180.0F);
  const float loftRad  = loft * (3.14159265F / 180.0F);

  // Lie modifier
  float lieMod = 1.0F;
  if (m_ball.lie() == GolfLie::kRough)  lieMod = 0.85F;
  if (m_ball.lie() == GolfLie::kBunker) lieMod = 0.75F;

  const float speed = m_powerMeter * maxDist * prqBonus * lieMod / 5.0F;  // ~ sqrt(2*maxDist/g)

  m_ball.velocity.x = speed * std::sin(totalYaw) * std::cos(loftRad);
  m_ball.velocity.y = speed * std::sin(loftRad);
  m_ball.velocity.z = speed * std::cos(totalYaw) * std::cos(loftRad);
  m_ball.inFlight   = true;
  m_ball.landed     = false;
  m_ball.spinRpm    = (m_selectedClub == GolfClub::kPutter) ? 0.0F : 1500.0F;

  m_phase      = GolfSwingPhase::kFollowThrough;
  m_phaseTimer = 0.0F;
  m_player3D.setClip(std::string(clips::kGolfFollowThrough), false);
}

// ── onBallLanded ─────────────────────────────────────────────────────────────

void Golf3DMode::onBallLanded() {
  // Camera pulls back to show ball position and distance to pin
  const Vec3& pin = m_course[static_cast<std::size_t>(m_currentHole)].pinPos;
  m_camera.position = m_ball.position + Vec3{0.0F, 4.0F, -8.0F};
  m_camera.target   = pin;
  m_player3D.setClip(std::string(clips::kGolfIdle));
}

// ── advanceHole ──────────────────────────────────────────────────────────────

void Golf3DMode::advanceHole() {
  m_currentHole++;
  m_strokesThisHole = 0;

  if (m_currentHole >= kHoleCount) {
    m_phase = GolfSwingPhase::kRoundComplete;
    return;
  }

  // Reset ball and player for next hole
  m_ball.position = m_course[static_cast<std::size_t>(m_currentHole)].teePos;
  m_ball.velocity = {};
  m_ball.inFlight = false;
  m_ball.landed   = false;
  m_ball.spinRpm  = 0.0F;

  m_player3D.position = m_ball.position;
  m_player3D.setClip(std::string(clips::kGolfIdle));

  m_aimYaw         = m_course[static_cast<std::size_t>(m_currentHole)].fairwayYaw;
  m_powerMeter     = 0.0F;
  m_powerLocked    = false;
  m_accuracyOffset = 0.0F;
  m_phaseTimer     = 0.0F;
  m_phase          = GolfSwingPhase::kAddress;

  m_selectedClub = GolfClub::kDriver;

  // New wind per hole
  m_windX = (static_cast<float>(m_currentHole * 17 % 7) - 3.0F) * 0.5F;
  m_windZ = (static_cast<float>(m_currentHole * 13 % 5) - 2.0F) * 0.4F;

  // Camera: behind player looking at pin
  const Vec3& pin = m_course[static_cast<std::size_t>(m_currentHole)].pinPos;
  m_camera.position = m_ball.position + Vec3{0.0F, 2.5F, -5.0F};
  m_camera.target   = pin;
}

// ── autoClubForDistance ───────────────────────────────────────────────────────

auto Golf3DMode::autoClubForDistance(float distMeters, GolfLie lie) const -> GolfClub {
  if (lie == GolfLie::kGreen)  return GolfClub::kPutter;
  if (lie == GolfLie::kBunker) return GolfClub::kWedge;
  if (distMeters <= 90.0F)  return GolfClub::kWedge;
  if (distMeters <= 165.0F) return GolfClub::kIron;
  return GolfClub::kDriver;
}

auto Golf3DMode::clubLoftDegrees(GolfClub club) const -> float {
  switch (club) {
  case GolfClub::kDriver: return 12.0F;
  case GolfClub::kIron:   return 32.0F;
  case GolfClub::kWedge:  return 52.0F;
  case GolfClub::kPutter: return 4.0F;
  }
  return 12.0F;
}

auto Golf3DMode::clubMaxDistanceMeters(GolfClub club) const -> float {
  switch (club) {
  case GolfClub::kDriver: return 220.0F;
  case GolfClub::kIron:   return 150.0F;
  case GolfClub::kWedge:  return 80.0F;
  case GolfClub::kPutter: return 25.0F;
  }
  return 150.0F;
}

// ── phaseLabel ───────────────────────────────────────────────────────────────

auto Golf3DMode::phaseLabel() const -> std::string_view {
  switch (m_phase) {
  case GolfSwingPhase::kWalking:       return "walking";
  case GolfSwingPhase::kAddress:       return "address";
  case GolfSwingPhase::kBackswing:     return "backswing";
  case GolfSwingPhase::kDownswing:     return "downswing";
  case GolfSwingPhase::kFollowThrough: return "follow_through";
  case GolfSwingPhase::kBallFlight:    return "ball_flight";
  case GolfSwingPhase::kBallLanded:    return "ball_landed";
  case GolfSwingPhase::kHoleComplete:  return "hole_complete";
  case GolfSwingPhase::kRoundComplete: return "round_complete";
  }
  return "address";
}

// ── totalScore ───────────────────────────────────────────────────────────────

auto Golf3DMode::totalScore() const -> int {
  int score = 0;
  for (const GolfHoleResult& r : m_holeResults) {
    score += r.relativeToPar();
  }
  return score;
}

// ── stateJson ────────────────────────────────────────────────────────────────

auto Golf3DMode::stateJson() const -> nlohmann::json {
  const int holeIdx = std::min(m_currentHole, kHoleCount - 1);
  const GolfHole& hole = m_course[static_cast<std::size_t>(holeIdx)];

  const float distToPin = m_ball.position.distanceTo(hole.pinPos);

  const auto clubLabel = [](GolfClub c) -> std::string_view {
    switch (c) {
    case GolfClub::kDriver: return "driver";
    case GolfClub::kIron:   return "iron";
    case GolfClub::kWedge:  return "wedge";
    case GolfClub::kPutter: return "putter";
    }
    return "driver";
  };

  nlohmann::json scorecard = nlohmann::json::array();
  for (const GolfHoleResult& r : m_holeResults) {
    scorecard.push_back({
        {"hole",    r.holeNumber},
        {"par",     r.par},
        {"strokes", r.strokes},
        {"rel",     r.relativeToPar()},
        {"label",   r.label()},
    });
  }

  return {
      {"phase",            phaseLabel()},
      {"hole",             m_currentHole + 1},
      {"hole_par",         hole.par},
      {"strokes_this_hole",m_strokesThisHole},
      {"total_strokes",    m_totalStrokes},
      {"total_score",      totalScore()},
      {"club",             clubLabel(m_selectedClub)},
      {"power_meter",      m_powerMeter},
      {"power_locked",     m_powerLocked},
      {"accuracy_offset",  m_accuracyOffset},
      {"aim_yaw",          m_aimYaw},
      {"dist_to_pin_m",    distToPin},
      {"wind_x",           m_windX},
      {"wind_z",           m_windZ},
      {"round_complete",   isRoundComplete()},
      {"scorecard",        std::move(scorecard)},
      // Ball world state
      {"ball_3d", {
          {"x",         m_ball.position.x},
          {"y",         m_ball.position.y},
          {"z",         m_ball.position.z},
          {"in_flight", m_ball.inFlight},
          {"landed",    m_ball.landed},
      }},
      // Player world state
      {"player_3d", {
          {"x",         m_player3D.position.x},
          {"y",         m_player3D.position.y},
          {"z",         m_player3D.position.z},
          {"yaw",       m_player3D.yawDegrees},
          {"anim_clip", m_player3D.animClip.name},
          {"anim_loop", m_player3D.animClip.loop},
      }},
      // Pin / hole location
      {"pin_3d", {
          {"x", hole.pinPos.x},
          {"y", hole.pinPos.y},
          {"z", hole.pinPos.z},
      }},
      // Camera
      {"camera_3d", {
          {"pos_x",   m_camera.position.x},
          {"pos_y",   m_camera.position.y},
          {"pos_z",   m_camera.position.z},
          {"tgt_x",   m_camera.target.x},
          {"tgt_y",   m_camera.target.y},
          {"tgt_z",   m_camera.target.z},
          {"fov",     m_camera.fovDegrees},
      }},
  };
}

} // namespace nexus::gameplay
