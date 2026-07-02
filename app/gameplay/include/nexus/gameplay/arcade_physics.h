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
};

class ArcadePhysics {
public:
  [[nodiscard]] static auto fromPRQ(float prq, float neuralDrive) -> ArcadePhysicsParams;
};

} // namespace nexus::gameplay
