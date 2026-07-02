// Spec §2.2 P1 — HP + inter-wave regen
#pragma once

namespace nexus::gameplay {

class HealthSystem {
public:
  static constexpr float kMaxHp = 100.0F;

  void reset();
  void applyDamage(float amount);
  void regenerate(double deltaSeconds, float ratePerSecond);
  [[nodiscard]] auto hp() const -> float { return m_hp; }
  [[nodiscard]] auto isDefeated() const -> bool { return m_hp <= 0.0F; }

private:
  float m_hp{kMaxHp};
};

} // namespace nexus::gameplay
