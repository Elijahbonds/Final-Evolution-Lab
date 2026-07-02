#include "nexus/gameplay/outcome_sport_mode.h"

#include "nexus/gameplay/arena_mode_registry.h"

#include <algorithm>
#include <string_view>

namespace nexus::gameplay {

namespace {

constexpr int32_t kBasketballWin = 21;
constexpr int32_t kVolleyballWin = 25;
constexpr int32_t kBaseballFinalInning = 9;
constexpr int32_t kGolfHoles = 9;
constexpr int32_t kGolfParPerHole = 4;
constexpr int32_t kTennisGamesToWinSet = 4;
constexpr int32_t kTennisSetsToWinMatch = 2;
constexpr int32_t kFootballWinTouchdowns = 3;
constexpr int32_t kSoccerWinGoals = 5;

[[nodiscard]] auto readAction(const nlohmann::json& params) -> std::string {
  if (params.contains("sport_action") && params.at("sport_action").is_string()) {
    return params.at("sport_action").get<std::string>();
  }
  if (params.contains("action") && params.at("action").is_string()) {
    return params.at("action").get<std::string>();
  }
  if (params.contains("shot_type") && params.at("shot_type").is_string()) {
    return params.at("shot_type").get<std::string>();
  }
  if (params.contains("play_type") && params.at("play_type").is_string()) {
    return params.at("play_type").get<std::string>();
  }
  if (params.contains("club") && params.at("club").is_string()) {
    return params.at("club").get<std::string>();
  }
  if (params.contains("rally_type") && params.at("rally_type").is_string()) {
    return params.at("rally_type").get<std::string>();
  }
  return {};
}

} // namespace

void OutcomeSportMode::reset(std::string_view modeId) {
  if (!modeId.empty()) {
    m_modeId = std::string(modeId);
  } else {
    m_modeId.clear();
  }
  m_playerScore = 0.0F;
  m_opponentScore = 0.0F;
  m_playerMetric = 0;
  m_opponentMetric = 0;
  m_secondaryMetric = 0;
  m_playerSets = 0;
  m_opponentSets = 0;
  m_threshold = 75.0F;
  m_pulses = 0;
  m_streak = 0;
  m_lastAction.clear();
  m_matchComplete = false;

  if (m_modeId.empty()) {
    return;
  }

  if (m_modeId == "karate_h2h") {
    m_playerScore = 100.0F;
    m_opponentScore = 100.0F;
  }
  if (m_modeId == "golf") {
    m_secondaryMetric = kGolfHoles * kGolfParPerHole;
    m_playerMetric = 0;
  }
  if (m_modeId == "baseball") {
    m_secondaryMetric = 1;
  }
}

void OutcomeSportMode::update(double /*deltaSeconds*/) {
  if (m_matchComplete) {
    return;
  }
  applyOpponentPressure();
}

auto OutcomeSportMode::pointsForPulse(bool success, float timing) const -> int32_t {
  if (!success) {
    return 0;
  }
  if (timing >= 0.92F) {
    return 3;
  }
  if (timing >= 0.65F) {
    return 2;
  }
  return 1;
}

void OutcomeSportMode::applyOpponentPressure() {
  if (m_pulses > 0 && m_pulses % 5 == 0 && m_playerMetric > m_opponentMetric) {
    if (m_modeId == "basketball_3v3" || m_modeId == "tennis" || m_modeId == "volleyball") {
      m_opponentMetric = std::min(m_opponentMetric + 1, m_playerMetric);
    }
  }
}

void OutcomeSportMode::advanceBaseballInning() {
  m_secondaryMetric = std::min(m_secondaryMetric + 1, kBaseballFinalInning);
}

void OutcomeSportMode::applyTennisGamePoint(bool playerWonPoint, bool ace) {
  const int32_t gameDelta = ace ? 2 : 1;
  if (playerWonPoint) {
    m_playerMetric += gameDelta;
  } else {
    m_opponentMetric += gameDelta;
  }

  const auto maybeWinSet = [&](int32_t playerGames, int32_t opponentGames) -> bool {
    const int32_t lead = playerGames - opponentGames;
    return playerGames >= kTennisGamesToWinSet && lead >= 2;
  };

  if (maybeWinSet(m_playerMetric, m_opponentMetric)) {
    ++m_playerSets;
    m_playerMetric = 0;
    m_opponentMetric = 0;
  } else if (maybeWinSet(m_opponentMetric, m_playerMetric)) {
    ++m_opponentSets;
    m_playerMetric = 0;
    m_opponentMetric = 0;
  }

  m_playerScore = static_cast<float>(m_playerSets);
  m_opponentScore = static_cast<float>(m_opponentSets);
  if (m_playerSets >= kTennisSetsToWinMatch || m_opponentSets >= kTennisSetsToWinMatch) {
    m_matchComplete = true;
  }
}

auto OutcomeSportMode::pulse(const nlohmann::json& params) -> Result<nlohmann::json> {
  if (m_modeId.empty()) {
    return Result<nlohmann::json>::err("outcome sport mode not initialized");
  }
  if (m_matchComplete) {
    return Result<nlohmann::json>::err("match already complete");
  }
  if (!params.is_object()) {
    return Result<nlohmann::json>::err("sport pulse params must be object");
  }

  const bool success = params.value("success", true);
  const float timing = std::clamp(params.value("timing", 0.85F), 0.0F, 1.0F);
  const std::string action = readAction(params);
  m_lastAction = action;
  int32_t points = pointsForPulse(success, timing);
  ++m_pulses;

  if (success) {
    ++m_streak;
  } else {
    m_streak = 0;
  }

  if (m_modeId == "basketball_3v3") {
    if (action == "three_pointer" && success) {
      points += (timing >= 0.85F ? 2 : 1);
    }
    if (m_streak >= 3 && success) {
      points += 1;
    }
    m_playerMetric += points;
    if (!success && timing < 0.4F) {
      m_opponentMetric += 1;
    }
    m_playerScore = static_cast<float>(m_playerMetric);
    m_opponentScore = static_cast<float>(m_opponentMetric);
    if (m_playerMetric >= kBasketballWin || m_opponentMetric >= kBasketballWin) {
      m_matchComplete = true;
    }
  } else if (m_modeId == "karate_h2h") {
    const bool heavy = action == "heavy_strike";
    const bool block = action == "block";
    const bool counter = action == "counter";
    if (success) {
      float damage = static_cast<float>(points) * 8.0F;
      if (heavy) {
        damage *= 1.5F;
      }
      if (counter && timing >= 0.85F) {
        damage = 12.0F;
      }
      m_opponentScore = std::max(0.0F, m_opponentScore - damage);
    } else if (block) {
      m_playerScore = std::max(0.0F, m_playerScore - 2.0F);
    } else {
      m_playerScore = std::max(0.0F, m_playerScore - 6.0F);
    }
    if (m_playerScore <= 0.0F || m_opponentScore <= 0.0F) {
      m_matchComplete = true;
    }
  } else if (m_modeId == "baseball") {
    if (action == "home_run" && success && timing >= 0.92F) {
      m_playerMetric += 4;
    } else if (success) {
      m_playerMetric += points;
    } else if (action == "strikeout") {
      if (m_pulses % 3 == 0) {
        advanceBaseballInning();
      }
    }
    if (m_pulses % 6 == 0) {
      advanceBaseballInning();
    }
    if (m_pulses % 8 == 0 && m_playerMetric > 0) {
      m_opponentMetric += 1;
    }
    m_playerScore = static_cast<float>(m_playerMetric);
    m_opponentScore = static_cast<float>(m_opponentMetric);
    if (m_secondaryMetric >= kBaseballFinalInning &&
        (m_playerMetric != m_opponentMetric || m_pulses >= 48)) {
      m_matchComplete = true;
    }
  } else if (m_modeId == "football") {
    if (action == "field_goal" && success) {
      m_playerScore += 3.0F;
    } else if (success && (action == "touchdown" || points >= 2)) {
      m_playerMetric += 1;
      m_playerScore += 6.0F;
    } else if (!success && action == "turnover") {
      m_opponentMetric += 1;
      m_opponentScore += 6.0F;
    } else if (!success) {
      m_opponentMetric += 1;
    }
    m_opponentScore = std::max(m_opponentScore, static_cast<float>(m_opponentMetric) * 6.0F);
    if (m_playerMetric >= kFootballWinTouchdowns || m_opponentMetric >= kFootballWinTouchdowns) {
      m_matchComplete = true;
    }
  } else if (m_modeId == "soccer") {
    if (action == "penalty") {
      if (success) {
        m_playerMetric += 1;
      } else {
        m_opponentMetric += 1;
      }
    } else if (success && points >= 2) {
      m_playerMetric += 1;
    } else if (!success && timing < 0.5F) {
      m_opponentMetric += 1;
    }
    m_playerScore = static_cast<float>(m_playerMetric);
    m_opponentScore = static_cast<float>(m_opponentMetric);
    if (m_playerMetric >= kSoccerWinGoals || m_opponentMetric >= kSoccerWinGoals) {
      m_matchComplete = true;
    }
  } else if (m_modeId == "golf") {
    ++m_playerMetric;
    if (success && points >= 2) {
      m_playerMetric = std::max(0, m_playerMetric - 1);
    }
    if (action == "putt" && success && timing >= 0.88F) {
      m_playerMetric = std::max(0, m_playerMetric - 1);
    }
    m_playerScore = static_cast<float>(m_playerMetric);
    if (m_pulses >= kGolfHoles) {
      m_matchComplete = true;
    }
  } else if (m_modeId == "tennis") {
    const bool ace = action == "ace" && success;
    applyTennisGamePoint(success, ace);
  } else if (m_modeId == "volleyball") {
    int32_t rallyPoints = success ? 1 : 0;
    if (action == "ace_serve" && success && timing >= 0.92F) {
      rallyPoints = 2;
    }
    if (success) {
      m_playerMetric += rallyPoints;
    } else {
      m_opponentMetric += 1;
    }
    m_playerScore = static_cast<float>(m_playerMetric);
    m_opponentScore = static_cast<float>(m_opponentMetric);
    const int32_t lead = m_playerMetric - m_opponentMetric;
    const int32_t oppLead = m_opponentMetric - m_playerMetric;
    if ((m_playerMetric >= kVolleyballWin && lead >= 2) ||
        (m_opponentMetric >= kVolleyballWin && oppLead >= 2)) {
      m_matchComplete = true;
    }
  } else {
    m_playerMetric += points;
    m_playerScore = static_cast<float>(m_playerMetric);
    if (m_pulses >= 12) {
      m_matchComplete = true;
    }
  }

  nlohmann::json payload{{"outcome_sport", stateJson()}};
  payload["pulse"] = {{"success", success},
                      {"timing", timing},
                      {"points", points},
                      {"sport_action", m_lastAction},
                      {"streak", m_streak}};
  payload["release_state"] = std::string(ArenaModeRegistry::releaseStateLabelForMode(m_modeId));
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto OutcomeSportMode::stateJson() const -> nlohmann::json {
  nlohmann::json state{
      {"mode_id", m_modeId},
      {"player_score", m_playerScore},
      {"opponent_score", m_opponentScore},
      {"player_metric", m_playerMetric},
      {"opponent_metric", m_opponentMetric},
      {"secondary_metric", m_secondaryMetric},
      {"threshold", m_threshold},
      {"pulses", m_pulses},
      {"streak", m_streak},
      {"last_action", m_lastAction},
      {"match_complete", m_matchComplete},
      {"release_state", std::string(ArenaModeRegistry::releaseStateLabelForMode(m_modeId))},
  };

  if (m_modeId == "tennis") {
    state["player_sets"] = m_playerSets;
    state["opponent_sets"] = m_opponentSets;
    state["player_games"] = m_playerMetric;
    state["opponent_games"] = m_opponentMetric;
  }
  if (m_modeId == "golf") {
    state["holes_played"] = m_pulses;
    state["course_par"] = m_secondaryMetric;
  }
  if (m_modeId == "baseball") {
    state["inning"] = m_secondaryMetric;
  }
  if (m_modeId == "football") {
    state["player_touchdowns"] = m_playerMetric;
    state["opponent_touchdowns"] = m_opponentMetric;
  }
  if (m_modeId == "basketball_3v3") {
    state["hot_streak"] = m_streak >= 3;
  }
  if (m_modeId == "soccer") {
    state["win_target"] = kSoccerWinGoals;
    state["penalty_round"] = m_pulses;
    state["shot_type"] = "penalty";
  }

  return state;
}

auto OutcomeSportMode::sessionScoreInput() const -> MatchScoreInput {
  MatchScoreInput input{};
  input.playerScore = m_playerScore;
  input.opponentScore = m_opponentScore;
  input.playerRuns = m_playerMetric;
  input.opponentRuns = m_opponentMetric;
  input.inning = m_secondaryMetric;
  input.playerTouchdowns = m_playerMetric;
  input.opponentTouchdowns = m_opponentMetric;
  input.playerGoals = m_playerMetric;
  input.opponentGoals = m_opponentMetric;
  input.playerStrokes = m_playerMetric;
  input.parStrokes = m_secondaryMetric > 0 ? m_secondaryMetric : kGolfHoles * kGolfParPerHole;
  if (m_modeId == "tennis") {
    input.playerSets = m_playerSets;
    input.opponentSets = m_opponentSets;
  } else {
    input.playerSets = m_playerMetric;
    input.opponentSets = m_opponentMetric;
  }
  input.playerPoints = m_playerMetric;
  input.opponentPoints = m_opponentMetric;
  input.playerHp = m_playerScore;
  input.opponentHp = m_opponentScore;
  input.surfingScore = m_playerScore;
  input.surfingThreshold = m_threshold;
  return input;
}

auto OutcomeSportMode::isMatchComplete() const -> bool {
  return m_matchComplete;
}

} // namespace nexus::gameplay
