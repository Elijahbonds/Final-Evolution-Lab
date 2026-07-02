#include "nexus/gameplay/karate_endless_mode.h"

#include <algorithm>
#include <string>

namespace nexus::gameplay {

namespace {

constexpr float kRegenRateMin = 0.5F;
constexpr float kRegenRateMax = 2.0F;
constexpr int kSpecialMoveComboThreshold = 8;

} // namespace

void KarateEndlessMode::reset() {
  m_playerCount = 1;
  m_activePlayer = 0;
  for (KaratePlayerSlot& slot : m_players) {
    slot = KaratePlayerSlot{};
    slot.health.reset();
  }
  m_waves = WaveSpawner{};
  m_enemies.clear();
  m_perks = {};
  m_perkClaimedThisIntermission = false;
  m_phase = KarateWavePhase::kCombat;
  m_comboChain = 0;
  m_maxComboChain = 0;
  m_criticalHits = 0;
  m_comboMultiplier = 1.0F;
  m_score = 0;
  m_opponentsDefeated = 0;
}

void KarateEndlessMode::configureCoop(int playerCount) {
  m_playerCount = std::clamp(playerCount, 1, kMaxPlayers);
  m_activePlayer = 0;
  for (int index = 0; index < kMaxPlayers; ++index) {
    m_players[static_cast<std::size_t>(index)] = KaratePlayerSlot{};
    if (index < m_playerCount) {
      m_players[static_cast<std::size_t>(index)].health.reset();
    }
  }
  m_waves = WaveSpawner{};
  m_enemies.clear();
  m_perks = {};
  m_perkClaimedThisIntermission = false;
  m_phase = KarateWavePhase::kCombat;
  m_comboChain = 0;
  m_maxComboChain = 0;
  m_criticalHits = 0;
  m_comboMultiplier = 1.0F;
  m_score = 0;
  m_opponentsDefeated = 0;
}

auto KarateEndlessMode::activeSlot() -> KaratePlayerSlot& {
  return m_players[static_cast<std::size_t>(m_activePlayer)];
}

auto KarateEndlessMode::activeSlot() const -> const KaratePlayerSlot& {
  return m_players[static_cast<std::size_t>(m_activePlayer)];
}

auto KarateEndlessMode::allPlayersDefeated() const -> bool {
  for (int index = 0; index < m_playerCount; ++index) {
    if (!m_players[static_cast<std::size_t>(index)].health.isDefeated()) {
      return false;
    }
  }
  return true;
}

auto KarateEndlessMode::isSessionOver() const -> bool {
  return m_phase == KarateWavePhase::kVictory || m_phase == KarateWavePhase::kDefeat;
}

auto KarateEndlessMode::wavePhaseLabel() const -> std::string_view {
  switch (m_phase) {
  case KarateWavePhase::kCombat:
    return "combat";
  case KarateWavePhase::kIntermission:
    return "intermission";
  case KarateWavePhase::kVictory:
    return "victory";
  case KarateWavePhase::kDefeat:
    return "defeat";
  }
  return "combat";
}

auto KarateEndlessMode::scaledOpponentCount(int baseCount) const -> int {
  return std::max(1, baseCount + (m_playerCount - 1));
}

auto KarateEndlessMode::damageMultiplier() const -> float {
  float multiplier = 1.0F;
  if (m_perks.power) {
    multiplier *= 1.35F;
  }
  if (m_comboChain >= kSpecialMoveComboThreshold) {
    multiplier *= 1.5F;
  }
  return multiplier;
}

auto KarateEndlessMode::damageTakenMultiplier() const -> float {
  float multiplier = 0.85F + static_cast<float>(m_playerCount) * 0.08F;
  if (m_perks.guard) {
    multiplier *= 0.65F;
  }
  return multiplier;
}

void KarateEndlessMode::advanceActivePlayer() {
  for (int offset = 1; offset <= m_playerCount; ++offset) {
    const int candidate = (m_activePlayer + offset) % m_playerCount;
    if (!m_players[static_cast<std::size_t>(candidate)].health.isDefeated()) {
      m_activePlayer = candidate;
      m_comboChain = m_players[static_cast<std::size_t>(m_activePlayer)].comboChain;
      m_comboMultiplier = std::min(
          4.0F, 1.0F + static_cast<float>(m_comboChain) * (m_perks.speed ? 0.2F : 0.15F));
      return;
    }
  }
}

void KarateEndlessMode::update(double deltaSeconds) {
  if (isSessionOver()) {
    return;
  }

  if (allPlayersDefeated()) {
    m_phase = KarateWavePhase::kDefeat;
    return;
  }

  if (activeSlot().health.isDefeated()) {
    advanceActivePlayer();
  }

  m_waves.update(deltaSeconds);
  m_phase = m_waves.regenPauseActive() ? KarateWavePhase::kIntermission : KarateWavePhase::kCombat;

  if (m_waves.regenPauseActive()) {
    const float regenRate = kRegenRateMin + (kRegenRateMax - kRegenRateMin) * 0.5F;
    for (int index = 0; index < m_playerCount; ++index) {
      m_players[static_cast<std::size_t>(index)].health.regenerate(deltaSeconds, regenRate);
    }
  } else {
    m_perkClaimedThisIntermission = false;
    m_perks = {};
  }

  const int expectedEnemies = scaledOpponentCount(m_waves.opponentsRemaining());
  if (static_cast<int>(m_enemies.size()) != expectedEnemies) {
    spawnActiveEnemies();
  }

  for (EnemyAI& enemy : m_enemies) {
    enemy.update(deltaSeconds);
    if (enemy.state().attacking && enemy.state().alive && !activeSlot().health.isDefeated()) {
      activeSlot().health.applyDamage(4.0F * enemy.state().aggression * damageTakenMultiplier());
      if (activeSlot().health.isDefeated()) {
        advanceActivePlayer();
        if (allPlayersDefeated()) {
          m_phase = KarateWavePhase::kDefeat;
          return;
        }
      }
    }
  }
}

auto KarateEndlessMode::performAction(CombatAction action, int playerIndex) -> Result<CombatOutcome> {
  if (isSessionOver()) {
    return Result<CombatOutcome>::err("session ended");
  }
  if (m_phase == KarateWavePhase::kIntermission) {
    return Result<CombatOutcome>::err("dojo intermission — claim a shrine perk or exfil");
  }

  const int resolvedPlayer = playerIndex >= 0 ? playerIndex : m_activePlayer;
  if (resolvedPlayer < 0 || resolvedPlayer >= m_playerCount) {
    return Result<CombatOutcome>::err("invalid player_index");
  }
  if (m_players[static_cast<std::size_t>(resolvedPlayer)].health.isDefeated()) {
    return Result<CombatOutcome>::err("player defeated");
  }

  m_activePlayer = resolvedPlayer;
  KaratePlayerSlot& slot = activeSlot();

  bool opponentAttacking = false;
  float attackTimer = 0.0F;
  for (const EnemyAI& enemy : m_enemies) {
    if (enemy.state().alive && enemy.state().attacking) {
      opponentAttacking = true;
      attackTimer = enemy.state().attackTimer;
      break;
    }
  }

  CombatOutcome outcome = CombatSystem::resolve(action, opponentAttacking, attackTimer);
  outcome.damageDealt *= damageMultiplier();

  if (action == CombatAction::kBlock && outcome.blocked) {
    return Result<CombatOutcome>::ok(outcome);
  }

  if (action == CombatAction::kDodge) {
    return Result<CombatOutcome>::ok(outcome);
  }

  if (outcome.damageDealt > 0.0F) {
    for (EnemyAI& enemy : m_enemies) {
      if (enemy.state().alive) {
        enemy.applyDamage(outcome.damageDealt);
        if (!enemy.state().alive) {
          onEnemyDefeated();
        }
        break;
      }
    }
    ++m_comboChain;
    slot.comboChain = m_comboChain;
    slot.maxComboChain = std::max(slot.maxComboChain, m_comboChain);
    m_maxComboChain = std::max(m_maxComboChain, m_comboChain);
    if (outcome.countered) {
      ++m_criticalHits;
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

auto KarateEndlessMode::handleWaveCommand(const nlohmann::json& params) -> Result<nlohmann::json> {
  if (!params.is_object()) {
    return Result<nlohmann::json>::err("wave params must be object");
  }

  if (params.contains("player_count")) {
    const int playerCount = params.value("player_count", 1);
    configureCoop(playerCount);
    nlohmann::json payload = stateJson();
    payload["configured"] = true;
    return Result<nlohmann::json>::ok(std::move(payload));
  }

  if (params.contains("active_player")) {
    const int requested = params.value("active_player", m_activePlayer);
    if (requested < 0 || requested >= m_playerCount) {
      return Result<nlohmann::json>::err("active_player out of range");
    }
    if (m_players[static_cast<std::size_t>(requested)].health.isDefeated()) {
      return Result<nlohmann::json>::err("active player defeated");
    }
    m_activePlayer = requested;
    m_comboChain = m_players[static_cast<std::size_t>(m_activePlayer)].comboChain;
    const float comboScale = m_perks.speed ? 0.2F : 0.15F;
    m_comboMultiplier =
        std::min(4.0F, 1.0F + static_cast<float>(m_comboChain) * comboScale);
    return Result<nlohmann::json>::ok(stateJson());
  }

  if (params.contains("perk")) {
    if (m_phase != KarateWavePhase::kIntermission) {
      return Result<nlohmann::json>::err("shrine perks available during intermission only");
    }
    if (m_perkClaimedThisIntermission) {
      return Result<nlohmann::json>::err("shrine perk already claimed this round");
    }
    const std::string perk = params.value("perk", "");
    if (perk == "speed") {
      m_perks.speed = true;
    } else if (perk == "power") {
      m_perks.power = true;
    } else if (perk == "guard") {
      m_perks.guard = true;
    } else {
      return Result<nlohmann::json>::err("unknown perk — use speed, power, or guard");
    }
    m_perkClaimedThisIntermission = true;
    nlohmann::json payload = stateJson();
    payload["perk_applied"] = perk;
    return Result<nlohmann::json>::ok(std::move(payload));
  }

  if (params.value("exfil", false)) {
    if (m_phase != KarateWavePhase::kIntermission) {
      return Result<nlohmann::json>::err("exfil available during intermission only");
    }
    if (m_waves.currentWave() < kTargetWave) {
      return Result<nlohmann::json>::err("survive wave 10 before exfil");
    }
    m_phase = KarateWavePhase::kVictory;
    nlohmann::json payload = stateJson();
    payload["exfil"] = true;
    return Result<nlohmann::json>::ok(std::move(payload));
  }

  return Result<nlohmann::json>::err("unsupported fel.karate.wave params");
}

void KarateEndlessMode::spawnActiveEnemies() {
  const WaveConfig config = WaveSpawner::configForWave(std::max(1, m_waves.currentWave()));
  const int enemyCount = scaledOpponentCount(m_waves.opponentsRemaining());
  m_enemies.clear();
  m_enemies.resize(static_cast<std::size_t>(enemyCount));
  for (EnemyAI& enemy : m_enemies) {
    enemy.configure(config.enemyHp, config.speedScale, config.aggression);
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

auto KarateEndlessMode::stateJson() const -> nlohmann::json {
  int aliveCount = 0;
  for (const EnemyAI& enemy : m_enemies) {
    if (enemy.state().alive) {
      ++aliveCount;
    }
  }

  nlohmann::json players = nlohmann::json::array();
  for (int index = 0; index < m_playerCount; ++index) {
    const KaratePlayerSlot& slot = m_players[static_cast<std::size_t>(index)];
    players.push_back({
        {"index", index},
        {"hp", slot.health.hp()},
        {"combo_chain", slot.comboChain},
        {"max_combo", slot.maxComboChain},
        {"active", index == m_activePlayer},
        {"defeated", slot.health.isDefeated()},
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
      {"multiplayer", "local_coop"},
      {"score", m_score},
      {"combo_chain", m_comboChain},
      {"max_combo", m_maxComboChain},
      {"critical_hits", m_criticalHits},
      {"combo_multiplier", m_comboMultiplier},
      {"regen_pause", m_waves.regenPauseActive()},
      {"session_over", isSessionOver()},
      {"victory", isVictory()},
      {"perks",
       {
           {"speed", m_perks.speed},
           {"power", m_perks.power},
           {"guard", m_perks.guard},
       }},
      {"perk_available", m_phase == KarateWavePhase::kIntermission && !m_perkClaimedThisIntermission},
      {"exfil_available",
       m_phase == KarateWavePhase::kIntermission && m_waves.currentWave() >= kTargetWave},
  };
}

} // namespace nexus::gameplay
