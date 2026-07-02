#include "nexus/gameplay/who_scene_it_mode.h"

#include "nexus/gameplay/arena_mode_registry.h"

#include <algorithm>

namespace nexus::gameplay {

void WhoSceneItMode::reset() {
  m_phase = WhoSceneItPhase::kLobby;
  m_correctCount = 0;
  m_opponentCorrect = 0;
  m_questionsPlayed = 0;
  m_buzzWins = 0;
  m_currentStreak = 0;
  m_peakStreak = 0;
  m_cognitiveScore = 0.0F;
  m_currentCategory.clear();
  m_phaseTimer = 0.0F;
  m_playerHasBuzz = false;
}

void WhoSceneItMode::update(double deltaSeconds) {
  if (m_phase == WhoSceneItPhase::kMatchWon) {
    return;
  }

  m_phaseTimer += static_cast<float>(deltaSeconds);
  if (m_phase == WhoSceneItPhase::kAnswered && m_phaseTimer >= 3.5F) {
    advanceGhostContestant();
    m_phase = WhoSceneItPhase::kLobby;
    m_phaseTimer = 0.0F;
    m_playerHasBuzz = false;
  }
}

auto WhoSceneItMode::buzzIn(float timing) -> Result<nlohmann::json> {
  if (m_phase == WhoSceneItPhase::kMatchWon) {
    return Result<nlohmann::json>::err("who scene it match already won");
  }

  const float t = std::clamp(timing, 0.0F, 1.0F);
  m_phase = WhoSceneItPhase::kBuzzWindow;
  m_playerHasBuzz = t >= kBuzzPerfectThreshold || t >= 0.55F;
  if (m_playerHasBuzz) {
    ++m_buzzWins;
  }

  nlohmann::json payload = stateJson();
  payload["buzz"] = {
      {"timing", t},
      {"won_buzz", m_playerHasBuzz},
      {"grade", t >= kBuzzPerfectThreshold ? "perfect" : t >= 0.55F ? "good" : "late"},
  };
  payload["agent_envelope"] = {
      {"command", "fel.scene.buzz_in"},
      {"won_buzz", m_playerHasBuzz},
      {"buzz_wins", m_buzzWins},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto WhoSceneItMode::submitAnswer(bool correct, float responseTimeSeconds,
                                    std::string_view clipCategory) -> Result<nlohmann::json> {
  if (m_phase == WhoSceneItPhase::kMatchWon) {
    return Result<nlohmann::json>::err("who scene it match already won");
  }
  if (!m_playerHasBuzz && m_phase != WhoSceneItPhase::kBuzzWindow) {
    return Result<nlohmann::json>::err("buzz in before answering");
  }

  const float responseTime = std::clamp(responseTimeSeconds, 0.0F, kQuestionTimeLimit);
  m_currentCategory = std::string(clipCategory.empty() ? "ClassicFilm" : clipCategory);
  ++m_questionsPlayed;
  m_phase = WhoSceneItPhase::kAnswered;
  m_phaseTimer = 0.0F;

  bool playerGotIt = correct;
  float scoreDelta = 0.0F;
  if (playerGotIt) {
    ++m_correctCount;
    ++m_currentStreak;
    m_peakStreak = std::max(m_peakStreak, m_currentStreak);
    const float speedBonus =
        std::clamp(1.0F - (responseTime / kQuestionTimeLimit), 0.0F, 0.4F);
    scoreDelta = 100.0F + speedBonus * 40.0F;
    m_cognitiveScore += scoreDelta;
  } else {
    m_currentStreak = 0;
  }

  if (m_correctCount >= kCorrectToWin) {
    m_phase = WhoSceneItPhase::kMatchWon;
  }

  nlohmann::json payload = stateJson();
  payload["answer"] = {
      {"correct", playerGotIt},
      {"response_time", responseTime},
      {"category", m_currentCategory},
      {"score_delta", scoreDelta},
  };
  payload["agent_envelope"] = {
      {"command", "fel.scene.answer"},
      {"correct_count", m_correctCount},
      {"win_target", kCorrectToWin},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

void WhoSceneItMode::advanceGhostContestant() {
  if (m_questionsPlayed == 0) {
    return;
  }
  if (m_questionsPlayed % 4 == 0 && m_opponentCorrect < m_correctCount) {
    ++m_opponentCorrect;
  }
}

auto WhoSceneItMode::stateJson() const -> nlohmann::json {
  return {
      {"phase", static_cast<int>(m_phase)},
      {"correct_count", m_correctCount},
      {"opponent_correct", m_opponentCorrect},
      {"win_target", kCorrectToWin},
      {"questions_played", m_questionsPlayed},
      {"buzz_wins", m_buzzWins},
      {"current_streak", m_currentStreak},
      {"peak_streak", m_peakStreak},
      {"cognitive_score", m_cognitiveScore},
      {"current_category", m_currentCategory},
      {"player_has_buzz", m_playerHasBuzz},
      {"match_complete", isMatchComplete()},
      {"release_state", std::string(ArenaModeRegistry::releaseStateLabelForMode("who_scene_it"))},
  };
}

} // namespace nexus::gameplay
