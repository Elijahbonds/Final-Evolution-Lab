// Who Scene It — Neuro Arena film quiz buzz-in simulator (who_scene_it)
#pragma once

#include "nexus/core/result.h"

#include <nlohmann/json.hpp>
#include <cstdint>
#include <string>

// GCC 13.3 workaround: forward-declare enum classes before large STL includes.
namespace nexus { namespace gameplay {
  enum class WhoSceneItPhase : std::uint8_t;
} } // namespace nexus::gameplay

namespace nexus::gameplay {

enum class WhoSceneItPhase : std::uint8_t {
  kLobby = 0,
  kBuzzWindow = 1,
  kAnswered = 2,
  kMatchWon = 3,
};

class WhoSceneItMode {
public:
  static constexpr int kCorrectToWin = 7;
  static constexpr float kBuzzPerfectThreshold = 0.92F;
  static constexpr float kQuestionTimeLimit = 12.0F;

  void reset();
  void update(double deltaSeconds);

  auto buzzIn(float timing) -> Result<nlohmann::json>;
  /// Validate-only: `correct` simulates server verify for film clip answer.
  auto submitAnswer(bool correct, float responseTimeSeconds, std::string_view clipCategory)
      -> Result<nlohmann::json>;

  [[nodiscard]] auto correctCount() const -> int32_t { return m_correctCount; }
  [[nodiscard]] auto isMatchComplete() const -> bool {
    return m_phase == WhoSceneItPhase::kMatchWon;
  }
  [[nodiscard]] auto stateJson() const -> nlohmann::json;

private:
  void advanceGhostContestant();

  WhoSceneItPhase m_phase{WhoSceneItPhase::kLobby};
  int32_t m_correctCount{0};
  int32_t m_opponentCorrect{0};
  int32_t m_questionsPlayed{0};
  int32_t m_buzzWins{0};
  int32_t m_currentStreak{0};
  int32_t m_peakStreak{0};
  float m_cognitiveScore{0.0F};
  std::string m_currentCategory;
  float m_phaseTimer{0.0F};
  bool m_playerHasBuzz{false};
};

} // namespace nexus::gameplay
