#include "nexus/gameplay/court_carnival_mode.h"

#include <algorithm>
#include <random>

namespace nexus::gameplay {

namespace {

constexpr float kTimingPerfectThreshold = 0.92F;
constexpr float kTimingGoodThreshold = 0.65F;

} // namespace

void CourtCarnivalMode::reset() {
  m_phase = CarnivalPhase::kLobby;
  m_activePad = CarnivalPad::kTrickShot;
  m_phaseTimer = 0.0F;
  m_playerScore = 0;
  m_opponentScore = 0;
  m_roundsWon = 0;
  m_diceRolls = 0;
  m_lastDiceValue = 0;
  m_hotPotatoThrows = 0;
  m_tokenPos = 0;
}

void CourtCarnivalMode::update(double deltaSeconds) {
  if (m_phase == CarnivalPhase::kMatchWon) {
    return;
  }

  m_phaseTimer += static_cast<float>(deltaSeconds);

  if (m_phase == CarnivalPhase::kActiveRound &&
      m_phaseTimer >= m_roundDurationSeconds) {
    // Time expired — opponent wins the round.
    m_opponentScore = std::min(m_opponentScore + 2, kWinScore);
    m_phase = CarnivalPhase::kRoundScored;
    m_phaseTimer = 0.0F;
  }

  if (m_phase == CarnivalPhase::kRoundScored && m_phaseTimer >= 0.5F) {
    m_phase = CarnivalPhase::kLobby;
    m_phaseTimer = 0.0F;
  }
}

auto CourtCarnivalMode::triggerPad(CarnivalPad pad, float timingNormalized)
    -> Result<nlohmann::json> {
  if (m_phase == CarnivalPhase::kMatchWon) {
    return Result<nlohmann::json>::err("carnival match already won");
  }

  const float timing = std::clamp(timingNormalized, 0.0F, 1.0F);
  beginRound(pad);
  const int points = scorePad(pad, timing);
  completeRound(points);

  nlohmann::json payload = stateJson();
  payload["pad_trigger"] = {
      {"pad", padLabel(pad)},
      {"timing", timing},
      {"points", points},
      {"grade", timing >= kTimingPerfectThreshold   ? "perfect"
                : timing >= kTimingGoodThreshold    ? "good"
                                                    : "miss"},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto CourtCarnivalMode::rollDice() -> Result<nlohmann::json> {
  if (m_phase == CarnivalPhase::kMatchWon) {
    return Result<nlohmann::json>::err("carnival match already won");
  }

  static thread_local std::mt19937 rng{std::random_device{}()};
  std::uniform_int_distribution<int> dist(1, 6);
  m_lastDiceValue = dist(rng);
  ++m_diceRolls;

  // Move token on the 3D board.
  const int prevPos = m_tokenPos;
  m_tokenPos = (m_tokenPos + m_lastDiceValue) % kBoardSpaceCount;

  const int bonus = m_lastDiceValue >= 5 ? 3 : m_lastDiceValue >= 3 ? 1 : 0;
  m_playerScore = std::min(m_playerScore + bonus, kWinScore);
  if (m_playerScore >= kWinScore) {
    m_phase = CarnivalPhase::kMatchWon;
  }

  // Resolve the space the token landed on.
  resolveSpaceLanding(m_tokenPos);

  const auto& space = kCarnivalBoard[static_cast<std::size_t>(m_tokenPos)];
  const auto  pos   = space.worldPos;

  nlohmann::json payload = stateJson();
  payload["dice"] = {
      {"value", m_lastDiceValue},
      {"bonus_points", bonus},
      {"rolls", m_diceRolls},
      {"from_space", prevPos},
      {"to_space", m_tokenPos},
      {"space_type", spaceTypeLabel(space.type)},
      {"token_world_pos", {{"x", pos.x}, {"y", pos.y}, {"z", pos.z}}},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

void CourtCarnivalMode::onThrowPulse(const ThrowPulseEnvelope& pulse) {
  if (m_phase != CarnivalPhase::kActiveRound ||
      m_activePad != CarnivalPad::kHotPotato) {
    return;
  }

  ++m_hotPotatoThrows;
  int bonus = 0;
  switch (pulse.catchFeedback) {
  case CatchFeedback::kPerfect:
    bonus = 4;
    break;
  case CatchFeedback::kSolid:
    bonus = 2;
    break;
  case CatchFeedback::kGraze:
    bonus = 1;
    break;
  case CatchFeedback::kMiss:
  default:
    bonus = 0;
    break;
  }

  if (bonus > 0) {
    completeRound(bonus);
  }
}

auto CourtCarnivalMode::padLabel(CarnivalPad pad) -> const char* {
  switch (pad) {
  case CarnivalPad::kTrickShot:
    return "trick_shot";
  case CarnivalPad::kHotPotato:
    return "hot_potato";
  case CarnivalPad::kRhythmBoard:
    return "rhythm_board";
  case CarnivalPad::kAtwLandmark:
    return "atw_landmark";
  }
  return "unknown";
}

auto CourtCarnivalMode::scorePad(CarnivalPad pad, float timingNormalized) -> int {
  const int base = timingNormalized >= kTimingPerfectThreshold   ? 5
                   : timingNormalized >= kTimingGoodThreshold    ? 3
                                                                 : 1;
  switch (pad) {
  case CarnivalPad::kTrickShot:
    return base + 1;
  case CarnivalPad::kHotPotato:
    return base;
  case CarnivalPad::kRhythmBoard:
    return base + 2;
  case CarnivalPad::kAtwLandmark:
    return base + 3;
  }
  return base;
}

void CourtCarnivalMode::beginRound(CarnivalPad pad) {
  m_activePad = pad;
  m_phase = CarnivalPhase::kActiveRound;
  m_phaseTimer = 0.0F;
  m_roundDurationSeconds = pad == CarnivalPad::kHotPotato ? 10.0F : 6.0F;
  m_hotPotatoThrows = 0;
}

void CourtCarnivalMode::completeRound(int points) {
  m_playerScore = std::min(m_playerScore + points, kWinScore);
  if (points >= 3) {
    ++m_roundsWon;
  } else {
    m_opponentScore = std::min(m_opponentScore + 1, kWinScore);
  }

  m_phase = CarnivalPhase::kRoundScored;
  m_phaseTimer = 0.0F;

  if (m_playerScore >= kWinScore || m_roundsWon >= kRoundsToWin) {
    m_phase = CarnivalPhase::kMatchWon;
  }
}

auto CourtCarnivalMode::stateJson() const -> nlohmann::json {
  const auto& space = kCarnivalBoard[static_cast<std::size_t>(m_tokenPos)];
  const auto  pos   = space.worldPos;
  return {
      {"phase", static_cast<int>(m_phase)},
      {"active_pad", padLabel(m_activePad)},
      {"player_score", m_playerScore},
      {"opponent_score", m_opponentScore},
      {"rounds_won", m_roundsWon},
      {"win_target", kWinScore},
      {"rounds_to_win", kRoundsToWin},
      {"dice_rolls", m_diceRolls},
      {"last_dice", m_lastDiceValue},
      {"hot_potato_throws", m_hotPotatoThrows},
      {"match_complete", isMatchComplete()},
      // Board game state
      {"token_position", m_tokenPos},
      {"space_type", spaceTypeLabel(space.type)},
      {"token_world_pos", {{"x", pos.x}, {"y", pos.y}, {"z", pos.z}}},
  };
}

// ── New board-game helpers ───────────────────────────────────────────────────

auto CourtCarnivalMode::spaceTypeLabel(CarnivalSpaceType t) -> const char* {
  switch (t) {
  case CarnivalSpaceType::kTrickShot:   return "trick_shot";
  case CarnivalSpaceType::kHotPotato:   return "hot_potato";
  case CarnivalSpaceType::kRhythmBoard: return "rhythm_board";
  case CarnivalSpaceType::kAtwLandmark: return "atw_landmark";
  case CarnivalSpaceType::kBonus:       return "bonus";
  case CarnivalSpaceType::kObstacle:    return "obstacle";
  }
  return "unknown";
}

auto CourtCarnivalMode::spaceTopad(CarnivalSpaceType t) -> CarnivalPad {
  switch (t) {
  case CarnivalSpaceType::kHotPotato:   return CarnivalPad::kHotPotato;
  case CarnivalSpaceType::kRhythmBoard: return CarnivalPad::kRhythmBoard;
  case CarnivalSpaceType::kAtwLandmark: return CarnivalPad::kAtwLandmark;
  default:                               return CarnivalPad::kTrickShot;
  }
}

void CourtCarnivalMode::resolveSpaceLanding(int spaceIndex) {
  const auto& space = kCarnivalBoard[static_cast<std::size_t>(spaceIndex)];
  switch (space.type) {
  case CarnivalSpaceType::kBonus:
    // Award bonus points immediately; no pad mini-game needed.
    m_playerScore = std::min(m_playerScore + space.bonusValue, kWinScore);
    if (m_playerScore >= kWinScore) {
      m_phase = CarnivalPhase::kMatchWon;
    }
    break;
  case CarnivalSpaceType::kObstacle:
    // Opponent gets a free point.
    m_opponentScore = std::min(m_opponentScore + 1, kWinScore);
    break;
  case CarnivalSpaceType::kTrickShot:
  case CarnivalSpaceType::kHotPotato:
  case CarnivalSpaceType::kRhythmBoard:
  case CarnivalSpaceType::kAtwLandmark:
    // Auto-begin the associated pad round so the player is prompted.
    beginRound(spaceTopad(space.type));
    break;
  }
}

} // namespace nexus::gameplay

