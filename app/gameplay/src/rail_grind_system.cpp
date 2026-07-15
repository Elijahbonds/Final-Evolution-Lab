#include "nexus/gameplay/rail_grind_system.h"

#include <algorithm>
#include <cmath>
#include <string>

namespace nexus::gameplay {

void RailGrindSystem::reset() {
  m_state = GrindState::kOff;
  m_railIndex = -1;
  m_t = 0.0F;
  m_speed = 0.0F;
  m_grindScore = 0.0F;
  m_trickTimer = 0.0F;
  m_trickCount = 0;
  m_lastTrick.clear();
}

void RailGrindSystem::update(double deltaSeconds, float grindAcceleration) {
  const float dt = static_cast<float>(deltaSeconds);

  if (m_state == GrindState::kSnapping) {
    // Lerp speed to rail entry speed over ~0.15 s
    m_speed = std::min(m_speed + grindAcceleration * 20.0F * dt, kBaseSpeed * grindAcceleration);
    if (m_speed >= kBaseSpeed * grindAcceleration * 0.5F) {
      m_state = GrindState::kGrinding;
    }
    return;
  }

  if (m_state == GrindState::kTrick) {
    m_trickTimer -= dt;
    if (m_trickTimer <= 0.0F) {
      m_trickTimer = 0.0F;
      m_state = GrindState::kGrinding;
    }
    // Still slide during trick
  }

  if (m_state == GrindState::kGrinding || m_state == GrindState::kTrick) {
    // Accelerate toward max speed (PRQ-scaled)
    const float topSpeed = kBaseSpeed + (kMaxSpeed - kBaseSpeed) * (grindAcceleration - 0.6F) / 1.4F;
    m_speed = std::min(m_speed + grindAcceleration * 4.0F * dt, topSpeed);

    const float railLen = (m_railIndex >= 0 && m_railIndex < static_cast<int>(kStoryRails.size()))
                              ? kStoryRails[static_cast<std::size_t>(m_railIndex)].length
                              : 1.0F;
    m_t += (m_speed / railLen) * dt;

    // Score: distance × grind multiplier
    m_grindScore += m_speed * dt * 2.5F;

    // Check end of rail
    const bool loops = (m_railIndex >= 0 && m_railIndex < static_cast<int>(kStoryRails.size()))
                           && kStoryRails[static_cast<std::size_t>(m_railIndex)].loop;
    if (m_t >= 1.0F) {
      if (loops) {
        m_t = std::fmod(m_t, 1.0F);
      } else {
        m_t = 1.0F;
        m_state = GrindState::kExit;
      }
    }
  }

  if (m_state == GrindState::kExit) {
    m_state = GrindState::kOff;
    m_railIndex = -1;
    m_t = 0.0F;
    m_speed = 0.0F;
  }
}

auto RailGrindSystem::trySnapToRail(Vec3 playerPos, float grindAcceleration)
    -> Result<nlohmann::json> {
  // Find nearest rail start/end within snap radius
  float bestDist = kSnapRadius + 1.0F;
  int   bestIdx  = -1;

  for (int i = 0; i < static_cast<int>(kStoryRails.size()); ++i) {
    const auto& rail = kStoryRails[static_cast<std::size_t>(i)];
    const float d = playerPos.distanceTo(rail.waypoints[0]);
    if (d < kSnapRadius && d < bestDist) {
      bestDist = d;
      bestIdx  = i;
    }
  }

  if (bestIdx < 0) {
    return Result<nlohmann::json>::err("no rail within snap radius");
  }

  m_railIndex = bestIdx;
  m_t = 0.0F;
  m_speed = kBaseSpeed * grindAcceleration;
  m_state = GrindState::kGrinding;  // enter grind immediately; lerp happens in update()

  return Result<nlohmann::json>::ok({
      {"rail_id", kStoryRails[static_cast<std::size_t>(m_railIndex)].id},
      {"snap_distance", bestDist},
      {"grind_state", "grinding"},
  });
}

auto RailGrindSystem::performTrick(std::string_view trickName)
    -> Result<nlohmann::json> {
  if (m_state != GrindState::kGrinding) {
    return Result<nlohmann::json>::err("not grinding");
  }
  const float bonus = trickBonus(trickName);
  m_grindScore += bonus;
  ++m_trickCount;
  m_lastTrick = std::string(trickName);
  m_trickTimer = 0.35F;
  m_state = GrindState::kTrick;

  return Result<nlohmann::json>::ok({
      {"trick", std::string(trickName)},
      {"bonus", bonus},
      {"grind_score", m_grindScore},
      {"trick_count", m_trickCount},
  });
}

auto RailGrindSystem::exitGrind() -> Result<nlohmann::json> {
  if (m_state == GrindState::kOff) {
    return Result<nlohmann::json>::err("not on a rail");
  }
  const float score = m_grindScore;
  m_state = GrindState::kExit;  // update() will clean up next frame
  return Result<nlohmann::json>::ok({
      {"grind_score", score},
      {"trick_count", m_trickCount},
      {"last_trick", m_lastTrick},
  });
}

auto RailGrindSystem::currentRailId() const -> std::string_view {
  if (m_railIndex < 0 || m_railIndex >= static_cast<int>(kStoryRails.size())) {
    return "none";
  }
  return kStoryRails[static_cast<std::size_t>(m_railIndex)].id;
}

auto RailGrindSystem::playerPosOnRail() const -> Vec3 {
  if (m_railIndex < 0 || m_railIndex >= static_cast<int>(kStoryRails.size())) {
    return {};
  }
  return evalRailPos(kStoryRails[static_cast<std::size_t>(m_railIndex)], m_t);
}

auto RailGrindSystem::stateJson() const -> nlohmann::json {
  const auto pos = playerPosOnRail();
  return {
      {"grind_state", static_cast<int>(m_state)},
      {"rail_id", std::string(currentRailId())},
      {"t", m_t},
      {"speed", m_speed},
      {"grind_score", m_grindScore},
      {"trick_count", m_trickCount},
      {"last_trick", m_lastTrick},
      {"position", {{"x", pos.x}, {"y", pos.y}, {"z", pos.z}}},
  };
}

// ── Private helpers ──────────────────────────────────────────────────────────

auto RailGrindSystem::trickBonus(std::string_view name) -> float {
  // SA2-style trick score table
  if (name == "nosegrind")   return 15.0F;
  if (name == "50-50")       return 10.0F;
  if (name == "noseslide")   return 18.0F;
  if (name == "tailslide")   return 18.0F;
  if (name == "boardslide")  return 12.0F;
  if (name == "crouch")      return 5.0F;
  if (name == "pose")        return 8.0F;
  return 8.0F;  // generic trick
}

auto RailGrindSystem::evalRailPos(const RailDef& rail, float t) -> Vec3 {
  // De Casteljau cubic Bézier evaluation
  const float u  = std::clamp(t, 0.0F, 1.0F);
  const float u1 = 1.0F - u;
  const auto& p  = rail.waypoints;

  return p[0] * (u1*u1*u1)
       + p[1] * (3.0F * u1*u1 * u)
       + p[2] * (3.0F * u1 * u*u)
       + p[3] * (u*u*u);
}

} // namespace nexus::gameplay
