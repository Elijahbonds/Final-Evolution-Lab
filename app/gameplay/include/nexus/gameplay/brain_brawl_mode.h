// Brain Brawl — Neuro Arena cognitive Q&A simulator (brain_brawl)
#pragma once

#include "nexus/core/result.h"

#include <nlohmann/json.hpp>
#include <cstdint>
#include <string>

// GCC 13.3 workaround: forward-declare enum classes before large STL includes.
namespace nexus { namespace gameplay {
  enum class BrainBrawlPhase : std::uint8_t;
} } // namespace nexus::gameplay

namespace nexus::gameplay {

enum class BrainBrawlPhase : std::uint8_t {
  kLobby = 0,
  kActive = 1,
  kMatchWon = 2,
};

class BrainBrawlMode {
public:
  static constexpr int kQuestionsToWin = 10;
  static constexpr float kQuestionTimeLimit = 15.0F;
  static constexpr int kStreakBonusThreshold = 3;

  void reset();
  void update(double deltaSeconds);

  /// Validate-only: `correct` simulates server verify at POST /games/brainstorm/verify.
  auto submitAnswer(bool correct, float responseTimeSeconds, std::string_view category)
      -> Result<nlohmann::json>;

  [[nodiscard]] auto playerCorrect() const -> int32_t { return m_playerCorrect; }
  [[nodiscard]] auto opponentCorrect() const -> int32_t { return m_opponentCorrect; }
  [[nodiscard]] auto cognitiveScore() const -> float { return m_cognitiveScore; }
  [[nodiscard]] auto isMatchComplete() const -> bool {
    return m_phase == BrainBrawlPhase::kMatchWon;
  }
  [[nodiscard]] auto stateJson() const -> nlohmann::json;

private:
  void advanceGhostOpponent();

  BrainBrawlPhase m_phase{BrainBrawlPhase::kLobby};
  float m_cognitiveScore{0.0F};
  int32_t m_playerCorrect{0};
  int32_t m_opponentCorrect{0};
  int32_t m_questionsAttempted{0};
  int32_t m_currentStreak{0};
  int32_t m_peakStreak{0};
  float m_streakMultiplier{1.0F};
  std::string m_currentCategory;
  float m_phaseTimer{0.0F};
};

} // namespace nexus::gameplay
