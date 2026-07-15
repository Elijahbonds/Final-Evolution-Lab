#include "nexus/gameplay/story_mode.h"

#include "nexus/gameplay/character_anim_state.h"

#include <algorithm>
#include <cmath>

namespace nexus::gameplay {

namespace {

constexpr float kObstacleDamage   = 10.0F;
constexpr float kWalkSpeed        = 3.5F;   // m/s — normal traversal
constexpr float kRunSpeed         = 7.0F;   // m/s — sprint when far from target
constexpr float kCameraArmLength  = 9.0F;   // metres behind player
constexpr float kCameraHeight     = 4.5F;   // metres above player
constexpr float kCameraLaziness   = 4.5F;   // smaller = faster follow

// Return the run/walk speed scaled by PRQ
[[nodiscard]] auto traversalSpeed(float movementScale, bool sprint) -> float {
  const float base = sprint ? kRunSpeed : kWalkSpeed;
  return base * std::clamp(movementScale, 0.7F, 2.8F);
}

// Pick the right anim clip for the player's current traversal state
[[nodiscard]] auto traversalClip(bool moving, bool sprint, bool onRail,
                                 bool airborne) -> std::string_view {
  if (onRail)    return clips::kGrindLoop;
  if (airborne)  return clips::kFlightGlide;
  if (!moving)   return clips::kIdle;
  return sprint ? clips::kRun : clips::kWalk;
}

} // namespace

// ── StoryCamera ───────────────────────────────────────────────────────────────

void StoryCamera::follow(Vec3 playerPos, float playerYaw, double dt) noexcept {
  // Soft-follow: lerp camera toward desired position behind player
  const float rad    = playerYaw * (3.14159265F / 180.0F);
  const Vec3 back    = { -std::sin(rad), 0.0F, -std::cos(rad) };
  const Vec3 desired = {
      playerPos.x + back.x * kCameraArmLength,
      playerPos.y + kCameraHeight,
      playerPos.z + back.z * kCameraArmLength,
  };

  const float alpha = std::min(1.0F, static_cast<float>(dt) * kCameraLaziness);
  position.x += (desired.x - position.x) * alpha;
  position.y += (desired.y - position.y) * alpha;
  position.z += (desired.z - position.z) * alpha;

  // Look slightly above player's feet
  target = { playerPos.x, playerPos.y + 1.2F, playerPos.z };
  yawDegrees = playerYaw;
}

// ── StoryMode ────────────────────────────────────────────────────────────────

void StoryMode::reset() {
  m_phase          = StoryPhase::kBoardTraversal;
  m_tokenPos       = 0;
  m_bossesDefeated = 0;
  m_diceRolls      = 0;
  m_lastDice       = 0;
  m_shards         = ShardInventory{};
  m_spaceCleared.fill(false);

  // Place player at the start space position
  const Vec3 startPos = kBoardSpaces[0].worldPos;
  m_player3D.position = startPos;
  m_player3D.yawDegrees = 0.0F;
  m_player3D.setClip(std::string(clips::kIdle));

  m_boss3D = CharacterState3D{};
  m_camera  = StoryCamera{};
  m_camera.follow(startPos, 0.0F, 0.1);

  m_health.reset();
  m_boss  = EnemyAI{};
  m_streamMgr.reset();
  m_rail.reset();
  m_flight.reset();

  refreshObjective();
}

void StoryMode::update(double deltaSeconds) {
  const auto physics = currentPhysics();

  m_streamMgr.update();
  m_rail.update(deltaSeconds, physics.grindAcceleration);
  m_flight.update(deltaSeconds, physics);

  // Update player animation clip based on traversal state
  const bool onRail   = m_rail.isGrinding();
  const bool airborne = m_flight.isAirborne();
  const bool moving   = m_player3D.velocity.x != 0.0F || m_player3D.velocity.z != 0.0F;
  const bool sprint   = m_player3D.velocity.length() > kWalkSpeed * 1.2F;

  const std::string_view clip = traversalClip(moving, sprint, onRail, airborne);
  if (m_player3D.animClip.name != std::string(clip)) {
    m_player3D.setClip(std::string(clip), /*loop=*/true,
                       sprint ? physics.movementSpeedScale : 1.0F);
  }

  // Soft-stop velocity when not actively moving (drag)
  if (!moving) {
    m_player3D.velocity = {};
  }

  // Update camera
  m_camera.follow(m_player3D.position, m_player3D.yawDegrees, deltaSeconds);

  // Boss fight loop
  if (m_phase == StoryPhase::kBossFight || m_phase == StoryPhase::kFinalBoss) {
    m_boss.update(deltaSeconds);

    // Animate boss character
    if (m_boss.state().attacking) {
      m_boss3D.setClip(std::string(clips::kKarateHeavyP), /*loop=*/false);
    } else if (!m_boss3D.animClip.loop) {
      m_boss3D.setClip(std::string(clips::kKarateIdle));
    }

    if (!m_boss.state().alive && m_phase != StoryPhase::kBossDefeated) {
      m_phase = StoryPhase::kBossDefeated;
      ++m_bossesDefeated;
      m_shards.combat += 50.0F;
      m_spaceCleared[static_cast<std::size_t>(m_tokenPos)] = true;
      m_boss3D.setClip(std::string(clips::kKarateDown), /*loop=*/false);
      m_player3D.setClip(std::string(clips::kKarateWin), /*loop=*/false);
      refreshObjective();
      checkStoryComplete();
    }
  }
}

// ── Free movement ─────────────────────────────────────────────────────────────

auto StoryMode::move(float dx, float dz) -> Result<nlohmann::json> {
  if (m_phase == StoryPhase::kBossFight || m_phase == StoryPhase::kFinalBoss) {
    return Result<nlohmann::json>::err("cannot move freely during boss fight");
  }
  if (m_phase == StoryPhase::kStoryComplete) {
    return Result<nlohmann::json>::ok(stateJson());
  }

  const float len = std::sqrt(dx * dx + dz * dz);
  if (len < 0.01F) {
    // No input — zero velocity, idle
    m_player3D.velocity = {};
    return Result<nlohmann::json>::ok({
        {"moved", false},
        {"player_pos", {{"x", m_player3D.position.x},
                        {"y", m_player3D.position.y},
                        {"z", m_player3D.position.z}}},
    });
  }

  const auto physics  = currentPhysics();
  const float normDx  = dx / len;
  const float normDz  = dz / len;
  const bool  sprint  = len > 0.75F;
  const float spd     = traversalSpeed(physics.movementSpeedScale, sprint);

  m_player3D.velocity = { normDx * spd, 0.0F, normDz * spd };

  // Update facing yaw
  m_player3D.yawDegrees = std::atan2(normDx, normDz) * (180.0F / 3.14159265F);

  // Constrain to a reasonable arena boundary around the board
  constexpr float kBoundary = 18.0F;
  m_player3D.position.x = std::clamp(
      m_player3D.position.x + normDx * spd * (1.0F / 60.0F), -kBoundary, kBoundary);
  m_player3D.position.z = std::clamp(
      m_player3D.position.z + normDz * spd * (1.0F / 60.0F), -kBoundary, kBoundary);

  return Result<nlohmann::json>::ok({
      {"moved", true},
      {"sprint", sprint},
      {"speed", spd},
      {"anim_clip", m_player3D.animClip.name},
      {"player_pos", {{"x", m_player3D.position.x},
                      {"y", m_player3D.position.y},
                      {"z", m_player3D.position.z}}},
      {"yaw_degrees", m_player3D.yawDegrees},
  });
}

// ── NPC interaction ───────────────────────────────────────────────────────────

auto StoryMode::interact() -> Result<nlohmann::json> {
  const StoryNpc* npc = nearestNpc();
  if (!npc) {
    return Result<nlohmann::json>::err("no NPC within interaction range");
  }

  // Handle purchase: check shard cost
  if (npc->shardCost > 0) {
    if (m_shards.total() < static_cast<float>(npc->shardCost)) {
      return Result<nlohmann::json>::err(
          std::string("not enough shards — need ") + std::to_string(npc->shardCost));
    }
    // Deduct from bonus shards first, then combat, then others
    float remaining = static_cast<float>(npc->shardCost);
    auto deduct = [&](float& pool) {
      const float take = std::min(pool, remaining);
      pool -= take;
      remaining -= take;
    };
    deduct(m_shards.bonus);
    deduct(m_shards.combat);
    deduct(m_shards.carnival);
    deduct(m_shards.grind);
    deduct(m_shards.flight);
  }

  return Result<nlohmann::json>::ok({
      {"npc_id",      std::string(npc->id)},
      {"npc_name",    std::string(npc->displayName)},
      {"npc_type",    static_cast<int>(npc->type)},
      {"greet",       std::string(npc->greetLine)},
      {"action",      std::string(npc->actionLine)},
      {"shard_cost",  npc->shardCost},
      {"shards_remaining", m_shards.total()},
      {"npc_pos", {{"x", npc->worldPos.x},
                   {"y", npc->worldPos.y},
                   {"z", npc->worldPos.z}}},
  });
}

// ── Board game ────────────────────────────────────────────────────────────────

auto StoryMode::rollAndMove() -> Result<nlohmann::json> {
  if (m_phase == StoryPhase::kBossFight || m_phase == StoryPhase::kFinalBoss) {
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

  const auto& space = kBoardSpaces[static_cast<std::size_t>(m_tokenPos)];
  m_streamMgr.activateZone(space.zone);

  // Move player avatar toward the landing space
  m_player3D.position = space.worldPos;
  m_player3D.setClip(std::string(clips::kRun), true, currentPhysics().movementSpeedScale);
  m_camera.follow(m_player3D.position, m_player3D.yawDegrees, 0.1);

  resolveSpaceLanding(m_tokenPos);

  nlohmann::json payload = stateJson();
  payload["dice_roll"] = {
      {"value",      m_lastDice},
      {"from_space", prevPos},
      {"to_space",   m_tokenPos},
      {"space_type", spaceTypeLabel(space.type)},
      {"zone",       static_cast<int>(space.zone)},
  };

  // Include zone narrative on first visit to a new zone
  const auto zoneIdx = static_cast<std::size_t>(space.zone);
  if (zoneIdx < kZoneNarratives.size()) {
    payload["zone_narrative"] = {
        {"zone_name",   std::string(kZoneNarratives[zoneIdx].zoneName)},
        {"description", std::string(kZoneNarratives[zoneIdx].description)},
        {"objective",   std::string(kZoneNarratives[zoneIdx].objective)},
    };
  }

  return Result<nlohmann::json>::ok(std::move(payload));
}

void StoryMode::resolveSpaceLanding(int spaceIndex) {
  const auto& space = kBoardSpaces[static_cast<std::size_t>(spaceIndex)];

  switch (space.type) {
  case BoardSpaceType::kBonus:
    m_shards.bonus += space.bonusValue;
    m_phase = StoryPhase::kBoardTraversal;
    break;

  case BoardSpaceType::kCarnival:
    m_shards.carnival += space.bonusValue * 0.5F;
    m_phase = StoryPhase::kBoardTraversal;
    break;

  case BoardSpaceType::kRailZone:
    m_phase = StoryPhase::kRailSection;
    break;

  case BoardSpaceType::kFlightZone:
    m_phase = StoryPhase::kFlightSection;
    break;

  case BoardSpaceType::kObstacle:
    m_health.applyDamage(kObstacleDamage);
    m_player3D.setClip(std::string(clips::kKarateHit), /*loop=*/false);
    m_phase = StoryPhase::kBoardTraversal;
    break;

  case BoardSpaceType::kBossZone:
    // Wait for explicit enterBossZone() command; remain in traversal.
    m_phase = StoryPhase::kBoardTraversal;
    break;
  }

  refreshObjective();
}

// ── Traversal commands ────────────────────────────────────────────────────────

auto StoryMode::jump() -> Result<nlohmann::json> {
  auto result = m_flight.jump();
  if (result.isOk()) {
    m_player3D.setClip(std::string(clips::kJump), /*loop=*/false);
  }
  return result;
}

auto StoryMode::activateFlight() -> Result<nlohmann::json> {
  const auto physics = currentPhysics();
  auto result = m_flight.activateFlight(physics);
  if (result.isOk()) {
    m_player3D.setClip(std::string(clips::kFlightGlide));
    if (m_phase == StoryPhase::kFlightSection) {
      m_shards.flight += 10.0F;
    }
  }
  return result;
}

auto StoryMode::triggerFlightBoost() -> Result<nlohmann::json> {
  const auto physics = currentPhysics();
  auto result = m_flight.triggerBoost(physics);
  if (result.isOk()) {
    m_player3D.setClip(std::string(clips::kFlightBoost), /*loop=*/false);
  }
  return result;
}

auto StoryMode::tryGrindSnap(float px, float py, float pz) -> Result<nlohmann::json> {
  const auto physics = currentPhysics();
  auto result = m_rail.trySnapToRail({px, py, pz}, physics.grindAcceleration);
  if (result.isOk()) {
    m_player3D.setClip(std::string(clips::kGrindEnter), /*loop=*/false);
    if (m_phase == StoryPhase::kRailSection) {
      m_shards.grind += 5.0F;
    }
  }
  return result;
}

auto StoryMode::grindTrick(std::string_view trickName) -> Result<nlohmann::json> {
  auto result = m_rail.performTrick(trickName);
  if (result.isOk()) {
    m_shards.grind += result.value().value("bonus", 0.0F);
    m_player3D.setClip(std::string(clips::kGrindTrick), /*loop=*/false);
  }
  return result;
}

auto StoryMode::exitGrind() -> Result<nlohmann::json> {
  auto result = m_rail.exitGrind();
  if (result.isOk()) {
    m_shards.grind += result.value().value("grind_score", 0.0F) * 0.1F;
    m_player3D.setClip(std::string(clips::kGrindJump), /*loop=*/false);
    if (m_phase == StoryPhase::kRailSection) {
      m_phase = StoryPhase::kBoardTraversal;
      refreshObjective();
    }
  }
  return result;
}

// ── Boss fight ────────────────────────────────────────────────────────────────

auto StoryMode::enterBossZone() -> Result<nlohmann::json> {
  if (m_phase == StoryPhase::kBossFight || m_phase == StoryPhase::kFinalBoss) {
    return Result<nlohmann::json>::err("boss fight already active");
  }
  const auto& space = kBoardSpaces[static_cast<std::size_t>(m_tokenPos)];
  if (space.type != BoardSpaceType::kBossZone) {
    return Result<nlohmann::json>::err("current space is not a boss zone");
  }
  if (m_spaceCleared[static_cast<std::size_t>(m_tokenPos)]) {
    return Result<nlohmann::json>::err("boss already defeated here");
  }

  const auto zoneIdx = static_cast<std::size_t>(space.zone);
  const auto& boss = kZoneBosses[zoneIdx < kZoneBosses.size() ? zoneIdx : kZoneBosses.size() - 1];

  m_boss.configure(boss.maxHp, boss.speedScale, boss.aggression);
  m_phase = (space.zone == StageZoneId::kRooftopRow && m_bossesDefeated >= kBossCount)
                ? StoryPhase::kFinalBoss
                : StoryPhase::kBossFight;

  // Place boss opposite the player
  m_boss3D.position = { m_player3D.position.x, 0.0F, m_player3D.position.z + 3.5F };
  m_boss3D.yawDegrees = 180.0F;
  m_boss3D.setClip(std::string(clips::kKarateIdle));

  m_player3D.setClip(std::string(clips::kKarateIdle));
  m_streamMgr.activateZone(space.zone);
  refreshObjective();

  return Result<nlohmann::json>::ok({
      {"boss_name",       std::string(boss.name)},
      {"boss_hp",         boss.maxHp},
      {"boss_intro",      std::string(boss.introQuote)},
      {"zone",            static_cast<int>(space.zone)},
      {"is_final_boss",   m_phase == StoryPhase::kFinalBoss},
      {"story_phase",     storyPhaseLabel(m_phase)},
      {"boss_pos", {{"x", m_boss3D.position.x},
                    {"y", m_boss3D.position.y},
                    {"z", m_boss3D.position.z}}},
  });
}

auto StoryMode::bossCombat(CombatAction action) -> Result<nlohmann::json> {
  if (m_phase != StoryPhase::kBossFight && m_phase != StoryPhase::kFinalBoss) {
    return Result<nlohmann::json>::err("not in boss fight");
  }

  const bool  bossAttacking = m_boss.state().attacking;
  const float bossTimer     = m_boss.state().attackTimer;
  const auto  outcome       = CombatSystem::resolve(action, bossAttacking, bossTimer);

  // Player animation
  switch (action) {
  case CombatAction::kLightStrike: m_player3D.setClip(std::string(clips::kKarateLightP), false); break;
  case CombatAction::kHeavyStrike: m_player3D.setClip(std::string(clips::kKarateHeavyP), false); break;
  case CombatAction::kBlock:       m_player3D.setClip(std::string(clips::kKarateBlock),   false); break;
  case CombatAction::kDodge:       m_player3D.setClip(std::string(clips::kKarateDodge),   false); break;
  case CombatAction::kCounter:     m_player3D.setClip(std::string(clips::kKarateCounter), false); break;
  }

  if (outcome.damageDealt > 0.0F) {
    m_boss.applyDamage(outcome.damageDealt);
    m_boss3D.setClip(std::string(clips::kKarateHit), /*loop=*/false);
  }

  if (bossAttacking && !outcome.blocked && !outcome.countered) {
    m_health.applyDamage(8.0F);
    m_player3D.setClip(std::string(clips::kKarateHit), /*loop=*/false);
  }

  const bool bossDefeated = !m_boss.state().alive;
  if (bossDefeated) {
    ++m_bossesDefeated;
    m_shards.combat += 50.0F;
    m_spaceCleared[static_cast<std::size_t>(m_tokenPos)] = true;
    m_phase = StoryPhase::kBossDefeated;
    m_boss3D.setClip(std::string(clips::kKarateDown), /*loop=*/false);
    m_player3D.setClip(std::string(clips::kKarateWin), /*loop=*/false);

    // Get boss defeated quote
    const auto& space  = kBoardSpaces[static_cast<std::size_t>(m_tokenPos)];
    const auto  zoneIdx = static_cast<std::size_t>(space.zone);
    const auto& boss    = kZoneBosses[zoneIdx < kZoneBosses.size() ? zoneIdx : kZoneBosses.size()-1];

    refreshObjective();
    checkStoryComplete();

    nlohmann::json payload = stateJson();
    payload["combat"] = {
        {"action", CombatSystem::actionLabel(action)},
        {"damage_dealt", outcome.damageDealt},
        {"blocked", outcome.blocked},
        {"countered", outcome.countered},
        {"boss_defeated", true},
        {"boss_defeated_quote", std::string(boss.defeatedShard)},
        {"boss_hp", 0.0F},
        {"player_hp", m_health.hp()},
    };
    return Result<nlohmann::json>::ok(std::move(payload));
  }

  nlohmann::json payload = stateJson();
  payload["combat"] = {
      {"action", CombatSystem::actionLabel(action)},
      {"damage_dealt", outcome.damageDealt},
      {"blocked", outcome.blocked},
      {"countered", outcome.countered},
      {"boss_defeated", false},
      {"boss_hp", m_boss.state().hp},
      {"player_hp", m_health.hp()},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto StoryMode::travelToZone(StageZoneId zone) -> Result<nlohmann::json> {
  if (!m_streamMgr.activateZone(zone)) {
    return Result<nlohmann::json>::err("invalid zone");
  }
  const auto zoneIdx = static_cast<std::size_t>(zone);
  const auto& meta   = m_streamMgr.meta(zone);
  return Result<nlohmann::json>::ok({
      {"zone",       static_cast<int>(zone)},
      {"zone_name",  meta.name},
      {"stream_state", "streaming"},
      {"zone_narrative", zoneIdx < kZoneNarratives.size()
          ? nlohmann::json{
              {"description", std::string(kZoneNarratives[zoneIdx].description)},
              {"objective",   std::string(kZoneNarratives[zoneIdx].objective)},
            }
          : nlohmann::json{nullptr}},
  });
}

// ── stateJson ─────────────────────────────────────────────────────────────────

auto StoryMode::stateJson() const -> nlohmann::json {
  const auto& space  = kBoardSpaces[static_cast<std::size_t>(m_tokenPos)];
  const Vec3  tPos   = space.worldPos;

  // Board spaces cleared
  nlohmann::json cleared = nlohmann::json::array();
  for (int i = 0; i < kBoardSpaceCount; ++i) {
    if (m_spaceCleared[static_cast<std::size_t>(i)]) {
      cleared.push_back(i);
    }
  }

  // Nearby NPCs visible to renderer
  nlohmann::json npcList = nlohmann::json::array();
  for (const StoryNpc& npc : kBoardwalkNpcs) {
    const float dist = m_player3D.position.distanceTo(npc.worldPos);
    npcList.push_back({
        {"id",         std::string(npc.id)},
        {"name",       std::string(npc.displayName)},
        {"type",       static_cast<int>(npc.type)},
        {"pos", {{"x", npc.worldPos.x}, {"y", npc.worldPos.y}, {"z", npc.worldPos.z}}},
        {"greet",      std::string(npc.greetLine)},
        {"shard_cost", npc.shardCost},
        {"in_range",   dist <= npc.interactRadius},
        {"distance",   dist},
    });
  }

  return {
      {"story_phase",      storyPhaseLabel(m_phase)},
      {"token_position",   m_tokenPos},
      {"space_type",       spaceTypeLabel(space.type)},
      {"token_world_pos",  {{"x", tPos.x}, {"y", tPos.y}, {"z", tPos.z}}},

      // Shard inventory breakdown
      {"shards", {
          {"total",    m_shards.total()},
          {"carnival", m_shards.carnival},
          {"combat",   m_shards.combat},
          {"grind",    m_shards.grind},
          {"flight",   m_shards.flight},
          {"bonus",    m_shards.bonus},
      }},

      {"bosses_defeated",  m_bossesDefeated},
      {"dice_rolls",       m_diceRolls},
      {"last_dice",        m_lastDice},
      {"player_hp",        m_health.hp()},
      {"is_complete",      isComplete()},
      {"spaces_cleared",   cleared},

      // Objective
      {"objective", {
          {"text",      m_objective.text},
          {"hint",      m_objective.hint},
          {"completed", m_objective.completed},
      }},

      // Player 3D avatar
      {"player_3d", {
          {"pos",       {{"x", m_player3D.position.x},
                         {"y", m_player3D.position.y},
                         {"z", m_player3D.position.z}}},
          {"velocity",  {{"x", m_player3D.velocity.x},
                         {"y", m_player3D.velocity.y},
                         {"z", m_player3D.velocity.z}}},
          {"yaw",       m_player3D.yawDegrees},
          {"anim_clip", m_player3D.animClip.name},
          {"anim_loop", m_player3D.animClip.loop},
          {"speed_scale", m_player3D.animClip.speedScale},
      }},

      // Boss 3D avatar (only meaningful during boss fight)
      {"boss_3d", {
          {"pos",       {{"x", m_boss3D.position.x},
                         {"y", m_boss3D.position.y},
                         {"z", m_boss3D.position.z}}},
          {"yaw",       m_boss3D.yawDegrees},
          {"anim_clip", m_boss3D.animClip.name},
          {"anim_loop", m_boss3D.animClip.loop},
          {"boss_hp",   m_boss.state().alive ? m_boss.state().hp : 0.0F},
          {"attacking", m_boss.state().attacking},
      }},

      // Camera
      {"camera", {
          {"pos",   {{"x", m_camera.position.x},
                     {"y", m_camera.position.y},
                     {"z", m_camera.position.z}}},
          {"target",{{"x", m_camera.target.x},
                     {"y", m_camera.target.y},
                     {"z", m_camera.target.z}}},
          {"fov",   m_camera.fovDegrees},
          {"yaw",   m_camera.yawDegrees},
          {"pitch", m_camera.pitchDegrees},
      }},

      // NPCs
      {"npcs", npcList},

      // Subsystems
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
    m_player3D.setClip(std::string(clips::kKarateWin));
    m_objective.set("You've conquered the Boardwalk. The court is yours.",
                    "Watch the credits and share your run.");
    m_objective.completed = true;
  } else if (m_phase == StoryPhase::kBossDefeated) {
    m_phase = StoryPhase::kBoardTraversal;
  }
}

void StoryMode::refreshObjective() {
  switch (m_phase) {
  case StoryPhase::kBoardTraversal: {
    // Find the nearest uncleared boss zone
    bool anyBossLeft = false;
    for (int i = 0; i < kBoardSpaceCount; ++i) {
      if (kBoardSpaces[static_cast<std::size_t>(i)].type == BoardSpaceType::kBossZone &&
          !m_spaceCleared[static_cast<std::size_t>(i)]) {
        anyBossLeft = true;
        break;
      }
    }
    if (!anyBossLeft) {
      m_objective.set("All zone bosses cleared. Head to Rooftop Row and face The Architect.",
                      "Roll the dice to reach space 19.");
    } else {
      m_objective.set("Roll the dice and advance your token. Land on a Boss Zone to fight.",
                      "Tap ROLL to move. Explore carnival and bonus spaces for shards.");
    }
    break;
  }
  case StoryPhase::kRailSection:
    m_objective.set("Grind the rails! Score as many trick points as you can.",
                    "Snap to a rail, then use TRICK to add bonus score. EXIT to leave.");
    break;
  case StoryPhase::kFlightSection:
    m_objective.set("Take flight over the zone. Use BOOST if your PRQ is high enough.",
                    "JUMP → FLY to glide. FLY_BOOST for a PRQ-powered speed burst.");
    break;
  case StoryPhase::kBossFight:
  case StoryPhase::kFinalBoss: {
    const auto& space   = kBoardSpaces[static_cast<std::size_t>(m_tokenPos)];
    const auto  zoneIdx = static_cast<std::size_t>(space.zone);
    const auto& boss    = kZoneBosses[zoneIdx < kZoneBosses.size() ? zoneIdx : kZoneBosses.size()-1];
    m_objective.set(std::string("Defeat ") + std::string(boss.name) + "!",
                    "Use light strikes to build pressure, heavy for big damage, counter on attack.");
    break;
  }
  case StoryPhase::kBossDefeated:
    m_objective.set("Boss defeated. Collect your shards and keep moving.",
                    "Roll again when you're ready.");
    m_objective.completed = true;
    break;
  case StoryPhase::kStageComplete:
    m_objective.set("Zone complete. New spaces are unlocked.",
                    "Roll to discover what's ahead.");
    break;
  case StoryPhase::kStoryComplete:
    m_objective.set("Story complete. The Boardwalk is yours.",
                    "");
    m_objective.completed = true;
    break;
  }
}

auto StoryMode::currentPhysics() const -> ArcadePhysicsParams {
  return ArcadePhysics::fromPRQ(PRQEngine::getScore(), PRQEngine::getNeuralDrive());
}

auto StoryMode::nearestNpc() const -> const StoryNpc* {
  const StoryNpc* best = nullptr;
  float bestDist = std::numeric_limits<float>::max();
  for (const StoryNpc& npc : kBoardwalkNpcs) {
    const float dist = m_player3D.position.distanceTo(npc.worldPos);
    if (dist <= npc.interactRadius && dist < bestDist) {
      bestDist = dist;
      best = &npc;
    }
  }
  return best;
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
