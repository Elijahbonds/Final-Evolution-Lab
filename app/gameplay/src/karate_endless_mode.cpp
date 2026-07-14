#include "nexus/gameplay/karate_endless_mode.h"
#include "nexus/gameplay/character_anim_state.h"

#include <algorithm>
#include <cmath>
#include <string>

namespace nexus::gameplay {

namespace {
constexpr float kRegenRateMin              = 0.5F;
constexpr float kRegenRateMax              = 2.0F;
constexpr int   kSpecialMoveComboThreshold = 8;
constexpr float kArenaRadius              = 7.5F;  // dojo half-width
} // namespace

// ── Camera3D ─────────────────────────────────────────────────────────────────
void Camera3D::trackPlayer(Vec3 playerPos, Vec3 lockedEnemyPos, bool hasLockOn,
                           bool jutsuing, double dt) noexcept {
  const float blend = std::min(1.0F, static_cast<float>(dt) * 6.0F); // smooth follow

  if (jutsuing) {
    // Zoom in dramatically for jutsu cinematic
    const Vec3 cinPos = playerPos + Vec3{0.0F, 3.5F, -6.0F};
    position.x += (cinPos.x - position.x) * blend * 2.0F;
    position.y += (cinPos.y - position.y) * blend * 2.0F;
    position.z += (cinPos.z - position.z) * blend * 2.0F;
    fovDegrees  = 55.0F; // zoom in
    cinematic   = true;
    target      = playerPos + Vec3{0.0F, 1.2F, 0.0F};
    return;
  }

  cinematic  = false;
  fovDegrees = 75.0F;

  if (hasLockOn) {
    // Naruto Storm lock-on: camera sits between player and enemy, looking at midpoint
    const Vec3 mid   = (playerPos + lockedEnemyPos) * 0.5F;
    const Vec3 camDir = (playerPos - lockedEnemyPos).normalized();
    const Vec3 desiredPos = mid + camDir * 10.0F + Vec3{0.0F, 4.0F, 0.0F};
    position.x += (desiredPos.x - position.x) * blend;
    position.y += (desiredPos.y - position.y) * blend;
    position.z += (desiredPos.z - position.z) * blend;
    target = mid + Vec3{0.0F, 1.0F, 0.0F};
  } else {
    // Default: orbit behind player
    const Vec3 desiredPos = playerPos + Vec3{0.0F, 5.5F, -11.0F};
    position.x += (desiredPos.x - position.x) * blend;
    position.y += (desiredPos.y - position.y) * blend;
    position.z += (desiredPos.z - position.z) * blend;
    target = playerPos + Vec3{0.0F, 1.2F, 0.0F};
  }
}

// ─────────────────────────────────────────────────────────────────────────────
void KarateEndlessMode::reset() {
  m_playerCount = 1;
  m_activePlayer = 0;
  for (auto& slot : m_players) {
    slot = KaratePlayerSlot{};
    slot.health.reset();
  }
  m_waves  = WaveSpawner{};
  m_enemies.clear();
  m_perks  = {};
  m_perkClaimedThisIntermission = false;
  m_phase  = KarateWavePhase::kCombat;
  m_comboChain  = 0;
  m_maxComboChain = 0;
  m_criticalHits = 0;
  m_comboMultiplier = 1.0F;
  m_score = 0;
  m_opponentsDefeated = 0;
  m_chakra = 0.0F;
  m_lockedEnemyIndex = -1;
  m_dashTimer = 0.0F;
  m_dashCooldownTimer = 0.0F;
  m_dashDirection = {};
  m_jutsuTimer = 0.0F;
  m_player3D = CharacterState3D{{0.0F, 0.0F, -4.0F}};
  m_player3D.setClip(std::string(clips::kKarateIdle));
  m_lastAnimAction = "idle";
  for (auto& e : m_enemy3D) {
    e = CharacterState3D{};
    e.setClip(std::string(clips::kKarateIdle));
  }
  m_camera = Camera3D{};
}

void KarateEndlessMode::configureCoop(int playerCount) {
  m_playerCount = std::clamp(playerCount, 1, kMaxPlayers);
  m_activePlayer = 0;
  for (int i = 0; i < kMaxPlayers; ++i) {
    m_players[static_cast<std::size_t>(i)] = KaratePlayerSlot{};
    if (i < m_playerCount) {
      m_players[static_cast<std::size_t>(i)].health.reset();
    }
  }
  m_waves = WaveSpawner{};
  m_enemies.clear();
  m_perks = {};
  m_perkClaimedThisIntermission = false;
  m_phase = KarateWavePhase::kCombat;
  m_comboChain = 0; m_maxComboChain = 0; m_criticalHits = 0;
  m_comboMultiplier = 1.0F;
  m_score = 0; m_opponentsDefeated = 0;
  m_chakra = 0.0F; m_lockedEnemyIndex = -1;
  m_dashTimer = 0.0F; m_dashCooldownTimer = 0.0F;
  m_jutsuTimer = 0.0F;
  m_player3D = CharacterState3D{{0.0F, 0.0F, -4.0F}};
  m_player3D.setClip(std::string(clips::kKarateIdle));
}

// ─────────────────────────────────────────────────────────────────────────────
auto KarateEndlessMode::activeSlot() -> KaratePlayerSlot& {
  return m_players[static_cast<std::size_t>(m_activePlayer)];
}
auto KarateEndlessMode::activeSlot() const -> const KaratePlayerSlot& {
  return m_players[static_cast<std::size_t>(m_activePlayer)];
}

auto KarateEndlessMode::allPlayersDefeated() const -> bool {
  for (int i = 0; i < m_playerCount; ++i) {
    if (!m_players[static_cast<std::size_t>(i)].health.isDefeated()) return false;
  }
  return true;
}

auto KarateEndlessMode::isSessionOver() const -> bool {
  return m_phase == KarateWavePhase::kVictory || m_phase == KarateWavePhase::kDefeat;
}

auto KarateEndlessMode::wavePhaseLabel() const -> std::string_view {
  switch (m_phase) {
  case KarateWavePhase::kCombat:       return "combat";
  case KarateWavePhase::kIntermission: return "intermission";
  case KarateWavePhase::kJutsu:        return "jutsu";
  case KarateWavePhase::kVictory:      return "victory";
  case KarateWavePhase::kDefeat:       return "defeat";
  }
  return "combat";
}

auto KarateEndlessMode::scaledOpponentCount(int base) const -> int {
  return std::max(1, base + (m_playerCount - 1));
}

auto KarateEndlessMode::damageMultiplier() const -> float {
  float m = 1.0F;
  if (m_perks.power) m *= 1.35F;
  if (m_comboChain >= kSpecialMoveComboThreshold) m *= 1.5F;
  return m;
}

auto KarateEndlessMode::damageTakenMultiplier() const -> float {
  float m = 0.85F + static_cast<float>(m_playerCount) * 0.08F;
  if (m_perks.guard) m *= 0.65F;
  return m;
}

// ─────────────────────────────────────────────────────────────────────────────
// FREE MOVEMENT
// ─────────────────────────────────────────────────────────────────────────────
auto KarateEndlessMode::movePlayer(float dx, float dz, double deltaSeconds) -> Result<nlohmann::json> {
  if (isSessionOver()) return Result<nlohmann::json>::err("session ended");

  // If dashing, movement is driven by dash direction
  if (m_dashTimer > 0.0F) {
    return Result<nlohmann::json>::ok(stateJson());
  }

  const float len = std::sqrt(dx * dx + dz * dz);
  if (len > 1e-4F) { dx /= len; dz /= len; }

  const float speed = m_perks.speed ? kPlayerMoveSpeed * 1.3F : kPlayerMoveSpeed;
  const float dt    = static_cast<float>(deltaSeconds);
  m_player3D.position.x += dx * speed * dt;
  m_player3D.position.z += dz * speed * dt;

  // Clamp to circular dojo arena
  const float dist = std::sqrt(m_player3D.position.x * m_player3D.position.x +
                               m_player3D.position.z * m_player3D.position.z);
  if (dist > kArenaRadius) {
    const float scale = kArenaRadius / dist;
    m_player3D.position.x *= scale;
    m_player3D.position.z *= scale;
  }

  // Update facing: if locked on, face the enemy; otherwise face movement direction
  if (m_lockedEnemyIndex >= 0 && m_lockedEnemyIndex < static_cast<int>(m_enemy3D.size())) {
    const Vec3 toEnemy = (m_enemy3D[static_cast<std::size_t>(m_lockedEnemyIndex)].position
                         - m_player3D.position).normalized();
    if (toEnemy.x != 0.0F || toEnemy.z != 0.0F) {
      m_player3D.yawDegrees = std::atan2(toEnemy.x, toEnemy.z) * (180.0F / 3.14159265F);
    }
  } else if (len > 0.05F) {
    m_player3D.yawDegrees = std::atan2(dx, dz) * (180.0F / 3.14159265F);
  }

  const bool moving = len > 0.05F;
  if (moving) {
    const std::string clip = m_perks.speed ? std::string(clips::kSprint) : std::string(clips::kRun);
    m_player3D.setClip(clip);
  } else {
    m_player3D.setClip(std::string(clips::kKarateIdle));
  }

  return Result<nlohmann::json>::ok(stateJson());
}

// ─────────────────────────────────────────────────────────────────────────────
auto KarateEndlessMode::dash(std::string_view direction) -> Result<nlohmann::json> {
  if (isSessionOver())        return Result<nlohmann::json>::err("session ended");
  if (m_dashCooldownTimer > 0.0F)
    return Result<nlohmann::json>::err("dash on cooldown");

  Vec3 dir{};
  if (direction == "forward")      dir = {0.0F, 0.0F, 1.0F};
  else if (direction == "back")    dir = {0.0F, 0.0F, -1.0F};
  else if (direction == "left")    dir = {-1.0F, 0.0F, 0.0F};
  else if (direction == "right")   dir = {1.0F, 0.0F, 0.0F};
  else return Result<nlohmann::json>::err("direction must be forward/back/left/right");

  // Rotate dash direction by player yaw
  const float yawRad = m_player3D.yawDegrees * (3.14159265F / 180.0F);
  const float cosY = std::cos(yawRad);
  const float sinY = std::sin(yawRad);
  m_dashDirection = {dir.x * cosY - dir.z * sinY, 0.0F, dir.x * sinY + dir.z * cosY};

  m_dashTimer         = kDashDuration;
  m_dashCooldownTimer = kDashCooldown;
  m_player3D.setClip(std::string(clips::kKarateDodge), false, 1.4F);

  return Result<nlohmann::json>::ok(stateJson());
}

// ─────────────────────────────────────────────────────────────────────────────
auto KarateEndlessMode::lockOn(int enemyIndex) -> Result<nlohmann::json> {
  if (enemyIndex < 0) {
    m_lockedEnemyIndex = -1;
    return Result<nlohmann::json>::ok(stateJson());
  }
  const int aliveCount = static_cast<int>(m_enemies.size());
  if (enemyIndex >= aliveCount) {
    return Result<nlohmann::json>::err("enemy index out of range");
  }
  if (!m_enemies[static_cast<std::size_t>(enemyIndex)].state().alive) {
    // cycle to next alive
    for (int i = 0; i < aliveCount; ++i) {
      const int idx = (enemyIndex + i) % aliveCount;
      if (m_enemies[static_cast<std::size_t>(idx)].state().alive) {
        m_lockedEnemyIndex = idx;
        return Result<nlohmann::json>::ok(stateJson());
      }
    }
    m_lockedEnemyIndex = -1;
    return Result<nlohmann::json>::ok(stateJson());
  }
  m_lockedEnemyIndex = enemyIndex;
  return Result<nlohmann::json>::ok(stateJson());
}

// ─────────────────────────────────────────────────────────────────────────────
auto KarateEndlessMode::jutsu() -> Result<nlohmann::json> {
  if (isSessionOver())   return Result<nlohmann::json>::err("session ended");
  if (m_phase == KarateWavePhase::kIntermission)
    return Result<nlohmann::json>::err("cannot jutsu during intermission");
  if (m_chakra < kChakraCostJutsu)
    return Result<nlohmann::json>::err("not enough chakra — need 80");

  m_chakra     -= kChakraCostJutsu;
  m_phase       = KarateWavePhase::kJutsu;
  m_jutsuTimer  = kJutsuduration;
  m_camera.cinematic = true;

  // Jutsu deals heavy damage to ALL alive enemies in range
  int enemiesHit = 0;
  for (EnemyAI& enemy : m_enemies) {
    if (enemy.state().alive) {
      enemy.applyDamage(kJutsuHpDamage);
      if (!enemy.state().alive) onEnemyDefeated();
      ++enemiesHit;
    }
  }

  const int jutsuScore = enemiesHit * 500 * static_cast<int>(std::round(m_comboMultiplier));
  m_score += jutsuScore;

  m_player3D.setClip("karate_jutsu_wave", false, 0.85F);

  nlohmann::json payload = stateJson();
  payload["jutsu_hit_count"] = enemiesHit;
  payload["jutsu_score"]     = jutsuScore;
  return Result<nlohmann::json>::ok(std::move(payload));
}

// ─────────────────────────────────────────────────────────────────────────────
auto KarateEndlessMode::performAction(CombatAction action, int playerIndex) -> Result<CombatOutcome> {
  if (isSessionOver()) return Result<CombatOutcome>::err("session ended");
  if (m_phase == KarateWavePhase::kIntermission)
    return Result<CombatOutcome>::err("dojo intermission — claim a shrine perk or exfil");
  if (m_phase == KarateWavePhase::kJutsu)
    return Result<CombatOutcome>::err("jutsu in progress");

  const int resolvedPlayer = playerIndex >= 0 ? playerIndex : m_activePlayer;
  if (resolvedPlayer < 0 || resolvedPlayer >= m_playerCount)
    return Result<CombatOutcome>::err("invalid player_index");
  if (m_players[static_cast<std::size_t>(resolvedPlayer)].health.isDefeated())
    return Result<CombatOutcome>::err("player defeated");

  m_activePlayer = resolvedPlayer;
  KaratePlayerSlot& slot = activeSlot();

  // If locked on, target that enemy; otherwise nearest
  const int targetIdx = (m_lockedEnemyIndex >= 0) ? m_lockedEnemyIndex
                                                   : nearestAliveEnemyIndex();
  bool opponentAttacking = false;
  float attackTimer = 0.0F;
  if (targetIdx >= 0 && targetIdx < static_cast<int>(m_enemies.size())) {
    const auto& st = m_enemies[static_cast<std::size_t>(targetIdx)].state();
    opponentAttacking = st.attacking && st.alive;
    attackTimer       = st.attackTimer;
  }

  CombatOutcome outcome = CombatSystem::resolve(action, opponentAttacking, attackTimer);
  outcome.damageDealt  *= damageMultiplier();

  // ── Animation ────────────────────────────────────────────────────────────
  m_lastAnimAction = std::string(CombatSystem::actionLabel(action));
  const AnimClip clip = CharacterAnimStateMachine::combatActionClip(static_cast<int>(action));
  m_player3D.setClip(clip.name, clip.loop, clip.speedScale);

  // ── Face the target during attack ────────────────────────────────────────
  if (targetIdx >= 0 && targetIdx < static_cast<int>(m_enemy3D.size())) {
    const Vec3 toTarget = (m_enemy3D[static_cast<std::size_t>(targetIdx)].position
                          - m_player3D.position).normalized();
    if (toTarget.x != 0.0F || toTarget.z != 0.0F) {
      m_player3D.yawDegrees = std::atan2(toTarget.x, toTarget.z) * (180.0F / 3.14159265F);
    }
  }

  if (action == CombatAction::kBlock && outcome.blocked) {
    return Result<CombatOutcome>::ok(outcome);
  }
  if (action == CombatAction::kDodge) {
    return Result<CombatOutcome>::ok(outcome);
  }

  if (outcome.damageDealt > 0.0F) {
    const int hitTarget = targetIdx >= 0 ? targetIdx : 0;
    if (hitTarget < static_cast<int>(m_enemies.size())) {
      m_enemies[static_cast<std::size_t>(hitTarget)].applyDamage(outcome.damageDealt);
      if (!m_enemies[static_cast<std::size_t>(hitTarget)].state().alive) {
        onEnemyDefeated();
        // If we killed the locked target, release lock
        if (m_lockedEnemyIndex == hitTarget) m_lockedEnemyIndex = -1;
      }
    }
    ++m_comboChain;
    slot.comboChain    = m_comboChain;
    slot.maxComboChain = std::max(slot.maxComboChain, m_comboChain);
    m_maxComboChain    = std::max(m_maxComboChain, m_comboChain);
    if (outcome.countered) {
      ++m_criticalHits;
      m_chakra = std::min(kChakraMax, m_chakra + kChakraPerCounter);
    } else {
      m_chakra = std::min(kChakraMax, m_chakra + kChakraPerHit);
    }
    const float comboScale = m_perks.speed ? 0.2F : 0.15F;
    m_comboMultiplier = std::min(4.0F, 1.0F + static_cast<float>(m_comboChain) * comboScale);
    m_score += static_cast<int>(outcome.damageDealt * m_comboMultiplier * m_waves.currentWave());
  } else {
    m_comboChain = 0;
    slot.comboChain = 0;
    m_comboMultiplier = 1.0F;
  }

  return Result<CombatOutcome>::ok(outcome);
}

// ─────────────────────────────────────────────────────────────────────────────
void KarateEndlessMode::update(double deltaSeconds) {
  if (isSessionOver()) return;

  // ── Jutsu cinematic phase ─────────────────────────────────────────────────
  if (m_phase == KarateWavePhase::kJutsu) {
    m_jutsuTimer -= static_cast<float>(deltaSeconds);
    if (m_jutsuTimer <= 0.0F) {
      m_phase = KarateWavePhase::kCombat;
      m_player3D.setClip(std::string(clips::kKarateIdle));
    }
    updateCamera(deltaSeconds);
    return;
  }

  // ── Dash physics ──────────────────────────────────────────────────────────
  if (m_dashTimer > 0.0F) {
    const float dt = static_cast<float>(deltaSeconds);
    m_player3D.position = m_player3D.position + m_dashDirection * (kDashSpeed * dt);
    // Clamp to arena
    const float dist = std::sqrt(m_player3D.position.x * m_player3D.position.x +
                                 m_player3D.position.z * m_player3D.position.z);
    if (dist > kArenaRadius) {
      const float s = kArenaRadius / dist;
      m_player3D.position.x *= s;
      m_player3D.position.z *= s;
    }
    m_dashTimer = std::max(0.0F, m_dashTimer - dt);
    if (m_dashTimer <= 0.0F) {
      m_player3D.setClip(std::string(clips::kKarateIdle));
    }
  }
  if (m_dashCooldownTimer > 0.0F) {
    m_dashCooldownTimer -= static_cast<float>(deltaSeconds);
  }

  // ── Wave / health ─────────────────────────────────────────────────────────
  if (allPlayersDefeated()) { m_phase = KarateWavePhase::kDefeat; return; }
  if (activeSlot().health.isDefeated()) advanceActivePlayer();

  m_waves.update(deltaSeconds);
  if (m_phase != KarateWavePhase::kJutsu) {
    m_phase = m_waves.regenPauseActive() ? KarateWavePhase::kIntermission : KarateWavePhase::kCombat;
  }

  if (m_waves.regenPauseActive()) {
    const float regen = kRegenRateMin + (kRegenRateMax - kRegenRateMin) * 0.5F;
    for (int i = 0; i < m_playerCount; ++i) {
      m_players[static_cast<std::size_t>(i)].health.regenerate(deltaSeconds, regen);
    }
  } else {
    m_perkClaimedThisIntermission = false;
    m_perks = {};
  }

  const int expected = scaledOpponentCount(m_waves.opponentsRemaining());
  if (static_cast<int>(m_enemies.size()) != expected) spawnActiveEnemies();

  updateEnemyAI(deltaSeconds);
  updateCamera(deltaSeconds);
}

// ─────────────────────────────────────────────────────────────────────────────
void KarateEndlessMode::updateEnemyAI(double dt) {
  const float dtF = static_cast<float>(dt);
  for (std::size_t i = 0; i < m_enemies.size(); ++i) {
    EnemyAI& enemy = m_enemies[i];
    enemy.update(dt);

    // Move enemy toward player in 3D space
    if (enemy.state().alive && i < m_enemy3D.size()) {
      const Vec3 toPlayer = (m_player3D.position - m_enemy3D[i].position).normalized();
      const float enemySpeed = 3.5F * enemy.state().speedScale;
      m_enemy3D[i].position = m_enemy3D[i].position + toPlayer * (enemySpeed * dtF);
      // Face player
      if (toPlayer.x != 0.0F || toPlayer.z != 0.0F) {
        m_enemy3D[i].yawDegrees =
            std::atan2(toPlayer.x, toPlayer.z) * (180.0F / 3.14159265F);
      }
      m_enemy3D[i].setClip(std::string(clips::kKarateLightP));

      if (enemy.state().attacking && !activeSlot().health.isDefeated()) {
        activeSlot().health.applyDamage(4.0F * enemy.state().aggression * damageTakenMultiplier());
        if (activeSlot().health.isDefeated()) {
          advanceActivePlayer();
          if (allPlayersDefeated()) { m_phase = KarateWavePhase::kDefeat; return; }
        }
      }
    }
  }
}

void KarateEndlessMode::updateCamera(double dt) {
  const auto lockedPos = lockedEnemyPos();
  const Vec3 lockTarget = lockedPos.value_or(Vec3{0.0F, 1.2F, 0.0F});
  m_camera.trackPlayer(m_player3D.position, lockTarget,
                       lockedPos.has_value(),
                       m_phase == KarateWavePhase::kJutsu, dt);
}

// ─────────────────────────────────────────────────────────────────────────────
auto KarateEndlessMode::lockedEnemyPos() const -> std::optional<Vec3> {
  if (m_lockedEnemyIndex < 0 || m_lockedEnemyIndex >= static_cast<int>(m_enemy3D.size())) {
    return std::nullopt;
  }
  return m_enemy3D[static_cast<std::size_t>(m_lockedEnemyIndex)].position;
}

auto KarateEndlessMode::nearestAliveEnemyIndex() const -> int {
  float best = 1e9F;
  int idx = -1;
  for (int i = 0; i < static_cast<int>(m_enemies.size()); ++i) {
    if (!m_enemies[static_cast<std::size_t>(i)].state().alive) continue;
    if (i >= static_cast<int>(m_enemy3D.size())) continue;
    const float d = m_player3D.position.distanceTo(
        m_enemy3D[static_cast<std::size_t>(i)].position);
    if (d < best) { best = d; idx = i; }
  }
  return idx;
}

// ─────────────────────────────────────────────────────────────────────────────
void KarateEndlessMode::advanceActivePlayer() {
  for (int offset = 1; offset <= m_playerCount; ++offset) {
    const int candidate = (m_activePlayer + offset) % m_playerCount;
    if (!m_players[static_cast<std::size_t>(candidate)].health.isDefeated()) {
      m_activePlayer  = candidate;
      m_comboChain    = m_players[static_cast<std::size_t>(m_activePlayer)].comboChain;
      m_comboMultiplier =
          std::min(4.0F, 1.0F + static_cast<float>(m_comboChain) * (m_perks.speed ? 0.2F : 0.15F));
      return;
    }
  }
}

void KarateEndlessMode::spawnActiveEnemies() {
  const WaveConfig config = WaveSpawner::configForWave(std::max(1, m_waves.currentWave()));
  const int count = scaledOpponentCount(m_waves.opponentsRemaining());
  m_enemies.clear();
  m_enemies.resize(static_cast<std::size_t>(count));
  for (EnemyAI& enemy : m_enemies) {
    enemy.configure(config.enemyHp, config.speedScale, config.aggression);
  }
  // Fan enemies around the circular dojo — evenly spaced radially
  const float baseAngle = 0.0F;
  const float step = (count > 1) ? (2.0F * 3.14159265F / static_cast<float>(count)) : 0.0F;
  for (int i = 0; i < count && i < kMaxPlayers; ++i) {
    const float angle = baseAngle + step * static_cast<float>(i);
    const float r = kArenaRadius * 0.75F;
    m_enemy3D[static_cast<std::size_t>(i)] = CharacterState3D{
        {r * std::sin(angle), 0.0F, r * std::cos(angle)}};
    m_enemy3D[static_cast<std::size_t>(i)].yawDegrees = angle * (180.0F / 3.14159265F) + 180.0F;
    m_enemy3D[static_cast<std::size_t>(i)].setClip(std::string(clips::kKarateIdle));
  }
}

void KarateEndlessMode::onEnemyDefeated() {
  ++m_opponentsDefeated;
  m_waves.onOpponentDefeated();
  if (m_waves.opponentsRemaining() == 0 && m_waves.currentWave() >= kTargetWave) {
    onWaveCleared();
  }
}

void KarateEndlessMode::onWaveCleared() {
  if (m_waves.currentWave() >= kTargetWave) {
    m_phase = KarateWavePhase::kVictory;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
auto KarateEndlessMode::handleWaveCommand(const nlohmann::json& params) -> Result<nlohmann::json> {
  if (!params.is_object()) return Result<nlohmann::json>::err("wave params must be object");

  if (params.contains("player_count")) {
    configureCoop(params.value("player_count", 1));
    nlohmann::json p   = stateJson();
    p["configured"]    = true;
    p["multiplayer"]   = m_playerCount > 1 ? "local_coop" : "solo";
    return Result<nlohmann::json>::ok(std::move(p));
  }
  if (params.contains("active_player")) {
    const int req = params.value("active_player", m_activePlayer);
    if (req < 0 || req >= m_playerCount) return Result<nlohmann::json>::err("active_player out of range");
    if (m_players[static_cast<std::size_t>(req)].health.isDefeated())
      return Result<nlohmann::json>::err("active player defeated");
    m_activePlayer    = req;
    m_comboChain      = m_players[static_cast<std::size_t>(m_activePlayer)].comboChain;
    m_comboMultiplier = std::min(4.0F, 1.0F + static_cast<float>(m_comboChain) *
                                  (m_perks.speed ? 0.2F : 0.15F));
    return Result<nlohmann::json>::ok(stateJson());
  }
  if (params.contains("perk")) {
    if (m_phase != KarateWavePhase::kIntermission)
      return Result<nlohmann::json>::err("shrine perks available during intermission only");
    if (m_perkClaimedThisIntermission)
      return Result<nlohmann::json>::err("shrine perk already claimed this round");
    const std::string perk = params.value("perk", "");
    if      (perk == "speed") m_perks.speed = true;
    else if (perk == "power") m_perks.power = true;
    else if (perk == "guard") m_perks.guard = true;
    else return Result<nlohmann::json>::err("unknown perk — use speed, power, or guard");
    m_perkClaimedThisIntermission = true;
    nlohmann::json p = stateJson(); p["perk_applied"] = perk;
    return Result<nlohmann::json>::ok(std::move(p));
  }
  if (params.value("exfil", false)) {
    if (m_phase != KarateWavePhase::kIntermission)
      return Result<nlohmann::json>::err("exfil available during intermission only");
    if (m_waves.currentWave() < kTargetWave)
      return Result<nlohmann::json>::err("survive wave 10 before exfil");
    m_phase = KarateWavePhase::kVictory;
    nlohmann::json p = stateJson(); p["exfil"] = true;
    return Result<nlohmann::json>::ok(std::move(p));
  }
  return Result<nlohmann::json>::err("unsupported fel.karate.wave params");
}

// ─────────────────────────────────────────────────────────────────────────────
auto KarateEndlessMode::stateJson() const -> nlohmann::json {
  int aliveCount = 0;
  for (const EnemyAI& e : m_enemies) { if (e.state().alive) ++aliveCount; }

  nlohmann::json players = nlohmann::json::array();
  for (int i = 0; i < m_playerCount; ++i) {
    const auto& slot = m_players[static_cast<std::size_t>(i)];
    players.push_back({
        {"index", i}, {"hp", slot.health.hp()},
        {"combo_chain", slot.comboChain}, {"max_combo", slot.maxComboChain},
        {"active", i == m_activePlayer}, {"defeated", slot.health.isDefeated()},
    });
  }

  // Enemy 3D positions
  nlohmann::json enemies3D = nlohmann::json::array();
  for (std::size_t i = 0; i < m_enemies.size() && i < m_enemy3D.size(); ++i) {
    enemies3D.push_back({
        {"index",     static_cast<int>(i)},
        {"x",         m_enemy3D[i].position.x},
        {"y",         m_enemy3D[i].position.y},
        {"z",         m_enemy3D[i].position.z},
        {"yaw",       m_enemy3D[i].yawDegrees},
        {"anim_clip", m_enemy3D[i].animClip.name},
        {"alive",     m_enemies[i].state().alive},
        {"locked",    static_cast<int>(i) == m_lockedEnemyIndex},
    });
  }

  return {
      {"wave", m_waves.currentWave()},
      {"wave_state", wavePhaseLabel()},
      {"target_wave", kTargetWave},
      {"opponents_alive", aliveCount},
      {"opponents_defeated", m_opponentsDefeated},
      {"player_hp", activeSlot().health.hp()},
      {"player_count", m_playerCount},
      {"active_player", m_activePlayer},
      {"players", players},
      {"score", m_score},
      {"combo_chain", m_comboChain},
      {"max_combo", m_maxComboChain},
      {"critical_hits", m_criticalHits},
      {"combo_multiplier", m_comboMultiplier},
      {"chakra", m_chakra},
      {"chakra_max", kChakraMax},
      {"jutsu_ready", jutsuReady()},
      {"locked_enemy", m_lockedEnemyIndex},
      {"dash_ready", m_dashCooldownTimer <= 0.0F},
      {"regen_pause", m_waves.regenPauseActive()},
      {"session_over", isSessionOver()},
      {"victory", isVictory()},
      {"perks", {{"speed", m_perks.speed}, {"power", m_perks.power}, {"guard", m_perks.guard}}},
      {"perk_available", m_phase == KarateWavePhase::kIntermission && !m_perkClaimedThisIntermission},
      {"exfil_available", m_phase == KarateWavePhase::kIntermission && m_waves.currentWave() >= kTargetWave},
      // ── 3D world state ────────────────────────────────────────────────────
      {"player_3d", {
          {"x", m_player3D.position.x}, {"y", m_player3D.position.y}, {"z", m_player3D.position.z},
          {"yaw", m_player3D.yawDegrees},
          {"anim_clip", m_player3D.animClip.name},
          {"anim_loop", m_player3D.animClip.loop},
          {"anim_speed", m_player3D.animClip.speedScale},
      }},
      {"enemies_3d", enemies3D},
      {"arena_3d", {
          {"radius", kArenaRadius},
          {"width",  arenas::kDojo.width},
          {"depth",  arenas::kDojo.depth},
          {"ceiling",arenas::kDojo.ceilingHeight},
      }},
      // ── Naruto Storm camera ───────────────────────────────────────────────
      {"camera_3d", {
          {"pos_x",     m_camera.position.x},
          {"pos_y",     m_camera.position.y},
          {"pos_z",     m_camera.position.z},
          {"target_x",  m_camera.target.x},
          {"target_y",  m_camera.target.y},
          {"target_z",  m_camera.target.z},
          {"fov",       m_camera.fovDegrees},
          {"cinematic", m_camera.cinematic},
      }},
  };
}

} // namespace nexus::gameplay
