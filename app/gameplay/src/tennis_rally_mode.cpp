#include "nexus/gameplay/tennis_rally_mode.h"

#include <algorithm>
#include <cstring>

namespace nexus::gameplay {

namespace {

constexpr float kServeAceThreshold = 0.93F;
constexpr float kServeFaultThreshold = 0.40F;
constexpr float kRallyWinnerThreshold = 0.88F;
constexpr float kRallyErrorThreshold = 0.45F;

} // namespace

void TennisRallyMode::reset() {
  m_phase = TennisPhase::kServe;
  m_playerSets = 0;
  m_opponentSets = 0;
  m_playerGames = 0;
  m_opponentGames = 0;
  m_gameScore = {};
  m_faultCount = 0;
  m_aces = 0;
  m_winners = 0;
  m_rallyExchanges = 0;
  m_deuce = false;
  m_playerHasAdv = false;
}

void TennisRallyMode::update(double /*deltaSeconds*/) {
  // Turn-based — no time-decay needed
}

auto TennisRallyMode::serve(float power, float placement) -> Result<nlohmann::json> {
  if (m_phase == TennisPhase::kMatchOver) {
    return Result<nlohmann::json>::err("match already over");
  }
  if (m_phase != TennisPhase::kServe) {
    return Result<nlohmann::json>::err("not in serve phase");
  }

  const float p = std::clamp(power, 0.0F, 1.0F);
  const float place = std::clamp(placement, -1.0F, 1.0F);

  ServeResult result = ServeResult::kIn;

  if (p >= kServeAceThreshold && std::abs(place) >= 0.6F) {
    result = ServeResult::kAce;
    ++m_aces;
  } else if (p < kServeFaultThreshold) {
    ++m_faultCount;
    if (m_faultCount >= 2) {
      result = ServeResult::kDoubleFault;
      m_faultCount = 0;
    } else {
      result = ServeResult::kFault;
    }
  } else {
    m_faultCount = 0;
  }

  if (result == ServeResult::kAce) {
    awardPoint(true);
  } else if (result == ServeResult::kDoubleFault) {
    awardPoint(false);
  } else if (result == ServeResult::kIn) {
    // Transition to rally
    m_phase = TennisPhase::kRally;
  }
  // kFault stays in serve phase

  const char* resultLabel = [result]() {
    switch (result) {
      case ServeResult::kAce:         return "ace";
      case ServeResult::kIn:          return "in";
      case ServeResult::kFault:       return "fault";
      case ServeResult::kDoubleFault: return "double_fault";
    }
    return "in";
  }();

  nlohmann::json payload = stateJson();
  payload["serve"] = {
      {"power", p},
      {"placement", place},
      {"result", resultLabel},
  };
  payload["agent_envelope"] = {
      {"command", "fel.tennis.serve"},
      {"result", resultLabel},
      {"aces", m_aces},
      {"player_games", m_playerGames},
      {"player_sets", m_playerSets},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto TennisRallyMode::rally(float timing, std::string_view shotType) -> Result<nlohmann::json> {
  if (m_phase == TennisPhase::kMatchOver) {
    return Result<nlohmann::json>::err("match already over");
  }
  if (m_phase != TennisPhase::kRally) {
    return Result<nlohmann::json>::err("not in rally phase");
  }

  const float t = std::clamp(timing, 0.0F, 1.0F);
  ++m_rallyExchanges;

  RallyResult result = RallyResult::kRallyOn;
  bool playerWon = false;

  if (t >= kRallyWinnerThreshold) {
    result = RallyResult::kWinner;
    playerWon = true;
    ++m_winners;
  } else if (t < kRallyErrorThreshold) {
    result = RallyResult::kError;
    playerWon = false;
  } else {
    // Rally continues — opponent may commit an error based on exchange count
    if (opponentRallyError(t)) {
      result = RallyResult::kWinner;
      playerWon = true;
      ++m_winners;
    }
  }

  if (result != RallyResult::kRallyOn) {
    awardPoint(playerWon);
    if (m_phase != TennisPhase::kMatchOver) {
      m_phase = TennisPhase::kServe;
    }
  }

  const char* resultLabel = [result]() {
    switch (result) {
      case RallyResult::kWinner:  return "winner";
      case RallyResult::kRallyOn: return "rally_on";
      case RallyResult::kError:   return "error";
    }
    return "rally_on";
  }();

  nlohmann::json payload = stateJson();
  payload["rally"] = {
      {"timing", t},
      {"shot_type", std::string(shotType)},
      {"result", resultLabel},
      {"rally_exchanges", m_rallyExchanges},
  };
  payload["agent_envelope"] = {
      {"command", "fel.tennis.rally"},
      {"result", resultLabel},
      {"winners", m_winners},
      {"player_games", m_playerGames},
      {"player_sets", m_playerSets},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

void TennisRallyMode::awardPoint(bool playerWon) {
  if (m_deuce) {
    if (playerWon) {
      if (m_playerHasAdv) {
        // Player wins game from advantage
        m_deuce = false;
        m_playerHasAdv = false;
        awardGame(true);
      } else {
        m_playerHasAdv = true; // player gains advantage
      }
    } else {
      if (m_playerHasAdv) {
        m_playerHasAdv = false; // back to deuce
      } else {
        // Opponent gains advantage → wins game
        m_deuce = false;
        awardGame(false);
      }
    }
    return;
  }

  if (playerWon) {
    ++m_gameScore.player;
  } else {
    ++m_gameScore.opponent;
  }

  // Check for deuce (both at 3 == 40-40)
  if (m_gameScore.player == 3 && m_gameScore.opponent == 3) {
    m_deuce = true;
    return;
  }

  // Check for game win (first to 4 points)
  if (m_gameScore.player >= 4 && m_gameScore.player > m_gameScore.opponent + 1) {
    m_gameScore = {};
    awardGame(true);
  } else if (m_gameScore.opponent >= 4 && m_gameScore.opponent > m_gameScore.player + 1) {
    m_gameScore = {};
    awardGame(false);
  }
}

void TennisRallyMode::awardGame(bool playerWon) {
  if (playerWon) {
    ++m_playerGames;
  } else {
    ++m_opponentGames;
  }

  // Check for set win
  if (m_playerGames >= kGamesToWinSet && m_playerGames > m_opponentGames + 1) {
    m_playerGames = 0;
    m_opponentGames = 0;
    awardSet(true);
  } else if (m_opponentGames >= kGamesToWinSet && m_opponentGames > m_playerGames + 1) {
    m_playerGames = 0;
    m_opponentGames = 0;
    awardSet(false);
  }
}

void TennisRallyMode::awardSet(bool playerWon) {
  if (playerWon) {
    ++m_playerSets;
  } else {
    ++m_opponentSets;
  }

  if (m_playerSets >= kSetsToWinMatch || m_opponentSets >= kSetsToWinMatch) {
    m_phase = TennisPhase::kMatchOver;
  }
}

auto TennisRallyMode::gameScoreLabel(int32_t pts) const -> std::string_view {
  switch (pts) {
    case 0: return "0";
    case 1: return "15";
    case 2: return "30";
    case 3: return "40";
    default: return "Adv";
  }
}

auto TennisRallyMode::opponentRallyError(float timing) const -> bool {
  // Opponent error rate increases with rally length; timing influences it slightly
  const float errorRate = 0.30F + static_cast<float>(m_rallyExchanges) * 0.04F + timing * 0.1F;
  // Pseudo-deterministic: use exchange count parity
  return errorRate > 0.60F && (m_rallyExchanges % 3 == 0);
}

auto TennisRallyMode::stateJson() const -> nlohmann::json {
  return {
      {"phase", static_cast<int>(m_phase)},
      {"player_sets", m_playerSets},
      {"opponent_sets", m_opponentSets},
      {"sets_to_win", kSetsToWinMatch},
      {"player_games", m_playerGames},
      {"opponent_games", m_opponentGames},
      {"games_to_win_set", kGamesToWinSet},
      {"game_score_player", std::string(gameScoreLabel(m_gameScore.player))},
      {"game_score_opponent", std::string(gameScoreLabel(m_gameScore.opponent))},
      {"deuce", m_deuce},
      {"player_advantage", m_playerHasAdv},
      {"aces", m_aces},
      {"winners", m_winners},
      {"rally_exchanges", m_rallyExchanges},
      {"match_over", isMatchOver()},
      {"victory", isVictory()},
      {"release_state", "validate_only"},
  };
}

} // namespace nexus::gameplay
