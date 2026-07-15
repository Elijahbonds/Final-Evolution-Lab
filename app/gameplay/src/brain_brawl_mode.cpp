#include "nexus/gameplay/brain_brawl_mode.h"

#include <algorithm>

namespace nexus::gameplay {

// ── Internal helpers ─────────────────────────────────────────────────────────

auto BrainBrawlMode::tierFromQuestionIndex(int32_t idx) -> BrainBrawlTier {
  if (idx <= 3) return BrainBrawlTier::kEasy;
  if (idx <= 6) return BrainBrawlTier::kMedium;
  return BrainBrawlTier::kHard;
}

auto BrainBrawlMode::basePointsForTier(BrainBrawlTier tier) -> float {
  switch (tier) {
  case BrainBrawlTier::kEasy:   return kBasePointsEasy;
  case BrainBrawlTier::kMedium: return kBasePointsMedium;
  case BrainBrawlTier::kHard:   return kBasePointsHard;
  }
  return kBasePointsMedium;
}

auto BrainBrawlMode::categoryLabel(BrainBrawlCategory cat) -> const char* {
  switch (cat) {
  case BrainBrawlCategory::kSportsIQ:     return "SportsIQ";
  case BrainBrawlCategory::kBiomechanics: return "Biomechanics";
  case BrainBrawlCategory::kNutrition:    return "Nutrition";
  case BrainBrawlCategory::kMentalEdge:   return "MentalEdge";
  case BrainBrawlCategory::kRecovery:     return "Recovery";
  }
  return "SportsIQ";
}

// ── Public API ───────────────────────────────────────────────────────────────

void BrainBrawlMode::reset() {
  m_phase            = BrainBrawlPhase::kLobby;
  m_currentTier      = BrainBrawlTier::kEasy;
  m_selectedCategory = BrainBrawlCategory::kSportsIQ;
  m_cognitiveScore   = 0.0F;
  m_playerCorrect    = 0;
  m_opponentCorrect  = 0;
  m_questionsAttempted = 0;
  m_currentStreak    = 0;
  m_peakStreak       = 0;
  m_streakMultiplier = 1.0F;
  m_prqDelta         = 0.0F;
  m_lastAnswerCorrect = false;
  m_lastScoreDelta    = 0.0F;
  m_currentCategory.clear();
  m_phaseTimer = 0.0F;
}

void BrainBrawlMode::update(double deltaSeconds) {
  if (m_phase == BrainBrawlPhase::kMatchWon) {
    return;
  }

  m_phaseTimer += static_cast<float>(deltaSeconds);

  // Advance ghost opponent on a cadence tied to question difficulty.
  if (m_phase == BrainBrawlPhase::kActive && m_phaseTimer >= 4.0F) {
    advanceGhostOpponent();
    m_phaseTimer = 0.0F;
  }

  // Release from stadium-reveal pause back to active.
  if (m_phase == BrainBrawlPhase::kRevealPause &&
      m_phaseTimer >= kRevealPauseDuration) {
    m_phase = BrainBrawlPhase::kActive;
    m_phaseTimer = 0.0F;
  }
}

auto BrainBrawlMode::selectCategory(BrainBrawlCategory category) -> Result<nlohmann::json> {
  if (m_phase == BrainBrawlPhase::kMatchWon) {
    return Result<nlohmann::json>::err("brain brawl match already won");
  }
  m_selectedCategory = category;
  m_currentCategory  = categoryLabel(category);

  return Result<nlohmann::json>::ok({
      {"action", "category_selected"},
      {"category", m_currentCategory},
      {"tier", static_cast<int>(tierFromQuestionIndex(m_questionsAttempted + 1))},
  });
}

auto BrainBrawlMode::submitAnswer(bool correct, float responseTimeSeconds,
                                  std::string_view category) -> Result<nlohmann::json> {
  if (m_phase == BrainBrawlPhase::kMatchWon) {
    return Result<nlohmann::json>::err("brain brawl match already won");
  }

  // Accept category override from caller (legacy path) or fall back to pre-selected.
  if (!category.empty()) {
    m_currentCategory = std::string(category);
  } else if (m_currentCategory.empty()) {
    m_currentCategory = categoryLabel(m_selectedCategory);
  }

  if (m_phase != BrainBrawlPhase::kActive) {
    m_phase = BrainBrawlPhase::kActive;
  }
  ++m_questionsAttempted;

  // Update difficulty tier based on current question index.
  m_currentTier = tierFromQuestionIndex(m_questionsAttempted);

  const float responseTime = std::clamp(responseTimeSeconds, 0.0F, kQuestionTimeLimit);
  m_lastAnswerCorrect      = correct;
  m_lastScoreDelta         = 0.0F;

  if (correct) {
    ++m_playerCorrect;
    ++m_currentStreak;
    m_peakStreak = std::max(m_peakStreak, m_currentStreak);
    if (m_currentStreak >= kStreakBonusThreshold) {
      m_streakMultiplier = 1.25F;
    }
    const float speedBonus =
        std::clamp(1.0F - (responseTime / kQuestionTimeLimit), 0.0F, 0.5F);
    const float base = basePointsForTier(m_currentTier);
    m_lastScoreDelta = (base + speedBonus * 50.0F) * m_streakMultiplier;
    m_cognitiveScore += m_lastScoreDelta;
  } else {
    m_currentStreak    = 0;
    m_streakMultiplier = 1.0F;
    // Hard wrong answers cost a small cognitive-score deduction.
    if (m_currentTier == BrainBrawlTier::kEasy) {
      m_cognitiveScore = std::max(m_cognitiveScore - 10.0F, 0.0F);
    }
  }

  const bool matchOver = (m_questionsAttempted >= kQuestionsToWin ||
                          m_playerCorrect     >= kQuestionsToWin ||
                          m_opponentCorrect   >= kQuestionsToWin);
  if (matchOver) {
    computePrqDelta();
    m_phase      = BrainBrawlPhase::kMatchWon;
    m_phaseTimer = 0.0F;
  } else {
    // Enter stadium-reveal pause before advancing to next question.
    m_phase      = BrainBrawlPhase::kRevealPause;
    m_phaseTimer = 0.0F;
  }

  nlohmann::json payload = stateJson();
  payload["answer"] = {
      {"correct",         m_lastAnswerCorrect},
      {"response_time",   responseTime},
      {"category",        m_currentCategory},
      {"tier",            static_cast<int>(m_currentTier)},
      {"tier_label",      m_currentTier == BrainBrawlTier::kEasy   ? "easy"
                          : m_currentTier == BrainBrawlTier::kMedium ? "medium"
                                                                     : "hard"},
      {"score_delta",     m_lastScoreDelta},
      {"streak_multiplier", m_streakMultiplier},
      // Stadium reveal: simulated audience percentage for visual drama.
      {"audience_pct_correct", correct ? 62 + (m_questionsAttempted % 20) : 38},
  };
  payload["session_mode_id"] = "brain_brawl";  // standard endpoint alignment
  return Result<nlohmann::json>::ok(std::move(payload));
}

// ── Private helpers ──────────────────────────────────────────────────────────

void BrainBrawlMode::advanceGhostOpponent() {
  if (m_questionsAttempted == 0) {
    return;
  }

  // When a real remote peer is registered, their score is applied via
  // applyRemoteAnswer(); ghost AI is disabled to avoid double-counting.
  if (m_remoteOpponent != nullptr) {
    m_opponentCorrect = m_remoteOpponent->correct;
    return;
  }

  // Difficulty curve: opponent answers correctly with increasing frequency.
  //   Q1–3 (easy):   1-in-4
  //   Q4–6 (medium): 1-in-3
  //   Q7–9 (hard):   1-in-2
  //   Q10+ (hard+):  every other question (1-in-2)
  const int interval = m_questionsAttempted <= 3  ? 4
                       : m_questionsAttempted <= 6 ? 3
                                                  : 2;
  if (m_questionsAttempted % interval == 0) {
    ++m_opponentCorrect;
  }
}

void BrainBrawlMode::computePrqDelta() {
  if (m_playerCorrect > m_opponentCorrect) {
    m_prqDelta = kPrqWin;
  } else if (m_playerCorrect == m_opponentCorrect) {
    m_prqDelta = kPrqDraw;
  } else {
    m_prqDelta = kPrqLoss;
  }
}

void BrainBrawlMode::applyRemoteAnswer(bool correct) {
  // Called from the gameplay update loop when a kPlayerInput NetMessage with
  // action="submit_answer" arrives from the remote / local-2P peer.
  if (correct) {
    ++m_opponentCorrect;
  }
  // Check match-over condition from the remote side.
  const bool matchOver = (m_opponentCorrect >= kQuestionsToWin);
  if (matchOver && m_phase != BrainBrawlPhase::kMatchWon) {
    computePrqDelta();
    m_phase      = BrainBrawlPhase::kMatchWon;
    m_phaseTimer = 0.0F;
  }
}

void BrainBrawlMode::setRemoteOpponent(const RemotePlayerState* state) {
  m_remoteOpponent = state;
  // Immediately sync score from the latest snapshot when registering.
  if (m_remoteOpponent != nullptr) {
    m_opponentCorrect = m_remoteOpponent->correct;
  }
}

auto BrainBrawlMode::stateJson() const -> nlohmann::json {
  const char* phaseStr =
      m_phase == BrainBrawlPhase::kLobby       ? "lobby"
      : m_phase == BrainBrawlPhase::kActive     ? "active"
      : m_phase == BrainBrawlPhase::kRevealPause ? "reveal_pause"
                                                 : "match_won";

  const char* tierStr =
      m_currentTier == BrainBrawlTier::kEasy   ? "easy"
      : m_currentTier == BrainBrawlTier::kMedium ? "medium"
                                                 : "hard";

  return {
      {"phase",                phaseStr},
      {"cognitive_score",      m_cognitiveScore},
      {"player_correct",       m_playerCorrect},
      {"opponent_correct",     m_opponentCorrect},
      {"questions_attempted",  m_questionsAttempted},
      {"questions_to_win",     kQuestionsToWin},
      {"current_streak",       m_currentStreak},
      {"peak_streak",          m_peakStreak},
      {"streak_multiplier",    m_streakMultiplier},
      {"current_category",     m_currentCategory},
      {"current_tier",         tierStr},
      {"prq_delta",            m_prqDelta},
      {"reveal_pause_duration", kRevealPauseDuration},
      {"match_complete",       isMatchComplete()},
      {"multiplayer",          m_remoteOpponent != nullptr},
      // Standard session endpoint alignment (replaces non-standard /api/brain-brawl/submit).
      {"session_mode_id",      "brain_brawl"},
      {"release_state",        "validate_only"},
  };
}

} // namespace nexus::gameplay
