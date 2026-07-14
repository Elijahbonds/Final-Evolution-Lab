#include "nexus/gameplay/brain_brawl_mode.h"

#include <algorithm>

namespace nexus::gameplay {

void BrainBrawlMode::reset() {
  m_phase = BrainBrawlPhase::kLobby;
  m_cognitiveScore = 0.0F;
  m_playerCorrect = 0;
  m_opponentCorrect = 0;
  m_questionsAttempted = 0;
  m_currentStreak = 0;
  m_peakStreak = 0;
  m_streakMultiplier = 1.0F;
  m_currentCategory.clear();
  m_phaseTimer = 0.0F;
}

void BrainBrawlMode::update(double deltaSeconds) {
  if (m_phase == BrainBrawlPhase::kMatchWon) {
    return;
  }

  m_phaseTimer += static_cast<float>(deltaSeconds);
  if (m_phase == BrainBrawlPhase::kActive && m_phaseTimer >= 4.0F) {
    advanceGhostOpponent();
    m_phaseTimer = 0.0F;
  }
}

auto BrainBrawlMode::submitAnswer(bool correct, float responseTimeSeconds,
                                  std::string_view category) -> Result<nlohmann::json> {
  if (m_phase == BrainBrawlPhase::kMatchWon) {
    return Result<nlohmann::json>::err("brain brawl match already won");
  }

  m_phase = BrainBrawlPhase::kActive;
  ++m_questionsAttempted;
  m_currentCategory = std::string(category.empty() ? "SportsIQ" : category);

  const float responseTime = std::clamp(responseTimeSeconds, 0.0F, kQuestionTimeLimit);
  bool playerGotIt = correct;
  if (playerGotIt) {
    ++m_playerCorrect;
    ++m_currentStreak;
    m_peakStreak = std::max(m_peakStreak, m_currentStreak);
    if (m_currentStreak >= kStreakBonusThreshold) {
      m_streakMultiplier = 1.25F;
    }
    const float speedBonus =
        std::clamp(1.0F - (responseTime / kQuestionTimeLimit), 0.0F, 0.5F);
    m_cognitiveScore += (100.0F + speedBonus * 50.0F) * m_streakMultiplier;
  } else {
    m_currentStreak = 0;
    m_streakMultiplier = 1.0F;
  }

  if (m_questionsAttempted >= kQuestionsToWin ||
      m_playerCorrect >= kQuestionsToWin ||
      m_opponentCorrect >= kQuestionsToWin) {
    m_phase = BrainBrawlPhase::kMatchWon;
  }

  nlohmann::json payload = stateJson();
  payload["answer"] = {
      {"correct", playerGotIt},
      {"response_time", responseTime},
      {"category", m_currentCategory},
      {"score_delta", playerGotIt ? (100.0F * m_streakMultiplier) : 0.0F},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

void BrainBrawlMode::advanceGhostOpponent() {
  if (m_questionsAttempted == 0) {
    return;
  }
  // Difficulty curve: opponent answers correctly with increasing frequency as
  // the match progresses, creating meaningful score pressure.
  //   Q1–3:  opponent correct ~1-in-4 questions
  //   Q4–6:  1-in-3
  //   Q7–9:  1-in-2
  //   Q10+:  nearly every question (1-in-2 or better)
  const int interval = m_questionsAttempted <= 3  ? 4
                       : m_questionsAttempted <= 6 ? 3
                       : m_questionsAttempted <= 9 ? 2
                                                   : 2;
  if (m_questionsAttempted % interval == 0) {
    ++m_opponentCorrect;
  }
}

auto BrainBrawlMode::stateJson() const -> nlohmann::json {
  return {
      {"phase", static_cast<int>(m_phase)},
      {"cognitive_score", m_cognitiveScore},
      {"player_correct", m_playerCorrect},
      {"opponent_correct", m_opponentCorrect},
      {"questions_attempted", m_questionsAttempted},
      {"questions_to_win", kQuestionsToWin},
      {"current_streak", m_currentStreak},
      {"peak_streak", m_peakStreak},
      {"streak_multiplier", m_streakMultiplier},
      {"current_category", m_currentCategory},
      {"match_complete", isMatchComplete()},
  };
}

} // namespace nexus::gameplay
