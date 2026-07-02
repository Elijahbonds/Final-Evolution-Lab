#include "nexus/gameplay/skateboarding_mode.h"

#include "nexus/gameplay/arena_mode_registry.h"

#include <algorithm>

namespace nexus::gameplay {

namespace {

[[nodiscard]] auto skateboardingReleaseState() -> int {
  return static_cast<int>(ArenaModeRegistry::releaseStateForMode("skateboarding"));
}

} // namespace

void SkateboardingMode::reset() {
  m_phase = SkatePhase::kRun;
  m_trickScore = 0.0F;
  m_comboMultiplier = 1;
  m_tricksLanded = 0;
  m_tricksBailed = 0;
  m_peakCombo = 1;
}

void SkateboardingMode::update(double /*deltaSeconds*/) {
  if (m_phase == SkatePhase::kRunComplete) {
    return;
  }
}

auto SkateboardingMode::landTrick(float difficulty, int32_t comboMultiplier)
    -> Result<nlohmann::json> {
  if (m_phase == SkatePhase::kRunComplete) {
    return Result<nlohmann::json>::err("skate run already complete");
  }

  const float diff = std::clamp(difficulty, 0.1F, 1.0F);
  const int32_t combo = std::clamp(comboMultiplier, 1, 8);
  m_comboMultiplier = combo;
  m_peakCombo = std::max(m_peakCombo, combo);

  const float points = (8.0F + diff * 12.0F) * static_cast<float>(combo);
  m_trickScore += points;
  ++m_tricksLanded;

  if (static_cast<int32_t>(m_trickScore) >= kWinScore) {
    m_phase = SkatePhase::kRunComplete;
  }

  nlohmann::json payload = stateJson();
  payload["trick"] = {
      {"difficulty", diff},
      {"combo_multiplier", combo},
      {"points", points},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto SkateboardingMode::bail() -> Result<nlohmann::json> {
  if (m_phase == SkatePhase::kRunComplete) {
    return Result<nlohmann::json>::err("skate run already complete");
  }

  ++m_tricksBailed;
  m_comboMultiplier = 1;

  if (m_tricksBailed >= kMaxBails && static_cast<int32_t>(m_trickScore) < kWinScore) {
    m_phase = SkatePhase::kRunComplete;
  }

  nlohmann::json payload = stateJson();
  payload["bail"] = {{"bails", m_tricksBailed}, {"combo_reset", true}};
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto SkateboardingMode::stateJson() const -> nlohmann::json {
  return {
      {"phase", static_cast<int>(m_phase)},
      {"trick_score", static_cast<int32_t>(m_trickScore)},
      {"win_target", kWinScore},
      {"combo_multiplier", m_comboMultiplier},
      {"peak_combo", m_peakCombo},
      {"tricks_landed", m_tricksLanded},
      {"tricks_bailed", m_tricksBailed},
      {"max_bails", kMaxBails},
      {"run_complete", isRunComplete()},
      {"release_state", skateboardingReleaseState()},
  };
}

} // namespace nexus::gameplay
