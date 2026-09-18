// Spec §2.2 P1 — strike / block / dodge / counter
#pragma once

#include "nexus/core/result.h"

#include <cstdint>
#include <string_view>

namespace nexus::gameplay {

enum class CombatAction : std::uint8_t {
  kLightStrike = 0,
  kHeavyStrike = 1,
  kBlock = 2,
  kDodge = 3,
  kCounter = 4,
};

struct CombatOutcome {
  CombatAction action{CombatAction::kLightStrike};
  float damageDealt{0.0F};
  float staminaCost{0.0F};
  bool blocked{false};
  bool countered{false};
};

class CombatSystem {
public:
  [[nodiscard]] static auto resolve(CombatAction action,
                                    bool opponentAttacking,
                                    float opponentAttackTimer) -> CombatOutcome;
  [[nodiscard]] static auto actionLabel(CombatAction action) -> std::string_view;
};

} // namespace nexus::gameplay
