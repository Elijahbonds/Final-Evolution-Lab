#include "nexus/gameplay/skateboarding_mode.h"

#include <algorithm>

namespace nexus::gameplay {

void SkateboardingMode::reset() {
  m_phase = SkatePhase::kRun;
  m_trickScore = 0.0F;
  m_comboMultiplier = 1;
  m_tricksLanded = 0;
  m_tricksBailed = 0;
  m_peakCombo = 1;
  m_lastTrickName.clear();
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

auto SkateboardingMode::trickDifficulty(std::string_view trickName) -> float {
  // Canonical trick difficulty values (0.0–1.0).
  if (trickName == "manual") {
    return 0.40F;
  }
  if (trickName == "50-50" || trickName == "5050") {
    return 0.45F;
  }
  if (trickName == "kickflip") {
    return 0.55F;
  }
  if (trickName == "heelflip") {
    return 0.55F;
  }
  if (trickName == "nollie") {
    return 0.60F;
  }
  if (trickName == "noseslide") {
    return 0.65F;
  }
  if (trickName == "360flip" || trickName == "tre_flip") {
    return 0.80F;
  }
  if (trickName == "hardflip") {
    return 0.82F;
  }
  if (trickName == "treflip") {
    return 0.85F;
  }
  if (trickName == "360flip_nosegrind") {
    return 0.92F;
  }
  // Unknown trick — use a moderate default.
  return 0.50F;
}

auto SkateboardingMode::timingBonus(float timingNormalized) -> float {
  if (timingNormalized >= 0.92F) {
    return 1.25F;
  }
  if (timingNormalized >= 0.65F) {
    return 1.05F;
  }
  return 0.80F;
}

auto SkateboardingMode::onNamedTrick(std::string_view trickName, float timingNormalized)
    -> Result<nlohmann::json> {
  if (m_phase == SkatePhase::kRunComplete) {
    return Result<nlohmann::json>::err("skate run already complete");
  }

  const float timing = std::clamp(timingNormalized, 0.0F, 1.0F);
  const float diff = trickDifficulty(trickName);
  m_lastTrickName = std::string(trickName);

  const float points = (8.0F + diff * 12.0F) * static_cast<float>(m_comboMultiplier) *
                       timingBonus(timing);
  m_trickScore += points;
  ++m_tricksLanded;

  if (static_cast<int32_t>(m_trickScore) >= kWinScore) {
    m_phase = SkatePhase::kRunComplete;
  }

  const std::string grade = timing >= 0.92F ? "perfect" : timing >= 0.65F ? "good" : "miss";
  nlohmann::json payload = stateJson();
  payload["named_trick"] = {
      {"name", m_lastTrickName},
      {"difficulty", diff},
      {"timing", timing},
      {"timing_grade", grade},
      {"combo_multiplier", m_comboMultiplier},
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
      {"last_trick", m_lastTrickName},
      {"run_complete", isRunComplete()},
      {"release_state", "validate_only"},
  };
}

} // namespace nexus::gameplay
