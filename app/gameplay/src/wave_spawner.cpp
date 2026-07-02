#include "nexus/gameplay/wave_spawner.h"

#include <algorithm>

namespace nexus::gameplay {

namespace {

constexpr float kRegenPauseSeconds = 2.0F;

} // namespace

auto WaveSpawner::configForWave(int waveNumber) -> WaveConfig {
  WaveConfig config{};
  config.waveNumber = std::max(1, waveNumber);

  if (waveNumber <= 3) {
    config.opponentCount = 1;
    config.speedScale = 0.85F;
    config.aggression = 0.7F;
    config.enemyHp = 60.0F;
  } else if (waveNumber <= 6) {
    config.opponentCount = 1;
    config.speedScale = 0.95F;
    config.aggression = 0.85F;
    config.enemyHp = 80.0F;
  } else if (waveNumber <= 9) {
    config.opponentCount = 2;
    config.speedScale = 1.0F;
    config.aggression = 1.0F;
    config.enemyHp = 80.0F;
  } else if (waveNumber <= 12) {
    config.opponentCount = 2;
    config.speedScale = 1.10F;
    config.aggression = 1.2F;
    config.enemyHp = 100.0F;
  } else {
    config.opponentCount = 3;
    config.speedScale = 1.15F;
    config.aggression = 1.4F;
    config.enemyHp = 120.0F;
  }

  return config;
}

void WaveSpawner::beginWave() {
  if (m_regenPauseSeconds > 0.0F) {
    return;
  }
  ++m_currentWave;
  const WaveConfig config = configForWave(m_currentWave);
  m_opponentsRemaining = config.opponentCount;
}

void WaveSpawner::onOpponentDefeated() {
  m_opponentsRemaining = std::max(0, m_opponentsRemaining - 1);
  if (m_opponentsRemaining == 0) {
    m_regenPauseSeconds = kRegenPauseSeconds;
  }
}

void WaveSpawner::update(double deltaSeconds) {
  if (m_regenPauseSeconds > 0.0F) {
    m_regenPauseSeconds = std::max(0.0F, m_regenPauseSeconds - static_cast<float>(deltaSeconds));
    if (m_regenPauseSeconds <= 0.0F && m_currentWave == 0) {
      beginWave();
    } else if (m_regenPauseSeconds <= 0.0F && m_opponentsRemaining == 0) {
      beginWave();
    }
  } else if (m_currentWave == 0) {
    beginWave();
  }
}

} // namespace nexus::gameplay
