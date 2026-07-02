#include "nexus/gameplay/arcade_physics.h"

#include <algorithm>

namespace nexus::gameplay {

auto ArcadePhysics::fromPRQ(float prq, float neuralDrive) -> ArcadePhysicsParams {
  const float norm = std::clamp(prq / 100.0F, 0.0F, 1.0F);
  const float neural = std::clamp(neuralDrive / 100.0F, 0.0F, 1.0F);

  ArcadePhysicsParams params{};
  params.hangTimeMultiplier = 1.0F + norm * 1.8F + neural * 0.4F;
  params.explosiveFirstStep = 0.3F + norm * 0.7F;
  params.comboDecayRateSeconds = 5.0F - norm * 3.0F;
  params.maxComboMultiplier = 2.0F + norm * 3.0F;
  params.criticalHitChance = 0.05F + norm * 0.2F + neural * 0.1F;
  params.neuralBurstActive = neuralDrive >= 80.0F;
  params.neuralBurstMultiplier = params.neuralBurstActive ? 1.15F : 1.0F;
  return params;
}

} // namespace nexus::gameplay
