#include "nexus/gameplay/enemy_ai.h"

#include <algorithm>

namespace nexus::gameplay {

void EnemyAI::configure(float maxHp, float speedScale, float aggression) {
  m_state.maxHp = maxHp;
  m_state.hp = maxHp;
  m_state.speedScale = speedScale;
  m_state.aggression = aggression;
  m_state.alive = true;
  m_state.attacking = false;
  m_state.attackTimer = 0.0F;
}

void EnemyAI::update(double deltaSeconds) {
  if (!m_state.alive) {
    return;
  }

  m_state.attackTimer = std::max(0.0F, m_state.attackTimer - static_cast<float>(deltaSeconds));
  m_state.attackCooldown = std::max(0.0F, m_state.attackCooldown - static_cast<float>(deltaSeconds));

  const float attackInterval = std::max(0.8F, 2.2F - m_state.aggression);
  if (m_state.attackCooldown <= 0.0F && !m_state.attacking) {
    m_state.attacking = true;
    m_state.attackTimer = 0.35F;
    m_state.attackCooldown = attackInterval / std::max(0.5F, m_state.speedScale);
  }

  if (m_state.attacking && m_state.attackTimer <= 0.0F) {
    m_state.attacking = false;
  }
}

void EnemyAI::applyDamage(float amount) {
  m_state.hp = std::max(0.0F, m_state.hp - amount);
  if (m_state.hp <= 0.0F) {
    m_state.alive = false;
    m_state.attacking = false;
  }
}

} // namespace nexus::gameplay
