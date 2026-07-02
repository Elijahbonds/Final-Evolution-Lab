#include "nexus/gameplay/venice_pickup_mode.h"

#include <algorithm>
#include <cctype>

namespace nexus::gameplay {

void VenicePickupMode::reset() {
  m_playerScore = 0;
  m_opponentScore = 0;
  m_passesCompleted = 0;
  m_perfectCatches = 0;
  m_matchComplete = false;
  m_lastProcessedThrow = 0;
  m_passHistory.clear();
}

void VenicePickupMode::update(double /*deltaSeconds*/) {
  if (m_matchComplete) {
    return;
  }
  // Opponent pressure: occasional ghost score to keep pickup competitive.
  if (m_passesCompleted > 0 && m_passesCompleted % 4 == 0 && m_playerScore > m_opponentScore) {
    m_opponentScore = std::min(m_opponentScore + 1, kWinScore - 1);
  }
}

auto VenicePickupMode::onAction(std::string_view action, float timingNormalized, bool success)
    -> Result<nlohmann::json> {
  if (m_matchComplete) {
    return Result<nlohmann::json>::err("pickup match already complete");
  }

  const float timing = std::clamp(timingNormalized, 0.0F, 1.0F);
  std::string lowered(action);
  for (char& ch : lowered) {
    ch = static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));
  }

  CatchFeedback feedback = CatchFeedback::kMiss;
  if (success) {
    const float perfectThreshold = lowered == "drive" ? 0.88F : 0.92F;
    const float goodThreshold = lowered == "crossover" ? 0.70F : 0.65F;
    if (timing >= perfectThreshold) {
      feedback = CatchFeedback::kPerfect;
    } else if (timing >= goodThreshold) {
      feedback = CatchFeedback::kSolid;
    } else {
      feedback = CatchFeedback::kGraze;
    }
  }

  ThrowPulseEnvelope pulse{
      .impulseY = 8.0F + timing * 10.0F,
      .breathBoost = 1.0F,
      .catchFeedback = feedback,
      .catchRadiusNormalized = timing,
  };
  onThrowPulse(pulse);

  int bonusPoints = 0;
  if (lowered == "shoot" && feedback == CatchFeedback::kPerfect) {
    bonusPoints = 1;
  } else if (lowered == "crossover" && success && feedback != CatchFeedback::kMiss) {
    bonusPoints = 1;
  }
  if (bonusPoints > 0 && !m_matchComplete) {
    m_playerScore += bonusPoints;
    if (m_playerScore >= kWinScore) {
      m_matchComplete = true;
    }
  }

  nlohmann::json payload = stateJson();
  payload["action"] = {
      {"label", lowered},
      {"timing", timing},
      {"success", success},
      {"catch_feedback", static_cast<int>(feedback)},
      {"bonus_points", bonusPoints},
  };
  payload["pickup"] = stateJson();
  return Result<nlohmann::json>::ok(std::move(payload));
}

void VenicePickupMode::onThrowPulse(const ThrowPulseEnvelope& pulse) {
  if (m_matchComplete) {
    return;
  }

  ++m_passesCompleted;
  const int points = pointsForFeedback(pulse.catchFeedback);
  m_playerScore += points;
  if (pulse.catchFeedback == CatchFeedback::kPerfect) {
    ++m_perfectCatches;
  }

  m_passHistory.push_back({
      .feedback = pulse.catchFeedback,
      .impulseY = pulse.impulseY,
      .pointsAwarded = points,
  });

  if (m_playerScore >= kWinScore) {
    m_matchComplete = true;
  }
}

auto VenicePickupMode::pointsForFeedback(CatchFeedback feedback) -> int {
  switch (feedback) {
  case CatchFeedback::kPerfect:
    return 3;
  case CatchFeedback::kSolid:
    return 2;
  case CatchFeedback::kGraze:
    return 1;
  case CatchFeedback::kMiss:
  default:
    return 0;
  }
}

auto VenicePickupMode::stateJson() const -> nlohmann::json {
  nlohmann::json passes = nlohmann::json::array();
  for (const PickupPassEvent& event : m_passHistory) {
    passes.push_back({
        {"catch_feedback", static_cast<int>(event.feedback)},
        {"impulse_y", event.impulseY},
        {"points", event.pointsAwarded},
    });
  }

  return {
      {"player_score", m_playerScore},
      {"opponent_score", m_opponentScore},
      {"passes_completed", m_passesCompleted},
      {"perfect_catches", m_perfectCatches},
      {"win_target", kWinScore},
      {"match_complete", m_matchComplete},
      {"pass_history", std::move(passes)},
  };
}

} // namespace nexus::gameplay
