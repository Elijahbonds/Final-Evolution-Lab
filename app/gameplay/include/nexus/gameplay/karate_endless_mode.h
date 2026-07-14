// Spec §2.2 P1 — Karate Endless / Dojo Breach wave survival (local co-op)
#pragma once

#include "nexus/core/result.h"
#include "nexus/gameplay/combat_system.h"
#include "nexus/gameplay/enemy_ai.h"
#include "nexus/gameplay/health_system.h"
#include "nexus/gameplay/wave_spawner.h"

#include <nlohmann/json.hpp>
#include <array>
#include <cstdint>
#include <string>
#include <vector>

// GCC 13.3 workaround: forward-declare enum classes before large STL includes.
namespace nexus { namespace gameplay {
  enum class KarateWavePhase : std::uint8_t;
} } // namespace nexus::gameplay

namespace nexus::gameplay {

enum class KarateWavePhase : std::uint8_t {
  kCombat = 0,
  kIntermission = 1,
  kVictory = 2,
  kDefeat = 3,
};

struct KaratePlayerSlot {
  HealthSystem health;
  int comboChain{0};
  int maxComboChain{0};
};

struct KaratePerkState {
  bool speed{false};
  bool power{false};
  bool guard{false};
};

class KarateEndlessMode {
public:
  static constexpr int kMaxPlayers = 4;
  static constexpr int kTargetWave = 10;

  void reset();
  void configureCoop(int playerCount);
  void update(double deltaSeconds);

  auto performAction(CombatAction action, int playerIndex = -1) -> Result<CombatOutcome>;
  auto handleWaveCommand(const nlohmann::json& params) -> Result<nlohmann::json>;

  [[nodiscard]] auto score() const -> int { return m_score; }
  [[nodiscard]] auto comboMultiplier() const -> float { return m_comboMultiplier; }
  [[nodiscard]] auto isSessionOver() const -> bool;
  [[nodiscard]] auto isVictory() const -> bool { return m_phase == KarateWavePhase::kVictory; }
  [[nodiscard]] auto wavePhase() const -> KarateWavePhase { return m_phase; }
  [[nodiscard]] auto stateJson() const -> nlohmann::json;

private:
  void spawnActiveEnemies();
  void onEnemyDefeated();
  void onWaveCleared();
  void advanceActivePlayer();
  [[nodiscard]] auto activeSlot() -> KaratePlayerSlot&;
  [[nodiscard]] auto activeSlot() const -> const KaratePlayerSlot&;
  [[nodiscard]] auto allPlayersDefeated() const -> bool;
  [[nodiscard]] auto wavePhaseLabel() const -> std::string_view;
  [[nodiscard]] auto scaledOpponentCount(int baseCount) const -> int;
  [[nodiscard]] auto damageMultiplier() const -> float;
  [[nodiscard]] auto damageTakenMultiplier() const -> float;

  std::array<KaratePlayerSlot, kMaxPlayers> m_players{};
  int m_playerCount{1};
  int m_activePlayer{0};
  WaveSpawner m_waves;
  std::vector<EnemyAI> m_enemies;
  KaratePerkState m_perks{};
  bool m_perkClaimedThisIntermission{false};
  KarateWavePhase m_phase{KarateWavePhase::kCombat};
  int m_comboChain{0};
  int m_maxComboChain{0};
  int m_criticalHits{0};
  float m_comboMultiplier{1.0F};
  int m_score{0};
  int m_opponentsDefeated{0};
};

} // namespace nexus::gameplay
