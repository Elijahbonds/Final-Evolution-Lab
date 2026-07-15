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

  // PRQ → movement speed: low PRQ feels like Sora (KH1 base), high PRQ feels
  // like Sonic. At PRQ 100 (norm=1.0) movementSpeedScale reaches 2.8×.
  // At the sprint stub value of PRQ 75 (norm=0.75) scale ≈ 2.25× — visibly fast
  // but not yet Sonic; true Sonic tier requires PRQ ≥ 90.
  params.movementSpeedScale = 0.6F + norm * 2.2F;

  // Flight speed mirrors KH1 glide at low PRQ and approaches airboost at high PRQ.
  params.flightSpeedScale = 0.8F + norm * 1.2F;

  // Rail grind acceleration: how quickly the player locks on and accelerates
  // along a rail. Higher PRQ means snappier entry and faster slide.
  params.grindAcceleration = 0.6F + norm * 1.4F;

  return params;
}

} // namespace nexus::gameplay
