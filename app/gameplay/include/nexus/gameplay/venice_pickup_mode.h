// Venice Beach pickup H2H — throw-catch scoring proxy for basketball_h2h
// Inspirator: NBA Jam / Venice Beach pickup culture
// Additions: HotStreak (3+ consecutive makes → on_fire bonus),
//            differentiated shot events (Shoot / Drive / Alley-Oop / Bank Shot).
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

  // HotStreak thresholds (NBA Jam "on fire" mechanic).
  static constexpr int   kHotStreakThreshold = 3;   // consecutive makes to ignite
  static constexpr float kOnFireMultiplier   = 1.5F; // points multiplier while on fire
  static constexpr int   kAlleyOopBonus      = 2;    // extra points on alley-oop
  static constexpr int   kBankShotBonus      = 1;    // extra point on bank shot

  void reset();
  void update(double deltaSeconds);

  /// UI-driven pickup action. Recognised action labels:
  ///   "shoot"      — standard jumper
  ///   "drive"      — layup drive (slightly easier perfect threshold)
  ///   "crossover"  — crossover dribble (breaks defender, bonus on solid+)
  ///   "alley_oop"  — high-arc lob (kAlleyOopBonus on perfect timing)
  ///   "bank_shot"  — off-glass (kBankShotBonus + crowd cheer event)
  auto onAction(std::string_view action, float timingNormalized, bool success)
      -> Result<nlohmann::json>;

  /// Called each frame when throw-catch completes a throw pulse.
  void onThrowPulse(const ThrowPulseEnvelope& pulse);

  [[nodiscard]] auto playerScore()       const -> int           { return m_playerScore; }
  [[nodiscard]] auto opponentScore()     const -> int           { return m_opponentScore; }
  [[nodiscard]] auto passesCompleted()   const -> std::uint32_t { return m_passesCompleted; }
  [[nodiscard]] auto perfectCatches()    const -> std::uint32_t { return m_perfectCatches; }
  [[nodiscard]] auto hotStreak()         const -> int           { return m_hotStreak; }
  [[nodiscard]] auto isOnFire()          const -> bool          { return m_onFire; }
  [[nodiscard]] auto isMatchComplete()   const -> bool          { return m_matchComplete; }
  [[nodiscard]] auto stateJson()         const -> nlohmann::json;
  [[nodiscard]] auto passHistory()       const -> const std::vector<PickupPassEvent>& {
    return m_passHistory;
  }

private:
  [[nodiscard]] static auto pointsForFeedback(CatchFeedback feedback) -> int;
  void recordMake();
  void recordMiss();

  int m_playerScore{0};
  int m_opponentScore{0};
  std::uint32_t m_passesCompleted{0};
  std::uint32_t m_perfectCatches{0};
  bool m_matchComplete{false};
  std::uint64_t m_lastProcessedThrow{0};
  std::vector<PickupPassEvent> m_passHistory;

  // HotStreak / on-fire state.
  int  m_hotStreak{0};   // consecutive scoring plays
  bool m_onFire{false};  // true when hotStreak >= kHotStreakThreshold
};

} // namespace nexus::gameplay
