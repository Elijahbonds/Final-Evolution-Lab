// Volleyball Rally — Sand_Court rally-scoring beach volleyball simulator (volleyball)
#include "nexus/gameplay/volleyball_rally_mode.h"

#include <algorithm>
#include <cmath>

namespace nexus::gameplay {

namespace {

constexpr float kAcePowerThreshold = 0.85F;
constexpr float kAcePlacementEdge = 0.75F;  // near the line = ace candidate
constexpr float kSpikeKillTimingMin = 0.88F;
constexpr float kSpikeKillPowerMin = 0.75F;
constexpr float kQuickSetTimingBoost = 0.10F; // harder to defend

} // namespace

void VolleyballRallyMode::reset() {
  m_phase = VolleyballPhase::kServe;
  m_playerServing = true;
  m_playerPoints = 0;
  m_opponentPoints = 0;
  m_playerSets = 0;
  m_opponentSets = 0;
  m_totalRallies = 0;
  m_aces = 0;
  m_kills = 0;
  m_blocks = 0;
  m_digStreak = 0;
  m_setReady = false;
  m_pendingSet = SetType::kHigh;
}

void VolleyballRallyMode::update(double /*deltaSeconds*/) {
  // Event-driven; no tick-based transitions
}

auto VolleyballRallyMode::serve(float power, float placement) -> Result<nlohmann::json> {
  if (m_phase == VolleyballPhase::kMatchOver) {
    return Result<nlohmann::json>::err("match already over");
  }
  if (m_phase != VolleyballPhase::kServe) {
    return Result<nlohmann::json>::err("not in serve phase");
  }

  const float p = std::clamp(power, 0.0F, 1.0F);
  const float pl = std::clamp(placement, -1.0F, 1.0F);
  ++m_totalRallies;

  const bool edgePlacement = std::abs(pl) >= kAcePlacementEdge;
  const bool hardServe = p >= kAcePowerThreshold;

  if (!opponentReturnServe(p, pl)) {
    // Ace or service error opponent can't handle
    if (hardServe && edgePlacement) {
      ++m_aces;
      awardPoint(true);  // player wins point
    } else {
      // Service error — opponent gets point
      awardPoint(false);
    }
    m_setReady = false;
    nlohmann::json payload = stateJson();
    payload["serve"] = {
        {"power", p}, {"placement", pl},
        {"result", hardServe && edgePlacement ? "ace" : "service_error"},
    };
    payload["agent_envelope"] = {
        {"command", "fel.volleyball.serve"},
        {"aces", m_aces},
    };
    return Result<nlohmann::json>::ok(std::move(payload));
  }

  // Opponent returned — rally continues
  m_phase = VolleyballPhase::kRally;
  m_setReady = false;
  m_digStreak = 0;

  nlohmann::json payload = stateJson();
  payload["serve"] = {
      {"power", p},
      {"placement", pl},
      {"result", "in_play"},
  };
  payload["agent_envelope"] = {{"command", "fel.volleyball.serve"}, {"result", "in_play"}};
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto VolleyballRallyMode::set_(float accuracy, std::string_view setType) -> Result<nlohmann::json> {
  if (m_phase == VolleyballPhase::kMatchOver) {
    return Result<nlohmann::json>::err("match already over");
  }
  if (m_phase != VolleyballPhase::kRally) {
    return Result<nlohmann::json>::err("not in rally phase — serve first");
  }

  const float acc = std::clamp(accuracy, 0.0F, 1.0F);
  if (setType == "quick") {
    m_pendingSet = SetType::kQuick;
  } else if (setType == "back") {
    m_pendingSet = SetType::kBack;
  } else {
    m_pendingSet = SetType::kHigh;
  }

  m_setReady = (acc >= 0.50F);

  nlohmann::json payload = stateJson();
  payload["set"] = {
      {"accuracy", acc},
      {"set_type", std::string(setType)},
      {"set_ready", m_setReady},
  };
  payload["agent_envelope"] = {
      {"command", "fel.volleyball.set"},
      {"set_type", std::string(setType)},
      {"set_ready", m_setReady},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto VolleyballRallyMode::spike(float timing, float power, std::string_view angle)
    -> Result<nlohmann::json> {
  if (m_phase == VolleyballPhase::kMatchOver) {
    return Result<nlohmann::json>::err("match already over");
  }
  if (m_phase != VolleyballPhase::kRally) {
    return Result<nlohmann::json>::err("not in rally phase");
  }

  const float t = std::clamp(timing, 0.0F, 1.0F);
  const float p = std::clamp(power, 0.0F, 1.0F);

  // Quick set makes spikes harder to defend
  float effectiveTiming = t;
  if (m_pendingSet == SetType::kQuick && m_setReady) {
    effectiveTiming = std::min(1.0F, t + kQuickSetTimingBoost);
  }

  const bool kill = effectiveTiming >= kSpikeKillTimingMin && p >= kSpikeKillPowerMin;
  const bool defended = opponentDefendsSpike(effectiveTiming, angle);

  ++m_digStreak;

  if (kill && !defended) {
    ++m_kills;
    awardPoint(true);
    m_setReady = false;
    nlohmann::json payload = stateJson();
    payload["spike"] = {{"timing", t}, {"power", p}, {"angle", std::string(angle)}, {"result", "kill"}};
    payload["agent_envelope"] = {{"command", "fel.volleyball.spike"}, {"result", "kill"}, {"kills", m_kills}};
    return Result<nlohmann::json>::ok(std::move(payload));
  }

  if (defended) {
    // Opponent digs it — continue rally (opponent earns a point back chance)
    ++m_blocks;
    if (m_digStreak >= 3) {
      // Long rally — opponent scores on dig sequence
      awardPoint(false);
      m_setReady = false;
      nlohmann::json payload = stateJson();
      payload["spike"] = {{"timing", t}, {"power", p}, {"angle", std::string(angle)}, {"result", "dug_long_rally"}};
      payload["agent_envelope"] = {{"command", "fel.volleyball.spike"}, {"result", "dug_long_rally"}};
      return Result<nlohmann::json>::ok(std::move(payload));
    }
    // Short dig — rally resets to serve phase for next serve
    m_phase = VolleyballPhase::kServe;
    m_setReady = false;
    m_digStreak = 0;
    nlohmann::json payload = stateJson();
    payload["spike"] = {{"timing", t}, {"power", p}, {"angle", std::string(angle)}, {"result", "dug_sideout"}};
    payload["agent_envelope"] = {{"command", "fel.volleyball.spike"}, {"result", "dug_sideout"}};
    return Result<nlohmann::json>::ok(std::move(payload));
  }

  // Attack error — out of bounds or into the net
  awardPoint(false);
  m_setReady = false;
  nlohmann::json payload = stateJson();
  payload["spike"] = {{"timing", t}, {"power", p}, {"angle", std::string(angle)}, {"result", "attack_error"}};
  payload["agent_envelope"] = {{"command", "fel.volleyball.spike"}, {"result", "attack_error"}};
  return Result<nlohmann::json>::ok(std::move(payload));
}

void VolleyballRallyMode::awardPoint(bool playerWon) {
  if (playerWon) {
    ++m_playerPoints;
  } else {
    ++m_opponentPoints;
  }
  // Always return to serve phase after a rally ends
  m_phase = VolleyballPhase::kServe;
  m_playerServing = playerWon; // winner serves next (rally scoring)
  m_digStreak = 0;
  checkSetEnd();
}

void VolleyballRallyMode::checkSetEnd() {
  const int32_t lead = m_playerPoints - m_opponentPoints;
  const int32_t oppLead = m_opponentPoints - m_playerPoints;

  const bool playerWinsSet = m_playerPoints >= kPointsToWinSet && lead >= 2;
  const bool opponentWinsSet = m_opponentPoints >= kPointsToWinSet && oppLead >= 2;

  if (playerWinsSet || opponentWinsSet) {
    if (playerWinsSet) {
      ++m_playerSets;
    } else {
      ++m_opponentSets;
    }
    m_playerPoints = 0;
    m_opponentPoints = 0;
    m_playerServing = true;
    m_digStreak = 0;
    m_setReady = false;

    if (m_playerSets >= kSetsToWinMatch || m_opponentSets >= kSetsToWinMatch) {
      m_phase = VolleyballPhase::kMatchOver;
    } else {
      m_phase = VolleyballPhase::kServe;
    }
  }
}

auto VolleyballRallyMode::opponentReturnServe(float power, float placement) const -> bool {
  // Hard edge serves with high power are aces; otherwise opponent returns
  const bool edgePlacement = std::abs(placement) >= kAcePlacementEdge;
  const bool hardServe = power >= kAcePowerThreshold;
  return !(hardServe && edgePlacement);
}

auto VolleyballRallyMode::opponentDefendsSpike(float timing, std::string_view angle) const -> bool {
  // Tip shots are easier to defend; line shots at high timing are kills
  if (angle == "tip") {
    return true; // opponent always digs tips
  }
  if (angle == "line" && timing >= kSpikeKillTimingMin) {
    return false; // line kill at high timing = unreachable
  }
  // Cross-court: 40% chance opponent digs based on dig streak
  return m_digStreak % 3 == 0;
}

auto VolleyballRallyMode::stateJson() const -> nlohmann::json {
  return {
      {"phase", static_cast<int>(m_phase)},
      {"player_serving", m_playerServing},
      {"player_points", m_playerPoints},
      {"opponent_points", m_opponentPoints},
      {"player_sets", m_playerSets},
      {"opponent_sets", m_opponentSets},
      {"win_target_points", kPointsToWinSet},
      {"sets_to_win", kSetsToWinMatch},
      {"total_rallies", m_totalRallies},
      {"aces", m_aces},
      {"kills", m_kills},
      {"blocks", m_blocks},
      {"dig_streak", m_digStreak},
      {"set_ready", m_setReady},
      {"match_over", isMatchOver()},
      {"victory", isVictory()},
      {"release_state", "validate_only"},
  };
}

} // namespace nexus::gameplay
