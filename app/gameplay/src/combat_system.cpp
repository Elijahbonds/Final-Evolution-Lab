#include "nexus/gameplay/combat_system.h"

namespace nexus::gameplay {

namespace {

constexpr float kLightDamage = 8.0F;
constexpr float kHeavyDamage = 18.0F;
constexpr float kCounterDamage = 25.0F;
constexpr float kCounterWindowSec = 0.15F;

} // namespace

auto CombatSystem::resolve(CombatAction action,
                           bool opponentAttacking,
                           float opponentAttackTimer) -> CombatOutcome {
  CombatOutcome outcome{};
  outcome.action = action;

  switch (action) {
  case CombatAction::kLightStrike:
    outcome.damageDealt = kLightDamage;
    outcome.staminaCost = 5.0F;
    break;
  case CombatAction::kHeavyStrike:
    outcome.damageDealt = kHeavyDamage;
    outcome.staminaCost = 15.0F;
    break;
  case CombatAction::kBlock:
    outcome.staminaCost = 3.0F;
    outcome.blocked = opponentAttacking;
    outcome.damageDealt = 0.0F;
    break;
  case CombatAction::kDodge:
    outcome.staminaCost = 10.0F;
    outcome.damageDealt = 0.0F;
    break;
  case CombatAction::kCounter:
    outcome.staminaCost = 8.0F;
    if (opponentAttacking && opponentAttackTimer <= kCounterWindowSec) {
      outcome.countered = true;
      outcome.damageDealt = kCounterDamage;
    }
    break;
  }

  return outcome;
}

auto CombatSystem::actionLabel(CombatAction action) -> std::string_view {
  switch (action) {
  case CombatAction::kLightStrike:
    return "light_strike";
  case CombatAction::kHeavyStrike:
    return "heavy_strike";
  case CombatAction::kBlock:
    return "block";
  case CombatAction::kDodge:
    return "dodge";
  case CombatAction::kCounter:
    return "counter";
  }
  return "unknown";
}

} // namespace nexus::gameplay
