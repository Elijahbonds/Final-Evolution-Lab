#include "nexus/gameplay/combat_system.h"
#include "nexus/gameplay/health_system.h"
#include "nexus/gameplay/qte_system.h"

#include <cstdio>
#include <cstdlib>
#include <string_view>

namespace {

void require(bool condition, const char* message) {
  if (!condition) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    std::exit(1);
  }
}

void combat_actions_resolve_expected_damage_and_labels() {
  using nexus::gameplay::CombatAction;
  using nexus::gameplay::CombatSystem;

  const auto light = CombatSystem::resolve(CombatAction::kLightStrike, false, 0.0F);
  require(light.damageDealt == 8.0F, "light strike damage");
  require(light.staminaCost == 5.0F, "light strike stamina cost");
  require(CombatSystem::actionLabel(light.action) == std::string_view{"light_strike"},
          "light strike label");

  const auto heavy = CombatSystem::resolve(CombatAction::kHeavyStrike, false, 0.0F);
  require(heavy.damageDealt == 18.0F, "heavy strike damage");
  require(heavy.staminaCost == 15.0F, "heavy strike stamina cost");
  require(CombatSystem::actionLabel(heavy.action) == std::string_view{"heavy_strike"},
          "heavy strike label");

  const auto block = CombatSystem::resolve(CombatAction::kBlock, true, 0.3F);
  require(block.blocked, "block flags active opponent attack");
  require(block.damageDealt == 0.0F, "block deals no damage");
  require(CombatSystem::actionLabel(block.action) == std::string_view{"block"}, "block label");
}

void counter_requires_active_attack_inside_window() {
  using nexus::gameplay::CombatAction;
  using nexus::gameplay::CombatSystem;

  const auto counter = CombatSystem::resolve(CombatAction::kCounter, true, 0.15F);
  require(counter.countered, "counter succeeds at window edge");
  require(counter.damageDealt == 25.0F, "counter damage");
  require(counter.staminaCost == 8.0F, "counter stamina cost");

  const auto late = CombatSystem::resolve(CombatAction::kCounter, true, 0.151F);
  require(!late.countered, "late counter fails");
  require(late.damageDealt == 0.0F, "late counter deals no damage");

  const auto idle = CombatSystem::resolve(CombatAction::kCounter, false, 0.0F);
  require(!idle.countered, "counter needs opponent attack");
}

void health_clamps_damage_regen_and_reset() {
  nexus::gameplay::HealthSystem health;
  require(health.hp() == nexus::gameplay::HealthSystem::kMaxHp, "health starts full");
  require(!health.isDefeated(), "full health not defeated");

  health.applyDamage(35.0F);
  require(health.hp() == 65.0F, "damage reduces health");
  health.applyDamage(-10.0F);
  require(health.hp() == 65.0F, "negative damage ignored");

  health.regenerate(2.0, 7.5F);
  require(health.hp() == 80.0F, "regen applies rate over delta");
  health.regenerate(10.0, 50.0F);
  require(health.hp() == nexus::gameplay::HealthSystem::kMaxHp, "regen clamps at max");

  health.applyDamage(250.0F);
  require(health.hp() == 0.0F, "damage clamps at zero");
  require(health.isDefeated(), "zero health defeated");
  health.reset();
  require(health.hp() == nexus::gameplay::HealthSystem::kMaxHp, "reset restores max hp");
}

void qte_grades_taps_and_consumes_window() {
  nexus::gameplay::QTESystem qte;
  qte.startApexWindow(1.0F);
  require(qte.isActive(), "qte starts active");
  qte.update(0.5);
  require(qte.onTap() == nexus::gameplay::QTEGrade::kPerfect, "center tap is perfect");
  require(!qte.isActive(), "tap consumes qte window");
  require(qte.onTap() == nexus::gameplay::QTEGrade::kMiss, "second tap misses");

  qte.startApexWindow(1.0F);
  qte.update(0.25);
  require(qte.onTap() == nexus::gameplay::QTEGrade::kGood, "near-center tap is good");

  qte.startApexWindow(1.0F);
  qte.update(0.96);
  require(qte.onTap() == nexus::gameplay::QTEGrade::kMiss, "edge tap misses");

  qte.startApexWindow(1.0F);
  qte.update(1.0);
  require(!qte.isActive(), "window expires after elapsed duration");
  require(qte.onTap() == nexus::gameplay::QTEGrade::kMiss, "expired window misses");
}

void qte_labels_and_bonuses_match_scoring_contract() {
  using nexus::gameplay::QTEGrade;
  using nexus::gameplay::QTESystem;

  require(QTESystem::gradeLabel(QTEGrade::kPerfect) == std::string_view{"PERFECT"},
          "perfect label");
  require(QTESystem::gradeLabel(QTEGrade::kGreat) == std::string_view{"GREAT"}, "great label");
  require(QTESystem::gradeLabel(QTEGrade::kGood) == std::string_view{"GOOD"}, "good label");
  require(QTESystem::gradeLabel(QTEGrade::kOk) == std::string_view{"OK"}, "ok label");
  require(QTESystem::gradeLabel(QTEGrade::kMiss) == std::string_view{"MISS"}, "miss label");

  require(QTESystem::timingBonus(QTEGrade::kPerfect) == 3.0F, "perfect bonus");
  require(QTESystem::timingBonus(QTEGrade::kGreat) == 2.0F, "great bonus");
  require(QTESystem::timingBonus(QTEGrade::kGood) == 1.0F, "good bonus");
  require(QTESystem::timingBonus(QTEGrade::kOk) == 0.5F, "ok bonus");
  require(QTESystem::timingBonus(QTEGrade::kMiss) == 0.0F, "miss bonus");
}

} // namespace

auto main() -> int {
  combat_actions_resolve_expected_damage_and_labels();
  counter_requires_active_attack_inside_window();
  health_clamps_damage_regen_and_reset();
  qte_grades_taps_and_consumes_window();
  qte_labels_and_bonuses_match_scoring_contract();
  std::fprintf(stdout, "PASS: combat_health_qte_test\n");
  return 0;
}
