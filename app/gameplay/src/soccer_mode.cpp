#include "nexus/gameplay/soccer_mode.h"
#include "nexus/gameplay/character_anim_state.h"

#include <algorithm>
#include <cmath>
#include <string>

namespace nexus::gameplay {

// ── SoccerDefender ────────────────────────────────────────────────────────────
void SoccerDefender::update(Vec3 ballPos, double dt) noexcept {
  const Vec3 dir   = (ballPos - position).normalized();
  const float dist = position.distanceTo(ballPos);
  const float step = speed * static_cast<float>(dt);
  if (dist <= step) {
    position = ballPos;
    engaged  = true;
  } else {
    position = position + dir * step;
    engaged  = dist < 1.2F;
  }
}

// ── SoccerMode ────────────────────────────────────────────────────────────────
void SoccerMode::reset() {
  m_phase       = SoccerPhase::kKickoff;
  m_phaseTimer  = 0.0F;
  m_playerGoals = 0;
  m_opGoals     = 0;
  m_matchTick   = 0;
  m_lastAction  = 0.0F;
  resetKickoff();
}

void SoccerMode::resetKickoff() {
  m_player      = CharacterState3D{kKickoffPos};
  m_player.setClip(std::string(clips::kSoccerDribble));
  m_ballPos      = kKickoffPos;
  m_ballVelocity = {};
  m_playerHasBall = true;
  spawnDefenders();
}

void SoccerMode::spawnDefenders() {
  // Defenders placed in a 3-deep defensive line between player and goal
  const float zLine[] = { 4.0F, 7.0F, 10.0F };
  const float xOff[]  = { 0.0F, -4.0F, 4.0F };
  for (int i = 0; i < kDefenders; ++i) {
    m_defenders[static_cast<std::size_t>(i)].position = {xOff[i], 0.0F, zLine[i]};
    m_defenders[static_cast<std::size_t>(i)].speed    = 4.5F + static_cast<float>(i) * 0.3F;
    m_defenders[static_cast<std::size_t>(i)].engaged  = false;
  }
}

void SoccerMode::update(double deltaSeconds) {
  if (m_phase == SoccerPhase::kMatchOver) return;

  m_phaseTimer += static_cast<float>(deltaSeconds);
  m_lastAction += static_cast<float>(deltaSeconds);

  // Goal / opponent goal celebration pause
  if (m_phase == SoccerPhase::kGoal || m_phase == SoccerPhase::kOpGoal) {
    if (m_phaseTimer >= 1.5F) {
      if (m_playerGoals >= kGoalsToWin || m_opGoals >= kGoalsToWin) {
        m_phase = SoccerPhase::kMatchOver;
      } else {
        m_phase = SoccerPhase::kActive;
        resetKickoff();
      }
    }
    return;
  }

  m_phase = SoccerPhase::kActive;
  updateDefenders(deltaSeconds);
  updateBallPhysics(deltaSeconds);

  // Opponent pressure: if player hasn't acted in 5s, opponent scores a chance.
  // Ghost AI is suppressed when a real remote peer is registered; goals arrive
  // via applyRemoteGoal() instead.
  if (m_remoteOpponent == nullptr && m_lastAction > 5.0F) {
    m_lastAction = 0.0F;
    ++m_matchTick;
    if (m_matchTick % 4 == 0) {
      ++m_opGoals;
      m_phase      = SoccerPhase::kOpGoal;
      m_phaseTimer = 0.0F;
    }
  }
}

void SoccerMode::updateDefenders(double dt) {
  const Vec3 target = m_playerHasBall ? m_player.position : m_ballPos;
  for (auto& def : m_defenders) {
    def.update(target, dt);
  }
}

void SoccerMode::updateBallPhysics(double dt) {
  if (m_playerHasBall) {
    m_ballPos = m_player.position + Vec3{0.0F, 0.0F, 0.5F};
    return;
  }
  // Simple ball rolling: decelerate toward stop
  m_ballPos      = m_ballPos + m_ballVelocity * static_cast<float>(dt);
  m_ballVelocity = m_ballVelocity * 0.92F; // friction

  // Check goal
  if (m_ballPos.z >= kFieldHalfD &&
      std::abs(m_ballPos.x) <= kGoalWidth * 0.5F) {
    ++m_playerGoals;
    m_phase      = SoccerPhase::kGoal;
    m_phaseTimer = 0.0F;
    m_player.setClip(std::string(clips::kSoccerCeleb), false);
  }
}

// ── Player actions ────────────────────────────────────────────────────────────
auto SoccerMode::move(float dx, float dz) -> Result<nlohmann::json> {
  if (m_phase == SoccerPhase::kMatchOver) return Result<nlohmann::json>::err("match over");
  if (m_phase == SoccerPhase::kGoal || m_phase == SoccerPhase::kOpGoal) {
    return Result<nlohmann::json>::ok(stateJson());
  }

  const float len = std::sqrt(dx * dx + dz * dz);
  if (len > 1e-4F) { dx /= len; dz /= len; }

  constexpr float kSpeed = 7.0F;
  m_player.position.x = std::clamp(m_player.position.x + dx * kSpeed * 0.016F,
                                   -kFieldHalfW, kFieldHalfW);
  m_player.position.z = std::clamp(m_player.position.z + dz * kSpeed * 0.016F,
                                   -kFieldHalfD, kFieldHalfD);
  m_player.setClip(std::string(clips::kSoccerDribble));
  if (m_playerHasBall) {
    m_ballPos = m_player.position + Vec3{0.0F, 0.0F, 0.3F};
  }
  m_lastAction = 0.0F;
  return Result<nlohmann::json>::ok(stateJson());
}

auto SoccerMode::shoot(float power, float direction) -> Result<nlohmann::json> {
  if (m_phase == SoccerPhase::kMatchOver) return Result<nlohmann::json>::err("match over");
  if (!m_playerHasBall) return Result<nlohmann::json>::err("no ball");

  m_player.setClip(std::string(clips::kSoccerShoot), false);
  m_playerHasBall = false;
  m_lastAction    = 0.0F;

  const float spd = 12.0F + power * 8.0F;
  m_ballVelocity  = { direction * 4.0F, 0.0F, spd };

  if (isShotOnTarget(direction)) {
    // Goal!
    ++m_playerGoals;
    m_phase      = SoccerPhase::kGoal;
    m_phaseTimer = 0.0F;
    m_player.setClip(std::string(clips::kSoccerCeleb), false);
    return Result<nlohmann::json>::ok({{"goal", true}, {"state", stateJson()}});
  }
  return Result<nlohmann::json>::ok({{"goal", false}, {"state", stateJson()}});
}

auto SoccerMode::pass(float direction) -> Result<nlohmann::json> {
  if (!m_playerHasBall) return Result<nlohmann::json>::err("no ball");
  m_player.setClip(std::string(clips::kSoccerPass), false);
  m_playerHasBall = false;
  m_ballVelocity  = { direction * 5.0F, 0.0F, 3.0F };
  m_lastAction    = 0.0F;
  // Simulate teammate returning the ball in ~1.5 s — simplification for solo play
  // (actual team logic would involve position tracking)
  return Result<nlohmann::json>::ok({{"passed", true}, {"state", stateJson()}});
}

auto SoccerMode::tackle() -> Result<nlohmann::json> {
  m_player.setClip(std::string(clips::kSoccerTackle), false);
  m_lastAction = 0.0F;
  // Check if nearest defender is close enough
  if (nearestDefenderDist() < 2.0F) {
    // Tackle succeeds — player gets ball back
    m_playerHasBall = true;
    return Result<nlohmann::json>::ok({{"tackled", true}, {"state", stateJson()}});
  }
  return Result<nlohmann::json>::ok({{"tackled", false}, {"state", stateJson()}});
}

auto SoccerMode::header() -> Result<nlohmann::json> {
  m_player.setClip(std::string(clips::kSoccerHeader), false);
  m_lastAction = 0.0F;
  if (m_playerHasBall || m_ballPos.y > 0.5F) {
    m_playerHasBall = false;
    m_ballVelocity  = {0.0F, 3.0F, 10.0F};
    if (isShotOnTarget(0.0F)) {
      ++m_playerGoals;
      m_phase = SoccerPhase::kGoal; m_phaseTimer = 0.0F;
      m_player.setClip(std::string(clips::kSoccerCeleb), false);
      return Result<nlohmann::json>::ok({{"goal", true}, {"state", stateJson()}});
    }
  }
  return Result<nlohmann::json>::ok({{"goal", false}, {"state", stateJson()}});
}

// ── Helpers ───────────────────────────────────────────────────────────────────
auto SoccerMode::isShotOnTarget(float direction) const -> bool {
  // Shot is on target if near goal x-range and has forward velocity
  const float goalX = direction * 2.0F; // offset from center
  return std::abs(goalX) <= kGoalWidth * 0.5F && m_player.position.z > 0.0F;
}

auto SoccerMode::nearestDefenderDist() const -> float {
  float best = 1e9F;
  for (const auto& d : m_defenders) {
    best = std::min(best, m_player.position.distanceTo(d.position));
  }
  return best;
}

auto SoccerMode::stateJson() const -> nlohmann::json {
  nlohmann::json defs = nlohmann::json::array();
  for (const auto& d : m_defenders) {
    defs.push_back({{"x", d.position.x}, {"z", d.position.z}, {"engaged", d.engaged}});
  }
  const auto phaseLabel = [this]() -> std::string_view {
    switch (m_phase) {
    case SoccerPhase::kKickoff:   return "kickoff";
    case SoccerPhase::kActive:    return "active";
    case SoccerPhase::kGoal:      return "goal";
    case SoccerPhase::kOpGoal:    return "op_goal";
    case SoccerPhase::kMatchOver: return "match_over";
    }
    return "active";
  }();
  return {
      {"phase",       phaseLabel},
      {"player_goals", m_playerGoals},
      {"op_goals",     m_opGoals},
      {"goals_to_win", kGoalsToWin},
      {"match_over",   isMatchOver()},
      {"has_ball",     m_playerHasBall},
      {"player_3d", {
          {"x", m_player.position.x}, {"y", m_player.position.y}, {"z", m_player.position.z},
          {"anim_clip", m_player.animClip.name},
      }},
      {"ball_3d", {
          {"x", m_ballPos.x}, {"y", m_ballPos.y}, {"z", m_ballPos.z},
          {"vx", m_ballVelocity.x}, {"vz", m_ballVelocity.z},
      }},
      {"defenders", defs},
      {"field", {
          {"half_width",  kFieldHalfW},
          {"half_depth",  kFieldHalfD},
          {"goal_width",  kGoalWidth},
          {"goal_center_z", kGoalCenter.z},
      }},
      {"multiplayer", m_remoteOpponent != nullptr},
  };
}

void SoccerMode::applyRemoteGoal() {
  ++m_opGoals;
  m_phase      = SoccerPhase::kOpGoal;
  m_phaseTimer = 0.0F;
  if (m_opGoals >= kGoalsToWin) {
    m_phase = SoccerPhase::kMatchOver;
  }
}

void SoccerMode::applyRemoteStateSync(const nlohmann::json& state) {
  // Apply authoritative ball position from the host peer.
  if (state.contains("ball_3d") && state["ball_3d"].is_object()) {
    const auto& b = state["ball_3d"];
    m_ballPos.x      = b.value("x", m_ballPos.x);
    m_ballPos.y      = b.value("y", m_ballPos.y);
    m_ballPos.z      = b.value("z", m_ballPos.z);
    m_ballVelocity.x = b.value("vx", m_ballVelocity.x);
    m_ballVelocity.z = b.value("vz", m_ballVelocity.z);
  }
  if (state.contains("op_goals") && state["op_goals"].is_number_integer()) {
    m_opGoals = state["op_goals"].get<int>();
  }
}

void SoccerMode::setRemoteOpponent(const RemotePlayerState* state) {
  m_remoteOpponent = state;
  if (m_remoteOpponent != nullptr) {
    m_opGoals = m_remoteOpponent->goals;
  }
}

} // namespace nexus::gameplay
