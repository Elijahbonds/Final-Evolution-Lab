// Headless score accumulator for production modes without dedicated ModeRuntime simulators.
#pragma once

#include "nexus/core/result.h"
#include "nexus/gameplay/gameplay_manager.h"

#include <nlohmann/json.hpp>
#include <cstdint>
#include <string>
#include <string_view>

namespace nexus::gameplay {

class OutcomeSportMode {
public:
  void reset(std::string_view modeId = {});
  void update(double deltaSeconds);

  auto pulse(const nlohmann::json& params) -> Result<nlohmann::json>;

  [[nodiscard]] auto stateJson() const -> nlohmann::json;
  [[nodiscard]] auto sessionScoreInput() const -> MatchScoreInput;
  [[nodiscard]] auto isMatchComplete() const -> bool;

private:
  [[nodiscard]] auto pointsForPulse(bool success, float timing) const -> int32_t;
  void applyOpponentPressure();
  void applyTennisGamePoint(bool playerWonPoint, bool ace);
  void advanceBaseballInning();

  std::string m_modeId;
  float m_playerScore{0.0F};
  float m_opponentScore{0.0F};
  int32_t m_playerMetric{0};
  int32_t m_opponentMetric{0};
  int32_t m_secondaryMetric{0};
  int32_t m_playerSets{0};
  int32_t m_opponentSets{0};
  float m_threshold{75.0F};
  int32_t m_pulses{0};
  int32_t m_streak{0};
  std::string m_lastAction;
  bool m_matchComplete{false};
};

} // namespace nexus::gameplay
