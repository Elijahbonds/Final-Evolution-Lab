// Spec §2.2 P1 — endless wave scaling table
#pragma once

#include <cstdint>

namespace nexus::gameplay {

struct WaveConfig {
  int waveNumber{1};
  int opponentCount{1};
  float speedScale{0.85F};
  float aggression{0.7F};
  float enemyHp{60.0F};
};

class WaveSpawner {
public:
  [[nodiscard]] static auto configForWave(int waveNumber) -> WaveConfig;
  [[nodiscard]] auto currentWave() const -> int { return m_currentWave; }
  [[nodiscard]] auto opponentsRemaining() const -> int { return m_opponentsRemaining; }
  [[nodiscard]] auto regenPauseActive() const -> bool { return m_regenPauseSeconds > 0.0F; }

  void beginWave();
  void onOpponentDefeated();
  void update(double deltaSeconds);

private:
  int m_currentWave{0};
  int m_opponentsRemaining{0};
  float m_regenPauseSeconds{0.0F};
};

} // namespace nexus::gameplay
