#include "nexus/gameplay/health_system.h"

#include <algorithm>

namespace nexus::gameplay {

void HealthSystem::reset() {
  m_hp = kMaxHp;
}

void HealthSystem::applyDamage(float amount) {
  m_hp = std::max(0.0F, m_hp - std::max(0.0F, amount));
}

void HealthSystem::regenerate(double deltaSeconds, float ratePerSecond) {
  m_hp = std::min(kMaxHp, m_hp + static_cast<float>(deltaSeconds) * std::max(0.0F, ratePerSecond));
}

} // namespace nexus::gameplay
