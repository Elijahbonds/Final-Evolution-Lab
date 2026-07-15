#include "nexus/gameplay/gymnastics_mode.h"

#include <algorithm>

namespace nexus::gameplay {

namespace {
// Base thresholds — apparatus-specific overrides via member functions.
constexpr float kBasePerfectThreshold = 0.92F;
constexpr float kBaseGoodThreshold    = 0.65F;
} // namespace

// ── Apparatus-specific timing windows ────────────────────────────────────────
// Balance beam and vault reward precision more; floor and bars are more forgiving.

auto GymnasticsMode::perfectThreshold() const -> float {
  switch (m_apparatus) {
  case GymnasticsApparatus::kBalanceBeam: return 0.95F;
  case GymnasticsApparatus::kVault:       return 0.94F;
  case GymnasticsApparatus::kFloorExercise:
  case GymnasticsApparatus::kParallelBars:
  default:                                return kBasePerfectThreshold;
  }
}

auto GymnasticsMode::goodThreshold() const -> float {
  // Higher declared difficulty narrows the good window.
  switch (m_declaredDifficulty) {
  case RoutineDifficulty::kD7: return 0.73F;
  case RoutineDifficulty::kD6: return 0.69F;
  default:                     return kBaseGoodThreshold;
  }
}

// ── Static helpers ────────────────────────────────────────────────────────────

auto GymnasticsMode::apparatusLabel(GymnasticsApparatus a) -> const char* {
  switch (a) {
  case GymnasticsApparatus::kFloorExercise: return "floor_exercise";
  case GymnasticsApparatus::kBalanceBeam:   return "balance_beam";
  case GymnasticsApparatus::kVault:         return "vault";
  case GymnasticsApparatus::kParallelBars:  return "parallel_bars";
  }
  return "unknown";
}

auto GymnasticsMode::difficultyLabel(RoutineDifficulty d) -> const char* {
  switch (d) {
  case RoutineDifficulty::kD5: return "d5";
  case RoutineDifficulty::kD6: return "d6";
  case RoutineDifficulty::kD7: return "d7";
  }
  return "d5";
}

auto GymnasticsMode::dScoreForDifficulty(RoutineDifficulty d) -> float {
  switch (d) {
  case RoutineDifficulty::kD5: return kDScoreD5;
  case RoutineDifficulty::kD6: return kDScoreD6;
  case RoutineDifficulty::kD7: return kDScoreD7;
  }
  return kDScoreD5;
}

// ── Lifecycle ─────────────────────────────────────────────────────────────────

void GymnasticsMode::reset() {
  m_phase               = GymnasticsPhase::kWarmup;
  m_declaredDifficulty  = RoutineDifficulty::kD5;
  m_judgeScore          = 0.0F;
  m_dScore              = kDScoreD5;
  m_eScore              = 0.0F;
  m_difficultyTotal     = 0.0F;
  m_executionTotal      = 0.0F;
  m_artistryTotal       = 0.0F;
  m_elementsCompleted   = 0;
  m_consecutiveClean    = 0;
  m_consecutiveMisses   = 0;
  m_deductions          = 0;
  m_deductionPoints     = 0.0F;
}

void GymnasticsMode::update(double /*deltaSeconds*/) {
  if (m_phase == GymnasticsPhase::kScored) {
    return;
  }
}

// ── Public API ────────────────────────────────────────────────────────────────

auto GymnasticsMode::declareRoutine(RoutineDifficulty difficulty)
    -> Result<nlohmann::json> {
  if (m_phase == GymnasticsPhase::kScored) {
    return Result<nlohmann::json>::err("gymnastics routine already scored");
  }
  if (m_elementsCompleted > 0) {
    return Result<nlohmann::json>::err("cannot change difficulty mid-routine");
  }

  m_declaredDifficulty = difficulty;
  m_dScore             = dScoreForDifficulty(difficulty);

  return Result<nlohmann::json>::ok({
      {"gymnastics",        stateJson()},
      {"declared_routine",  {{"difficulty", difficultyLabel(difficulty)},
                              {"d_score",    m_dScore},
                              {"apparatus",  apparatusLabel(m_apparatus)}}},
      {"release_state",     "validate_only"},
  });
}

auto GymnasticsMode::rotateApparatus() -> Result<nlohmann::json> {
  // Cycle: floor → beam → vault → bars → floor
  const auto prev = m_apparatus;
  switch (m_apparatus) {
  case GymnasticsApparatus::kFloorExercise: m_apparatus = GymnasticsApparatus::kBalanceBeam;  break;
  case GymnasticsApparatus::kBalanceBeam:   m_apparatus = GymnasticsApparatus::kVault;         break;
  case GymnasticsApparatus::kVault:         m_apparatus = GymnasticsApparatus::kParallelBars;  break;
  case GymnasticsApparatus::kParallelBars:  m_apparatus = GymnasticsApparatus::kFloorExercise; break;
  }
  ++m_routinesScored;

  // Reset routine state for the new apparatus.
  m_phase             = GymnasticsPhase::kWarmup;
  m_declaredDifficulty= RoutineDifficulty::kD5;
  m_dScore            = kDScoreD5;
  m_eScore            = 0.0F;
  m_elementsCompleted = 0;
  m_consecutiveClean  = 0;
  m_consecutiveMisses = 0;
  m_deductions        = 0;
  m_deductionPoints   = 0.0F;
  // judgeScore, difficultyTotal, executionTotal, artistryTotal accumulate across rotations.

  return Result<nlohmann::json>::ok({
      {"gymnastics",     stateJson()},
      {"apparatus_rotation",
       {{"from", apparatusLabel(prev)},
        {"to",   apparatusLabel(m_apparatus)},
        {"routines_scored", m_routinesScored}}},
      {"release_state",  "validate_only"},
  });
}

auto GymnasticsMode::rhythmTap(float timingNormalized, float difficulty)
    -> Result<nlohmann::json> {
  if (m_phase == GymnasticsPhase::kScored) {
    return Result<nlohmann::json>::err("gymnastics routine already scored");
  }

  const float timing = std::clamp(timingNormalized, 0.0F, 1.0F);
  const float diff   = std::clamp(difficulty, 0.1F, 1.0F);
  m_phase            = GymnasticsPhase::kRoutine;

  const float elementScore = scoreTap(timing, diff);

  // Track consecutive clean / miss for flow momentum and fall penalty.
  const bool isClean = timing >= goodThreshold();
  if (isClean) {
    ++m_consecutiveClean;
    m_consecutiveMisses = 0;
  } else {
    m_consecutiveClean = 0;
    ++m_consecutiveMisses;
  }

  // Fall penalty: two consecutive misses = −1.0 Olympic deduction.
  if (m_consecutiveMisses >= 2) {
    m_consecutiveMisses = 0;  // reset to avoid stacking falls
    ++m_deductions;
    m_deductionPoints += kDeductionFall;
  }

  const float flowBonus = m_consecutiveClean >= 3 ? 1.15F
                          : m_consecutiveClean >= 2 ? 1.07F
                                                    : 1.0F;
  const float scoredElement = elementScore * flowBonus;

  // D-score is declared difficulty; E-score accumulates from execution.
  m_eScore = std::min(m_eScore + scoredElement * 0.6F, 10.0F);

  // Total judge score = D-score + E-score − deductions.
  m_judgeScore = std::max(0.0F, m_dScore + m_eScore - m_deductionPoints);
  m_judgeScore = std::min(m_judgeScore, 100.0F);

  m_difficultyTotal += diff * 10.0F;
  m_executionTotal  += scoredElement * 0.6F;
  m_artistryTotal   += scoredElement * 0.4F;
  ++m_elementsCompleted;
  checkCompletion();

  const char* grade = timing >= perfectThreshold()  ? "perfect"
                      : timing >= goodThreshold()   ? "good"
                                                    : "miss";
  return Result<nlohmann::json>::ok({
      {"gymnastics", stateJson()},
      {"tap", {
          {"timing",           timing},
          {"difficulty",       diff},
          {"element_score",    scoredElement},
          {"flow_bonus",       flowBonus},
          {"consecutive_clean",m_consecutiveClean},
          {"grade",            grade},
          {"d_score",          m_dScore},
          {"e_score",          m_eScore},
          {"deduction_total",  m_deductionPoints},
      }},
      {"release_state", "validate_only"},
  });
}

auto GymnasticsMode::applyDeduction(float value) -> Result<nlohmann::json> {
  if (m_phase == GymnasticsPhase::kScored) {
    return Result<nlohmann::json>::err("gymnastics routine already scored");
  }

  const float deduction = std::clamp(value, 0.1F, 5.0F);
  ++m_deductions;
  m_deductionPoints += deduction;
  m_judgeScore = std::max(m_dScore + m_eScore - m_deductionPoints, 0.0F);
  m_consecutiveClean  = 0;
  m_consecutiveMisses = 0;
  checkCompletion();

  return Result<nlohmann::json>::ok({
      {"gymnastics", stateJson()},
      {"deduction", {{"value", deduction}, {"total_deductions", m_deductions},
                     {"total_deduction_pts", m_deductionPoints}}},
      {"release_state", "validate_only"},
  });
}

// ── Private helpers ───────────────────────────────────────────────────────────

auto GymnasticsMode::scoreTap(float timingNormalized, float difficulty) -> float {
  const float perfect = perfectThreshold();
  const float good    = goodThreshold();
  const float base    = timingNormalized >= perfect ? 14.0F
                        : timingNormalized >= good  ?  9.0F
                                                    :  4.0F;
  return base * (0.75F + difficulty * 0.25F);
}

void GymnasticsMode::checkCompletion() {
  if (m_elementsCompleted >= kTargetElements || m_judgeScore >= kGoldThreshold) {
    m_phase = GymnasticsPhase::kScored;
  }
}

auto GymnasticsMode::stateJson() const -> nlohmann::json {
  const char* phaseStr = m_phase == GymnasticsPhase::kWarmup  ? "warmup"
                         : m_phase == GymnasticsPhase::kRoutine ? "routine"
                                                                : "scored";
  return {
      {"phase",               phaseStr},
      {"apparatus",           apparatusLabel(m_apparatus)},
      {"declared_difficulty", difficultyLabel(m_declaredDifficulty)},
      {"d_score",             m_dScore},
      {"e_score",             m_eScore},
      {"judge_score",         m_judgeScore},
      {"gold_threshold",      kGoldThreshold},
      {"difficulty_total",    m_difficultyTotal},
      {"execution_total",     m_executionTotal},
      {"artistry_total",      m_artistryTotal},
      {"elements_completed",  m_elementsCompleted},
      {"target_elements",     kTargetElements},
      {"consecutive_clean",   m_consecutiveClean},
      {"deductions",          m_deductions},
      {"deduction_points",    m_deductionPoints},
      {"routines_scored",     m_routinesScored},
      {"routine_complete",    isRoutineComplete()},
  };
}

} // namespace nexus::gameplay
