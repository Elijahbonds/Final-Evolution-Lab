// Spec §3.2 / Appendix A — PRQ → arcade physics mapping
#pragma once

namespace nexus::gameplay {

struct ArcadePhysicsParams {
  float hangTimeMultiplier{1.0F};
  float explosiveFirstStep{0.3F};
  float comboDecayRateSeconds{5.0F};
  float maxComboMultiplier{2.0F};
  float criticalHitChance{0.05F};
  bool neuralBurstActive{false};
  float neuralBurstMultiplier{1.0F};

  // Story / traversal speed scaling.
  // movementSpeedScale: 1.0 = Sora (KH1) baseline, 2.8 = Sonic at PRQ 100.
  // Scales run/sprint speed and board-game token movement pace.
  float movementSpeedScale{1.0F};

  // flightSpeedScale: 1.0 = Sora glide, 2.0 = near-Sonic airboost at PRQ 100.
  float flightSpeedScale{1.0F};

  // grindAcceleration: rail entry snap speed; higher PRQ = faster lock-on grind.
  float grindAcceleration{1.0F};
};

class ArcadePhysics {
public:
  [[nodiscard]] static auto fromPRQ(float prq, float neuralDrive) -> ArcadePhysicsParams;
};

} // namespace nexus::gameplay
