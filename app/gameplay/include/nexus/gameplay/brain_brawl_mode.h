// Brain Brawl — Neuro Arena cognitive Q&A simulator (brain_brawl)
// Inspirator: HQ Trivia / Jeopardy! / QuizUp
// Additions: difficulty tiers (easy/medium/hard), PRQ delta on match end,
//            category selection per question set, stadium answer-reveal pause.
#pragma once

#include "nexus/core/result.h"
#include "nexus/gameplay/remote_player_state.h"

#include <nlohmann/json.hpp>
#include <array>
#include <cstdint>
#include <string>

// GCC 13.3 workaround: forward-declare enum classes before large STL includes.
namespace nexus { namespace gameplay {
  enum class BrainBrawlPhase   : std::uint8_t;
  enum class BrainBrawlTier    : std::uint8_t;
  enum class BrainBrawlCategory: std::uint8_t;
} } // namespace nexus::gameplay

namespace nexus::gameplay {

enum class BrainBrawlPhase : std::uint8_t {
  kLobby       = 0,
  kActive      = 1,
  kRevealPause = 2,  // brief "stadium reveal" pause after each answer (1.5 s)
  kMatchWon    = 3,
};

// Difficulty tier auto-assigned by question index (1–3 easy, 4–6 medium, 7+ hard).
enum class BrainBrawlTier : std::uint8_t {
  kEasy   = 0,
  kMedium = 1,
  kHard   = 2,
};

// Five sport-science categories; player pre-selects one per question set.
enum class BrainBrawlCategory : std::uint8_t {
  kSportsIQ     = 0,
  kBiomechanics = 1,
  kNutrition    = 2,
  kMentalEdge   = 3,
  kRecovery     = 4,
};

class BrainBrawlMode {
public:
  static constexpr int   kQuestionsToWin      = 10;
  static constexpr float kQuestionTimeLimit   = 15.0F;
  static constexpr int   kStreakBonusThreshold = 3;
  static constexpr float kRevealPauseDuration = 1.5F;  // seconds of stadium reveal

  // Points per tier (base before speed bonus and streak multiplier).
  static constexpr float kBasePointsEasy   = 80.0F;
  static constexpr float kBasePointsMedium = 100.0F;
  static constexpr float kBasePointsHard   = 140.0F;

  // PRQ delta awarded at match end (Cognitive Flex attribute).
  static constexpr float kPrqWin  = 1.5F;
  static constexpr float kPrqDraw = 0.3F;
  static constexpr float kPrqLoss = 0.1F;

  void reset();
  void update(double deltaSeconds);

  /// Select the category for the current question before calling submitAnswer.
  /// category: 0=SportsIQ, 1=Biomechanics, 2=Nutrition, 3=MentalEdge, 4=Recovery
  auto selectCategory(BrainBrawlCategory category) -> Result<nlohmann::json>;

  /// Validate-only: `correct` simulates server verify at POST /api/games/session.
  /// Now routes through standard session endpoint matching brain_brawl mode_id.
  auto submitAnswer(bool correct, float responseTimeSeconds, std::string_view category)
      -> Result<nlohmann::json>;

  /// Apply an answer event received from a remote / local-2P opponent.
  /// Called by the gameplay update loop when a kPlayerInput NetMessage with
  /// action="submit_answer" arrives from the peer.
  void applyRemoteAnswer(bool correct);

  /// Register a remote player whose state drives the opponent slot instead of
  /// the ghost AI.  Pass nullptr to revert to ghost AI.
  void setRemoteOpponent(const RemotePlayerState* state);

  [[nodiscard]] auto playerCorrect()   const -> int32_t { return m_playerCorrect; }
  [[nodiscard]] auto opponentCorrect() const -> int32_t { return m_opponentCorrect; }
  [[nodiscard]] auto cognitiveScore()  const -> float   { return m_cognitiveScore; }
  [[nodiscard]] auto prqDelta()        const -> float   { return m_prqDelta; }
  [[nodiscard]] auto currentTier()     const -> BrainBrawlTier { return m_currentTier; }
  [[nodiscard]] auto isMatchComplete() const -> bool {
    return m_phase == BrainBrawlPhase::kMatchWon;
  }
  [[nodiscard]] auto isRevealPause()   const -> bool {
    return m_phase == BrainBrawlPhase::kRevealPause;
  }
  [[nodiscard]] auto hasRemoteOpponent() const -> bool { return m_remoteOpponent != nullptr; }
  [[nodiscard]] auto stateJson() const -> nlohmann::json;

private:
  void advanceGhostOpponent();
  void computePrqDelta();
  [[nodiscard]] static auto tierFromQuestionIndex(int32_t idx) -> BrainBrawlTier;
  [[nodiscard]] static auto basePointsForTier(BrainBrawlTier tier) -> float;
  [[nodiscard]] static auto categoryLabel(BrainBrawlCategory cat) -> const char*;

  BrainBrawlPhase    m_phase{BrainBrawlPhase::kLobby};
  BrainBrawlTier     m_currentTier{BrainBrawlTier::kEasy};
  BrainBrawlCategory m_selectedCategory{BrainBrawlCategory::kSportsIQ};
  float   m_cognitiveScore{0.0F};
  int32_t m_playerCorrect{0};
  int32_t m_opponentCorrect{0};
  int32_t m_questionsAttempted{0};
  int32_t m_currentStreak{0};
  int32_t m_peakStreak{0};
  float   m_streakMultiplier{1.0F};
  float   m_prqDelta{0.0F};
  // Stadium-reveal state: stores the last answer result to emit after the pause.
  bool    m_lastAnswerCorrect{false};
  float   m_lastScoreDelta{0.0F};
  std::string m_currentCategory;
  float m_phaseTimer{0.0F};
  // Non-owning pointer; null → ghost AI, non-null → real remote peer.
  const RemotePlayerState* m_remoteOpponent{nullptr};
};

} // namespace nexus::gameplay
