// Spec §2.2 P1 — basic opponent behavior
#pragma once

namespace nexus::gameplay {

struct EnemyState {
  float hp{60.0F};
  float maxHp{60.0F};
  float speedScale{1.0F};
  float aggression{0.7F};
  float attackTimer{0.0F};
  float attackCooldown{0.0F};
  bool attacking{false};
  bool alive{true};
};

class EnemyAI {
public:
  void configure(float maxHp, float speedScale, float aggression);
  void update(double deltaSeconds);
  void applyDamage(float amount);
  [[nodiscard]] auto state() const -> const EnemyState& { return m_state; }

private:
  EnemyState m_state{};
};

} // namespace nexus::gameplay
