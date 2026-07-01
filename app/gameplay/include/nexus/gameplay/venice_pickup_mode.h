// Venice Beach pickup H2H — throw-catch scoring proxy for basketball_h2h
#pragma once

#include "nexus/core/result.h"
#include "nexus/gameplay/throw_catch_physics.h"

#include <nlohmann/json.hpp>
#include <cstdint>
#include <string_view>
#include <vector>

namespace nexus::gameplay {

struct PickupPassEvent {
  CatchFeedback feedback{CatchFeedback::kMiss};
  float impulseY{0.0F};
  int pointsAwarded{0};
};

class VenicePickupMode {
public:
  static constexpr int kWinScore = 21;

  void reset();
  void update(double deltaSeconds);

  /// UI-driven pickup action (Shoot / Drive / Crossover) — distinct from generic tap score.
  auto onAction(std::string_view action, float timingNormalized, bool success)
      -> Result<nlohmann::json>;

  /// Called each frame when throw-catch completes a throw pulse.
  void onThrowPulse(const ThrowPulseEnvelope& pulse);

  [[nodiscard]] auto playerScore() const -> int { return m_playerScore; }
  [[nodiscard]] auto opponentScore() const -> int { return m_opponentScore; }
  [[nodiscard]] auto passesCompleted() const -> std::uint32_t { return m_passesCompleted; }
  [[nodiscard]] auto perfectCatches() const -> std::uint32_t { return m_perfectCatches; }
  [[nodiscard]] auto isMatchComplete() const -> bool { return m_matchComplete; }
  [[nodiscard]] auto stateJson() const -> nlohmann::json;
  [[nodiscard]] auto passHistory() const -> const std::vector<PickupPassEvent>& {
    return m_passHistory;
  }

private:
  [[nodiscard]] static auto pointsForFeedback(CatchFeedback feedback) -> int;

  int m_playerScore{0};
  int m_opponentScore{0};
  std::uint32_t m_passesCompleted{0};
  std::uint32_t m_perfectCatches{0};
  bool m_matchComplete{false};
  std::uint64_t m_lastProcessedThrow{0};
  std::vector<PickupPassEvent> m_passHistory;
};

} // namespace nexus::gameplay
