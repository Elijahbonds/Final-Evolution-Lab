#include "nexus/gameplay/skateboarding_mode.h"

#include <algorithm>

namespace nexus::gameplay {

void SkateboardingMode::reset() {
  m_phase            = SkatePhase::kRun;
  m_trickScore       = 0.0F;
  m_runTimer         = 0.0F;
  m_comboMultiplier  = 1;
  m_tricksLanded     = 0;
  m_tricksBailed     = 0;
  m_peakCombo        = 1;
  m_specialsUnlocked = false;
  m_manualActive     = false;
  m_manualTimer      = 0.0F;
  m_lastTrickName.clear();
}

void SkateboardingMode::update(double deltaSeconds) {
  if (m_phase == SkatePhase::kRunComplete) {
    return;
  }

  // Advance manual balance timer; forcibly end manual if it times out.
  if (m_manualActive) {
    m_manualTimer += static_cast<float>(deltaSeconds);
    if (m_manualTimer >= kManualMaxDuration) {
      m_manualActive    = false;
      m_comboMultiplier = 1;
      m_manualTimer     = 0.0F;
    }
  }

  // Advance the run timer; run ends at 2 minutes regardless of score.
  m_runTimer += static_cast<float>(deltaSeconds);
  if (m_runTimer >= kRunDurationSeconds) {
    m_phase = SkatePhase::kRunComplete;
  }
}

// ── Private helpers ──────────────────────────────────────────────────────────

auto SkateboardingMode::trickDifficulty(std::string_view trickName) -> float {
  // Base tricks.
  if (trickName == "manual")                           return 0.40F;
  if (trickName == "50-50" || trickName == "5050")     return 0.45F;
  if (trickName == "kickflip")                         return 0.55F;
  if (trickName == "heelflip")                         return 0.55F;
  if (trickName == "nollie")                           return 0.60F;
  if (trickName == "noseslide")                        return 0.65F;
  if (trickName == "360flip" || trickName == "tre_flip") return 0.80F;
  if (trickName == "hardflip")                         return 0.82F;
  if (trickName == "treflip")                          return 0.85F;
  if (trickName == "360flip_nosegrind")                return 0.92F;
  // Special tricks (unlocked at kSpecialsUnlockThreshold).
  if (trickName == "900")                              return 0.95F;
  if (trickName == "mcttwist")                         return 0.97F;
  if (trickName == "christ_air")                       return 1.00F;
  return 0.50F;  // default
}

auto SkateboardingMode::timingBonus(float timingNormalized) -> float {
  if (timingNormalized >= 0.92F) return 1.25F;
  if (timingNormalized >= 0.65F) return 1.05F;
  return 0.80F;
}

void SkateboardingMode::checkRunEnd() {
  // Legacy threshold still ends the run early when reached (preserves existing test behaviour).
  if (static_cast<int32_t>(m_trickScore) >= kWinScore || m_tricksBailed >= kMaxBails) {
    m_phase = SkatePhase::kRunComplete;
  }
}

// ── Public API ───────────────────────────────────────────────────────────────

auto SkateboardingMode::landTrick(float difficulty, int32_t comboMultiplier)
    -> Result<nlohmann::json> {
  if (m_phase == SkatePhase::kRunComplete) {
    return Result<nlohmann::json>::err("skate run already complete");
  }

  const float   diff  = std::clamp(difficulty, 0.1F, 1.0F);
  const int32_t combo = std::clamp(comboMultiplier, 1, 8);
  m_comboMultiplier   = combo;
  m_peakCombo         = std::max(m_peakCombo, combo);

  const float points = (8.0F + diff * 12.0F) * static_cast<float>(combo);
  m_trickScore += points;
  ++m_tricksLanded;

  if (m_tricksLanded >= kSpecialsUnlockThreshold && m_tricksBailed == 0) {
    m_specialsUnlocked = true;
  }

  checkRunEnd();

  nlohmann::json payload = stateJson();
  payload["trick"] = {
      {"difficulty",       diff},
      {"combo_multiplier", combo},
      {"points",           points},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto SkateboardingMode::onNamedTrick(std::string_view trickName, float timingNormalized)
    -> Result<nlohmann::json> {
  if (m_phase == SkatePhase::kRunComplete) {
    return Result<nlohmann::json>::err("skate run already complete");
  }

  const float timing = std::clamp(timingNormalized, 0.0F, 1.0F);
  const float diff   = trickDifficulty(trickName);
  m_lastTrickName    = std::string(trickName);

  // Reject special tricks if not yet unlocked.
  const bool isSpecial = (trickName == "900" || trickName == "mcttwist" ||
                          trickName == "christ_air");
  if (isSpecial && !m_specialsUnlocked) {
    return Result<nlohmann::json>::err("special tricks not yet unlocked — land 10 tricks first");
  }

  // Special tricks get a 3× difficulty multiplier on top of base.
  const float specialMult = isSpecial ? 3.0F : 1.0F;

  const float points = (8.0F + diff * 12.0F) * specialMult *
                       static_cast<float>(m_comboMultiplier) *
                       timingBonus(timing);
  m_trickScore += points;
  ++m_tricksLanded;

  if (m_tricksLanded >= kSpecialsUnlockThreshold && m_tricksBailed == 0) {
    m_specialsUnlocked = true;
  }

  checkRunEnd();

  const std::string grade = timing >= 0.92F ? "perfect" : timing >= 0.65F ? "good" : "miss";
  nlohmann::json payload  = stateJson();
  payload["named_trick"] = {
      {"name",             m_lastTrickName},
      {"difficulty",       diff},
      {"timing",           timing},
      {"timing_grade",     grade},
      {"combo_multiplier", m_comboMultiplier},
      {"special",          isSpecial},
      {"points",           points},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto SkateboardingMode::bail() -> Result<nlohmann::json> {
  if (m_phase == SkatePhase::kRunComplete) {
    return Result<nlohmann::json>::err("skate run already complete");
  }

  ++m_tricksBailed;
  m_comboMultiplier  = 1;
  m_manualActive     = false;
  m_manualTimer      = 0.0F;
  // Bailing resets specials-unlock progress.
  m_specialsUnlocked = false;

  checkRunEnd();

  nlohmann::json payload = stateJson();
  payload["bail"] = {{"bails", m_tricksBailed}, {"combo_reset", true}, {"specials_reset", true}};
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto SkateboardingMode::onManual(float balanceNormalized) -> Result<nlohmann::json> {
  if (m_phase == SkatePhase::kRunComplete) {
    return Result<nlohmann::json>::err("skate run already complete");
  }

  const float balance = std::clamp(balanceNormalized, 0.0F, 1.0F);
  const bool inWindow = balance >= (0.5F - kManualTolerance) &&
                        balance <= (0.5F + kManualTolerance);

  if (!m_manualActive) {
    m_manualActive    = true;
    m_manualTimer     = 0.0F;
    m_comboMultiplier = std::min(m_comboMultiplier + 1, 8);
    m_peakCombo       = std::max(m_peakCombo, m_comboMultiplier);
  }

  if (!inWindow) {
    // Out of balance — fall off manual, reset combo.
    m_manualActive    = false;
    m_manualTimer     = 0.0F;
    m_comboMultiplier = 1;
  }

  nlohmann::json payload = stateJson();
  payload["manual"] = {
      {"balance",       balance},
      {"in_window",     inWindow},
      {"duration",      m_manualTimer},
      {"combo",         m_comboMultiplier},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto SkateboardingMode::endManual() -> Result<nlohmann::json> {
  if (!m_manualActive) {
    nlohmann::json payload = stateJson();
    payload["manual_end"] = {{"note", "no manual active"}};
    return Result<nlohmann::json>::ok(std::move(payload));
  }

  // Award duration bonus: 1 point per second of clean manual.
  const float durationBonus = m_manualTimer * 1.0F;
  m_trickScore  += durationBonus;
  m_manualActive = false;

  checkRunEnd();

  nlohmann::json payload = stateJson();
  payload["manual_end"] = {
      {"duration",       m_manualTimer},
      {"duration_bonus", durationBonus},
  };
  m_manualTimer = 0.0F;
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto SkateboardingMode::stateJson() const -> nlohmann::json {
  return {
      {"phase",              static_cast<int>(m_phase)},
      {"trick_score",        static_cast<int32_t>(m_trickScore)},
      {"win_target",         kWinScore},
      {"run_timer",          m_runTimer},
      {"run_duration",       kRunDurationSeconds},
      {"time_remaining",     std::max(0.0F, kRunDurationSeconds - m_runTimer)},
      {"combo_multiplier",   m_comboMultiplier},
      {"peak_combo",         m_peakCombo},
      {"tricks_landed",      m_tricksLanded},
      {"tricks_bailed",      m_tricksBailed},
      {"max_bails",          kMaxBails},
      {"specials_unlocked",  m_specialsUnlocked},
      {"specials_threshold", kSpecialsUnlockThreshold},
      {"manual_active",      m_manualActive},
      {"manual_timer",       m_manualTimer},
      {"last_trick",         m_lastTrickName},
      {"run_complete",       isRunComplete()},
      {"release_state",      "validate_only"},
  };
}

} // namespace nexus::gameplay
