#include "nexus/gameplay/court_carnival_mode.h"

#include <algorithm>
#include <random>

namespace nexus::gameplay {

namespace {

constexpr float kTimingPerfectThreshold = 0.92F;
constexpr float kTimingGoodThreshold = 0.65F;

} // namespace

void CourtCarnivalMode::reset() {
  m_phase                  = CarnivalPhase::kLobby;
  m_activePad              = CarnivalPad::kTrickShot;
  m_playerCard             = CarnivalItemCard::kNone;
  m_phaseTimer             = 0.0F;
  m_playerScore            = 0;
  m_opponentScore          = 0;
  m_playerStars            = 0;
  m_opponentStars          = 0;
  m_roundsWon              = 0;
  m_diceRolls              = 0;
  m_lastDiceValue          = 0;
  m_hotPotatoThrows        = 0;
  m_tokenPos               = 0;
  m_roundCount             = 0;
  m_accumulatedDicePoints  = 0;
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
    m_phase         = CarnivalPhase::kRoundScored;
    m_phaseTimer    = 0.0F;
  }

  if (m_phase == CarnivalPhase::kRoundScored && m_phaseTimer >= 0.5F) {
    m_phase      = CarnivalPhase::kLobby;
    m_phaseTimer = 0.0F;
  }

  if (m_phase == CarnivalPhase::kChaosEvent && m_phaseTimer >= 1.5F) {
    m_phase      = CarnivalPhase::kLobby;
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
      {"pad",    padLabel(pad)},
      {"timing", timing},
      {"points", points},
      {"grade",  timing >= kTimingPerfectThreshold   ? "perfect"
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

  // Boost card: roll twice and take the better result.
  int roll1 = dist(rng);
  int roll2 = (m_playerCard == CarnivalItemCard::kBoost) ? dist(rng) : roll1;
  m_lastDiceValue = std::max(roll1, roll2);
  if (m_playerCard == CarnivalItemCard::kBoost) {
    m_playerCard = CarnivalItemCard::kNone;  // consume card
  }

  ++m_diceRolls;
  m_accumulatedDicePoints += m_lastDiceValue;

  // Move token on the 3D board.
  const int prevPos = m_tokenPos;
  m_tokenPos        = (m_tokenPos + m_lastDiceValue) % kBoardSpaceCount;

  const int bonus = m_lastDiceValue >= 5 ? 3 : m_lastDiceValue >= 3 ? 1 : 0;
  m_playerScore   = std::min(m_playerScore + bonus, kWinScore);
  if (m_playerScore >= kWinScore || m_playerStars >= kStarsToWin) {
    m_phase = CarnivalPhase::kMatchWon;
  }

  // Resolve the space the token landed on.
  if (m_phase != CarnivalPhase::kMatchWon) {
    resolveSpaceLanding(m_tokenPos);
  }

  // Award an item card after every other roll.
  if (m_diceRolls % 2 == 0 && m_playerCard == CarnivalItemCard::kNone) {
    distributeItemCard();
  }

  const auto& space = kCarnivalBoard[static_cast<std::size_t>(m_tokenPos)];
  const auto  pos   = space.worldPos;

  nlohmann::json payload = stateJson();
  payload["dice"] = {
      {"value",         m_lastDiceValue},
      {"bonus_points",  bonus},
      {"rolls",         m_diceRolls},
      {"from_space",    prevPos},
      {"to_space",      m_tokenPos},
      {"space_type",    spaceTypeLabel(space.type)},
      {"token_world_pos", {{"x", pos.x}, {"y", pos.y}, {"z", pos.z}}},
      {"item_card",     cardLabel(m_playerCard)},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto CourtCarnivalMode::purchaseStar() -> Result<nlohmann::json> {
  if (m_phase == CarnivalPhase::kMatchWon) {
    return Result<nlohmann::json>::err("carnival match already won");
  }

  const auto& space = kCarnivalBoard[static_cast<std::size_t>(m_tokenPos)];
  if (space.type != CarnivalSpaceType::kAtwLandmark) {
    return Result<nlohmann::json>::err("must be on an ATW landmark space to purchase a star");
  }

  if (m_accumulatedDicePoints < kStarCost) {
    nlohmann::json payload = stateJson();
    payload["star_purchase"] = {{"success", false}, {"dice_points", m_accumulatedDicePoints},
                                {"cost", kStarCost}};
    return Result<nlohmann::json>::ok(std::move(payload));
  }

  m_accumulatedDicePoints -= kStarCost;
  ++m_playerStars;

  if (m_playerStars >= kStarsToWin) {
    m_phase = CarnivalPhase::kMatchWon;
  }

  nlohmann::json payload = stateJson();
  payload["star_purchase"] = {
      {"success",      true},
      {"player_stars", m_playerStars},
      {"stars_to_win", kStarsToWin},
      {"remaining_dice_points", m_accumulatedDicePoints},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto CourtCarnivalMode::playItemCard(CarnivalItemCard card) -> Result<nlohmann::json> {
  if (m_phase == CarnivalPhase::kMatchWon) {
    return Result<nlohmann::json>::err("carnival match already won");
  }
  if (m_playerCard == CarnivalItemCard::kNone) {
    return Result<nlohmann::json>::err("no item card held");
  }

  std::string effect;
  switch (card) {
  case CarnivalItemCard::kSteal:
    // Take kItemStealAmount points from the opponent.
    {
      const int stolen  = std::min(m_opponentScore, kItemStealAmount);
      m_opponentScore  -= stolen;
      m_playerScore     = std::min(m_playerScore + stolen, kWinScore);
      effect = "stolen_" + std::to_string(stolen) + "_points";
    }
    m_playerCard = CarnivalItemCard::kNone;
    break;
  case CarnivalItemCard::kWarp:
    // Teleport to the first ATW landmark space on the board.
    for (int i = 0; i < kBoardSpaceCount; ++i) {
      if (kCarnivalBoard[static_cast<std::size_t>(i)].type ==
          CarnivalSpaceType::kAtwLandmark) {
        m_tokenPos = i;
        break;
      }
    }
    effect       = "warped_to_atw_space_" + std::to_string(m_tokenPos);
    m_playerCard = CarnivalItemCard::kNone;
    resolveSpaceLanding(m_tokenPos);
    break;
  case CarnivalItemCard::kBoost:
    // Boost is consumed on the next rollDice call.
    effect = "boost_queued";
    break;
  case CarnivalItemCard::kNone:
    break;
  }

  if (m_playerScore >= kWinScore || m_playerStars >= kStarsToWin) {
    m_phase = CarnivalPhase::kMatchWon;
  }

  nlohmann::json payload = stateJson();
  payload["item_card_played"] = {
      {"card",   cardLabel(card)},
      {"effect", effect},
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
  case CatchFeedback::kPerfect: bonus = 4; break;
  case CatchFeedback::kSolid:   bonus = 2; break;
  case CatchFeedback::kGraze:   bonus = 1; break;
  case CatchFeedback::kMiss:
  default:                      bonus = 0; break;
  }

  if (bonus > 0) {
    completeRound(bonus);
  }
}

// ── Static label helpers ─────────────────────────────────────────────────────

auto CourtCarnivalMode::padLabel(CarnivalPad pad) -> const char* {
  switch (pad) {
  case CarnivalPad::kTrickShot:     return "trick_shot";
  case CarnivalPad::kHotPotato:     return "hot_potato";
  case CarnivalPad::kRhythmBoard:   return "rhythm_board";
  case CarnivalPad::kAtwLandmark:   return "atw_landmark";
  case CarnivalPad::kShootingDrill: return "shooting_drill";
  case CarnivalPad::kSpeedDribble:  return "speed_dribble";
  }
  return "unknown";
}

auto CourtCarnivalMode::cardLabel(CarnivalItemCard c) -> const char* {
  switch (c) {
  case CarnivalItemCard::kNone:  return "none";
  case CarnivalItemCard::kBoost: return "boost";
  case CarnivalItemCard::kSteal: return "steal";
  case CarnivalItemCard::kWarp:  return "warp";
  }
  return "none";
}

auto CourtCarnivalMode::scorePad(CarnivalPad pad, float timingNormalized) -> int {
  const int base = timingNormalized >= kTimingPerfectThreshold   ? 5
                   : timingNormalized >= kTimingGoodThreshold    ? 3
                                                                 : 1;
  switch (pad) {
  case CarnivalPad::kTrickShot:     return base + 1;
  case CarnivalPad::kHotPotato:     return base;
  case CarnivalPad::kRhythmBoard:   return base + 2;
  case CarnivalPad::kAtwLandmark:   return base + 3;
  case CarnivalPad::kShootingDrill: return base + 2;  // 3-pt shooting: high ceiling
  case CarnivalPad::kSpeedDribble:  return base + 1;  // speed dribble: moderate reward
  }
  return base;
}

void CourtCarnivalMode::beginRound(CarnivalPad pad) {
  m_activePad  = pad;
  m_phase      = CarnivalPhase::kActiveRound;
  m_phaseTimer = 0.0F;
  // Shooting drill and speed dribble get 8s; hot-potato 10s; others 6s.
  m_roundDurationSeconds =
      pad == CarnivalPad::kHotPotato                              ? 10.0F
      : (pad == CarnivalPad::kShootingDrill ||
         pad == CarnivalPad::kSpeedDribble)                       ?  8.0F
                                                                  :  6.0F;
  m_hotPotatoThrows = 0;
}

void CourtCarnivalMode::completeRound(int points) {
  ++m_roundCount;
  m_playerScore = std::min(m_playerScore + points, kWinScore);
  if (points >= 3) {
    ++m_roundsWon;
  } else {
    m_opponentScore = std::min(m_opponentScore + 1, kWinScore);
    // Opponent also slowly accumulates stars.
    if (m_roundCount % 3 == 0) {
      ++m_opponentStars;
    }
  }

  m_phase      = CarnivalPhase::kRoundScored;
  m_phaseTimer = 0.0F;

  if (m_playerScore >= kWinScore || m_roundsWon >= kRoundsToWin ||
      m_playerStars >= kStarsToWin) {
    m_phase = CarnivalPhase::kMatchWon;
    return;
  }

  // Chaos event every kChaosRoundInterval rounds.
  if (m_roundCount % kChaosRoundInterval == 0) {
    triggerChaosEvent();
  }
}

void CourtCarnivalMode::triggerChaosEvent() {
  // Chaos: both scores shift by a small random ±3 amount (simulated deterministically
  // via round count to keep validate-only tests reproducible).
  const int delta = (m_roundCount % 7) - 3;  // deterministic −3..+3
  m_playerScore   = std::clamp(m_playerScore   + delta, 0, kWinScore);
  m_opponentScore = std::clamp(m_opponentScore - delta, 0, kWinScore);
  m_phase         = CarnivalPhase::kChaosEvent;
  m_phaseTimer    = 0.0F;
}

void CourtCarnivalMode::distributeItemCard() {
  // Cycle through cards deterministically (Boost → Steal → Warp → repeat).
  const int cardIdx = (m_diceRolls / 2) % 3;
  m_playerCard = cardIdx == 0 ? CarnivalItemCard::kBoost
                 : cardIdx == 1 ? CarnivalItemCard::kSteal
                                : CarnivalItemCard::kWarp;
}

// ── New board-game helpers ───────────────────────────────────────────────────

auto CourtCarnivalMode::spaceTypeLabel(CarnivalSpaceType t) -> const char* {
  switch (t) {
  case CarnivalSpaceType::kTrickShot:     return "trick_shot";
  case CarnivalSpaceType::kHotPotato:     return "hot_potato";
  case CarnivalSpaceType::kRhythmBoard:   return "rhythm_board";
  case CarnivalSpaceType::kAtwLandmark:   return "atw_landmark";
  case CarnivalSpaceType::kBonus:         return "bonus";
  case CarnivalSpaceType::kObstacle:      return "obstacle";
  case CarnivalSpaceType::kShootingDrill: return "shooting_drill";
  case CarnivalSpaceType::kSpeedDribble:  return "speed_dribble";
  }
  return "unknown";
}

auto CourtCarnivalMode::spaceTopad(CarnivalSpaceType t) -> CarnivalPad {
  switch (t) {
  case CarnivalSpaceType::kHotPotato:     return CarnivalPad::kHotPotato;
  case CarnivalSpaceType::kRhythmBoard:   return CarnivalPad::kRhythmBoard;
  case CarnivalSpaceType::kAtwLandmark:   return CarnivalPad::kAtwLandmark;
  case CarnivalSpaceType::kShootingDrill: return CarnivalPad::kShootingDrill;
  case CarnivalSpaceType::kSpeedDribble:  return CarnivalPad::kSpeedDribble;
  default:                                return CarnivalPad::kTrickShot;
  }
}

void CourtCarnivalMode::resolveSpaceLanding(int spaceIndex) {
  const auto& space = kCarnivalBoard[static_cast<std::size_t>(spaceIndex)];
  switch (space.type) {
  case CarnivalSpaceType::kBonus:
    m_playerScore = std::min(m_playerScore + space.bonusValue, kWinScore);
    if (m_playerScore >= kWinScore) {
      m_phase = CarnivalPhase::kMatchWon;
    }
    break;
  case CarnivalSpaceType::kObstacle:
    m_opponentScore = std::min(m_opponentScore + 1, kWinScore);
    break;
  case CarnivalSpaceType::kAtwLandmark:
    // ATW landmark: auto-begin the pad AND allow purchaseStar() call.
    beginRound(CarnivalPad::kAtwLandmark);
    break;
  case CarnivalSpaceType::kTrickShot:
  case CarnivalSpaceType::kHotPotato:
  case CarnivalSpaceType::kRhythmBoard:
  case CarnivalSpaceType::kShootingDrill:
  case CarnivalSpaceType::kSpeedDribble:
    beginRound(spaceTopad(space.type));
    break;
  }
}

auto CourtCarnivalMode::stateJson() const -> nlohmann::json {
  const auto& space = kCarnivalBoard[static_cast<std::size_t>(m_tokenPos)];
  const auto  pos   = space.worldPos;

  const char* phaseStr =
      m_phase == CarnivalPhase::kLobby       ? "lobby"
      : m_phase == CarnivalPhase::kActiveRound ? "active_round"
      : m_phase == CarnivalPhase::kRoundScored ? "round_scored"
      : m_phase == CarnivalPhase::kChaosEvent  ? "chaos_event"
                                               : "match_won";

  return {
      {"phase",               phaseStr},
      {"active_pad",          padLabel(m_activePad)},
      {"player_score",        m_playerScore},
      {"opponent_score",      m_opponentScore},
      {"player_stars",        m_playerStars},
      {"opponent_stars",      m_opponentStars},
      {"stars_to_win",        kStarsToWin},
      {"rounds_won",          m_roundsWon},
      {"win_target",          kWinScore},
      {"rounds_to_win",       kRoundsToWin},
      {"dice_rolls",          m_diceRolls},
      {"last_dice",           m_lastDiceValue},
      {"round_count",         m_roundCount},
      {"accumulated_dice_pts",m_accumulatedDicePoints},
      {"star_cost",           kStarCost},
      {"hot_potato_throws",   m_hotPotatoThrows},
      {"player_item_card",    cardLabel(m_playerCard)},
      {"match_complete",      isMatchComplete()},
      // Board game state.
      {"token_position",      m_tokenPos},
      {"space_type",          spaceTypeLabel(space.type)},
      {"token_world_pos",     {{"x", pos.x}, {"y", pos.y}, {"z", pos.z}}},
  };
}

} // namespace nexus::gameplay

