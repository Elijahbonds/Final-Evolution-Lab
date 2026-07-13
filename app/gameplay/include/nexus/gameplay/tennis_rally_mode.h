// Tennis Rally Ace — Tennis_Court serve+rally game/set/match simulator (tennis)
#pragma once

#include "nexus/core/result.h"

#include <nlohmann/json.hpp>
#include <cstdint>

namespace nexus::gameplay {

enum class TennisPhase : std::uint8_t {
  kServe = 0,
  kRally = 1,
  kMatchOver = 2,
};

enum class ServeResult : std::uint8_t {
  kAce = 0,
  kIn = 1,
  kFault = 2,
  kDoubleFault = 3,
};

enum class RallyResult : std::uint8_t {
  kWinner = 0,
  kRallyOn = 1,
  kError = 2,
};

// Game score within a set: 0=0, 1=15, 2=30, 3=40, 4=Adv
struct TennisGameScore {
  int32_t player{0};
  int32_t opponent{0};
};

class TennisRallyMode {
public:
  static constexpr int kGamesToWinSet = 4;
  static constexpr int kSetsToWinMatch = 2;

  void reset();
  void update(double deltaSeconds);

  // serve: power [0,1], placement [-1 wide … +1 body]
  auto serve(float power, float placement) -> Result<nlohmann::json>;
  // rally: timing [0,1], shot_type: "flat" | "topspin" | "slice" | "lob" | "drop"
  auto rally(float timing, std::string_view shotType) -> Result<nlohmann::json>;

  [[nodiscard]] auto playerSets() const -> int32_t { return m_playerSets; }
  [[nodiscard]] auto opponentSets() const -> int32_t { return m_opponentSets; }
  [[nodiscard]] auto playerGames() const -> int32_t { return m_playerGames; }
  [[nodiscard]] auto opponentGames() const -> int32_t { return m_opponentGames; }
  [[nodiscard]] auto phase() const -> TennisPhase { return m_phase; }
  [[nodiscard]] auto isMatchOver() const -> bool { return m_phase == TennisPhase::kMatchOver; }
  [[nodiscard]] auto isVictory() const -> bool {
    return m_phase == TennisPhase::kMatchOver && m_playerSets >= kSetsToWinMatch;
  }
  [[nodiscard]] auto stateJson() const -> nlohmann::json;

private:
  void awardPoint(bool playerWon);
  void awardGame(bool playerWon);
  void awardSet(bool playerWon);
  [[nodiscard]] auto gameScoreLabel(int32_t pts) const -> std::string_view;
  [[nodiscard]] auto opponentRallyError(float timing) const -> bool;

  TennisPhase m_phase{TennisPhase::kServe};
  int32_t m_playerSets{0};
  int32_t m_opponentSets{0};
  int32_t m_playerGames{0};
  int32_t m_opponentGames{0};
  TennisGameScore m_gameScore{};
  int32_t m_faultCount{0};   // consecutive faults on serve
  int32_t m_aces{0};
  int32_t m_winners{0};
  int32_t m_rallyExchanges{0};
  bool m_deuce{false};
  bool m_playerHasAdv{false};
};

} // namespace nexus::gameplay
