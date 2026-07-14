#include "nexus/gameplay/story_mode.h"

#include <algorithm>

namespace nexus::gameplay {

namespace {

constexpr float kObstacleDamage = 10.0F;

} // namespace

void StoryMode::reset() {
  m_phase          = StoryPhase::kBoardTraversal;
  m_tokenPos       = 0;
  m_totalShards    = 0.0F;
  m_bossesDefeated = 0;
  m_diceRolls      = 0;
  m_lastDice       = 0;
  m_spaceCleared.fill(false);
  m_health.reset();
  m_boss  = EnemyAI{};
  m_streamMgr.reset();
  m_rail.reset();
  m_flight.reset();
}

void StoryMode::update(double deltaSeconds) {
  const auto physics = currentPhysics();

  m_streamMgr.update();
  m_rail.update(deltaSeconds, physics.grindAcceleration);
  m_flight.update(deltaSeconds, physics);

  if (m_phase == StoryPhase::kBossFight) {
    m_boss.update(deltaSeconds);
    // If boss died externally (e.g. health depleted), auto-resolve.
    if (!m_boss.state().alive && m_phase == StoryPhase::kBossFight) {
      m_phase = StoryPhase::kBossDefeated;
      ++m_bossesDefeated;
      // Reward shards based on which zone boss
      m_totalShards += 50.0F;
      m_spaceCleared[m_tokenPos] = true;
      checkStoryComplete();
    }
  }
}

// ── Board game ───────────────────────────────────────────────────────────────

auto StoryMode::rollAndMove() -> Result<nlohmann::json> {
  if (m_phase == StoryPhase::kBossFight) {
    return Result<nlohmann::json>::err("cannot roll during boss fight");
  }
  if (m_phase == StoryPhase::kStoryComplete) {
    return Result<nlohmann::json>::err("story already complete");
  }

  static thread_local std::mt19937 rng{std::random_device{}()};
  std::uniform_int_distribution<int> dist(1, 6);
  m_lastDice = dist(rng);
  ++m_diceRolls;

  const int prevPos = m_tokenPos;
  m_tokenPos = (m_tokenPos + m_lastDice) % kBoardSpaceCount;

  // Activate the target zone for streaming
  const auto& space = kBoardSpaces[static_cast<std::size_t>(m_tokenPos)];
  m_streamMgr.activateZone(space.zone);

  // Resolve landing
  resolveSpaceLanding(m_tokenPos);

  nlohmann::json payload = stateJson();
  payload["dice_roll"] = {
      {"value", m_lastDice},
      {"from_space", prevPos},
      {"to_space", m_tokenPos},
      {"space_type", spaceTypeLabel(space.type)},
      {"zone", static_cast<int>(space.zone)},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

void StoryMode::resolveSpaceLanding(int spaceIndex) {
  const auto& space = kBoardSpaces[static_cast<std::size_t>(spaceIndex)];

  switch (space.type) {
  case BoardSpaceType::kBonus:
    m_totalShards += space.bonusValue;
    m_phase = StoryPhase::kBoardTraversal;
    break;

  case BoardSpaceType::kCarnival:
    m_totalShards += space.bonusValue * 0.5F;  // half bonus; full bonus via pad trigger
    m_phase = StoryPhase::kBoardTraversal;
    break;

  case BoardSpaceType::kRailZone:
    m_phase = StoryPhase::kRailSection;
    break;

  case BoardSpaceType::kFlightZone:
    m_phase = StoryPhase::kFlightSection;
    break;

  case BoardSpaceType::kObstacle:
    m_health.applyDamage(space.bonusValue);
    m_phase = StoryPhase::kBoardTraversal;
    break;

  case BoardSpaceType::kBossZone:
    if (!m_spaceCleared[static_cast<std::size_t>(spaceIndex)]) {
      // Boss fight will be triggered by enterBossZone()
      m_phase = StoryPhase::kBoardTraversal;  // wait for explicit enterBossZone
    }
    break;
  }
}

// ── Traversal commands ────────────────────────────────────────────────────────

auto StoryMode::jump() -> Result<nlohmann::json> {
  return m_flight.jump();
}

auto StoryMode::activateFlight() -> Result<nlohmann::json> {
  const auto physics = currentPhysics();
  auto result = m_flight.activateFlight(physics);
  if (result.isOk() && m_phase == StoryPhase::kFlightSection) {
    m_totalShards += 10.0F;  // bonus for using flight in a flight zone
  }
  return result;
}

auto StoryMode::triggerFlightBoost() -> Result<nlohmann::json> {
  const auto physics = currentPhysics();
  return m_flight.triggerBoost(physics);
}

auto StoryMode::tryGrindSnap(float px, float py, float pz)
    -> Result<nlohmann::json> {
  const auto physics = currentPhysics();
  auto result = m_rail.trySnapToRail({px, py, pz}, physics.grindAcceleration);
  if (result.isOk() && m_phase == StoryPhase::kRailSection) {
    m_totalShards += 5.0F;  // bonus for entering grind in a rail zone
  }
  return result;
}

auto StoryMode::grindTrick(std::string_view trickName) -> Result<nlohmann::json> {
  auto result = m_rail.performTrick(trickName);
  if (result.isOk()) {
    // Funnel trick score into shards
    m_totalShards += result.value().value("bonus", 0.0F);
  }
  return result;
}

auto StoryMode::exitGrind() -> Result<nlohmann::json> {
  auto result = m_rail.exitGrind();
  if (result.isOk()) {
    m_totalShards += result.value().value("grind_score", 0.0F) * 0.1F;
    if (m_phase == StoryPhase::kRailSection) {
      m_phase = StoryPhase::kBoardTraversal;
    }
  }
  return result;
}

// ── Boss fight ────────────────────────────────────────────────────────────────

auto StoryMode::enterBossZone() -> Result<nlohmann::json> {
  if (m_phase == StoryPhase::kBossFight) {
    return Result<nlohmann::json>::err("boss fight already active");
  }
  const auto& space = kBoardSpaces[static_cast<std::size_t>(m_tokenPos)];
  if (space.type != BoardSpaceType::kBossZone) {
    return Result<nlohmann::json>::err("current space is not a boss zone");
  }
  if (m_spaceCleared[static_cast<std::size_t>(m_tokenPos)]) {
    return Result<nlohmann::json>::err("boss already defeated here");
  }

  // Find boss config for this zone
  const auto zoneIdx = static_cast<std::size_t>(space.zone);
  const auto& boss = kZoneBosses[zoneIdx < kZoneBosses.size() ? zoneIdx : kZoneBosses.size() - 1];

  m_boss.configure(boss.maxHp, boss.speedScale, boss.aggression);
  m_phase = (space.zone == StageZoneId::kRooftopRow && m_bossesDefeated >= kBossCount)
                ? StoryPhase::kFinalBoss
                : StoryPhase::kBossFight;

  // Ensure this zone is streaming in
  m_streamMgr.activateZone(space.zone);

  return Result<nlohmann::json>::ok({
      {"boss_name", boss.name},
      {"boss_hp", boss.maxHp},
      {"zone", static_cast<int>(space.zone)},
      {"is_final_boss", m_phase == StoryPhase::kFinalBoss},
      {"story_phase", storyPhaseLabel(m_phase)},
  });
}

auto StoryMode::bossCombat(CombatAction action) -> Result<nlohmann::json> {
  if (m_phase != StoryPhase::kBossFight && m_phase != StoryPhase::kFinalBoss) {
    return Result<nlohmann::json>::err("not in boss fight");
  }

  const bool bossAttacking = m_boss.state().attacking;
  const float bossTimer    = m_boss.state().attackTimer;
  const auto outcome = CombatSystem::resolve(action, bossAttacking, bossTimer);

  // Apply damage to boss
  if (outcome.damageDealt > 0.0F) {
    m_boss.applyDamage(outcome.damageDealt);
  }

  // Player takes damage if boss counter-hit
  if (bossAttacking && !outcome.blocked && !outcome.countered) {
    m_health.applyDamage(8.0F);
  }

  const bool bossDefeated = !m_boss.state().alive;
  if (bossDefeated) {
    ++m_bossesDefeated;
    m_totalShards += 50.0F;
    m_spaceCleared[static_cast<std::size_t>(m_tokenPos)] = true;
    m_phase = StoryPhase::kBossDefeated;
    checkStoryComplete();
  }

  nlohmann::json payload = stateJson();
  payload["combat"] = {
      {"action", CombatSystem::actionLabel(action)},
      {"damage_dealt", outcome.damageDealt},
      {"blocked", outcome.blocked},
      {"countered", outcome.countered},
      {"boss_defeated", bossDefeated},
      {"boss_hp", m_boss.state().hp},
      {"player_hp", m_health.hp()},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto StoryMode::travelToZone(StageZoneId zone) -> Result<nlohmann::json> {
  if (!m_streamMgr.activateZone(zone)) {
    return Result<nlohmann::json>::err("invalid zone");
  }
  return Result<nlohmann::json>::ok({
      {"zone", static_cast<int>(zone)},
      {"zone_name", m_streamMgr.meta(zone).name},
      {"stream_state", "streaming"},
  });
}

// ── stateJson ────────────────────────────────────────────────────────────────

auto StoryMode::stateJson() const -> nlohmann::json {
  const auto& space = kBoardSpaces[static_cast<std::size_t>(m_tokenPos)];
  const auto pos = space.worldPos;

  nlohmann::json cleared = nlohmann::json::array();
  for (int i = 0; i < kBoardSpaceCount; ++i) {
    if (m_spaceCleared[static_cast<std::size_t>(i)]) {
      cleared.push_back(i);
    }
  }

  return {
      {"story_phase",      storyPhaseLabel(m_phase)},
      {"token_position",   m_tokenPos},
      {"space_type",       spaceTypeLabel(space.type)},
      {"token_world_pos",  {{"x", pos.x}, {"y", pos.y}, {"z", pos.z}}},
      {"total_shards",     m_totalShards},
      {"bosses_defeated",  m_bossesDefeated},
      {"dice_rolls",       m_diceRolls},
      {"last_dice",        m_lastDice},
      {"player_hp",        m_health.hp()},
      {"is_complete",      isComplete()},
      {"spaces_cleared",   cleared},
      {"stream_state",     m_streamMgr.stateJson()},
      {"grind",            m_rail.stateJson()},
      {"flight",           m_flight.stateJson()},
      {"prq_speed_scale",  currentPhysics().movementSpeedScale},
  };
}

// ── Private helpers ───────────────────────────────────────────────────────────

void StoryMode::checkStoryComplete() {
  if (m_bossesDefeated >= kBossCount + 1) {  // 4 zone bosses + final boss
    m_phase = StoryPhase::kStoryComplete;
  } else if (m_phase == StoryPhase::kBossDefeated) {
    m_phase = StoryPhase::kBoardTraversal;
  }
}

auto StoryMode::currentPhysics() const -> ArcadePhysicsParams {
  return ArcadePhysics::fromPRQ(PRQEngine::getScore(), PRQEngine::getNeuralDrive());
}

auto StoryMode::spaceTypeLabel(BoardSpaceType t) -> const char* {
  switch (t) {
  case BoardSpaceType::kCarnival:   return "carnival";
  case BoardSpaceType::kRailZone:   return "rail_zone";
  case BoardSpaceType::kFlightZone: return "flight_zone";
  case BoardSpaceType::kBossZone:   return "boss_zone";
  case BoardSpaceType::kBonus:      return "bonus";
  case BoardSpaceType::kObstacle:   return "obstacle";
  }
  return "unknown";
}

auto StoryMode::storyPhaseLabel(StoryPhase p) -> const char* {
  switch (p) {
  case StoryPhase::kBoardTraversal: return "board_traversal";
  case StoryPhase::kRailSection:    return "rail_section";
  case StoryPhase::kFlightSection:  return "flight_section";
  case StoryPhase::kBossFight:      return "boss_fight";
  case StoryPhase::kBossDefeated:   return "boss_defeated";
  case StoryPhase::kStageComplete:  return "stage_complete";
  case StoryPhase::kFinalBoss:      return "final_boss";
  case StoryPhase::kStoryComplete:  return "story_complete";
  }
  return "unknown";
}

} // namespace nexus::gameplay
