// Snowboarding — Mountain Slope carve/jump/butter simulator (snowboarding)
// Inspirator: SSX Tricky / Shaun White Snowboarding / 1080° Avalanche
// Additions: Tricky meter (SSX core) + uber trick, course gates, personal-best ghost.
#pragma once

#include "nexus/core/result.h"

#include <nlohmann/json.hpp>
#include <cstdint>

// GCC 13.3 workaround: forward-declare enum classes before large STL includes.
namespace nexus { namespace gameplay {
  enum class SnowPhase : std::uint8_t;
} } // namespace nexus::gameplay

namespace nexus::gameplay {

enum class SnowPhase : std::uint8_t {
  kRun         = 0,
  kUberTrick   = 1,  // brief cinematic pause when uber trick fires
  kRunComplete = 2,
};

class SnowboardingMode {
public:
  static constexpr int   kWinScore          = 50;
  static constexpr int   kMaxWipeouts       = 4;
  static constexpr int   kGateCount         = 5;      // gates per run
  static constexpr float kGateMissDeduction = 10.0F;  // points lost per missed gate
  // Tricky meter thresholds.
  static constexpr float kTrickyMeterMax    = 100.0F;
  static constexpr float kUberThreshold     = 100.0F; // meter must be full to fire uber
  static constexpr float kUberScoreMultiplier = 10.0F;
  static constexpr float kUberAnimDuration    = 1.2F;  // seconds of cinematic pause

  void reset();
  void update(double deltaSeconds);

  auto carve(float timing, float lineDifficulty)          -> Result<nlohmann::json>;
  auto jump(float airDifficulty, int32_t comboMultiplier) -> Result<nlohmann::json>;
  auto butter(float style)                                -> Result<nlohmann::json>;
  /// Grab during a jump — adds style multiplier and flow bonus.
  /// grabName: "indy", "melon", "stalefish", "mute", "tail", "nose".
  auto grab(std::string_view grabName, float timing)      -> Result<nlohmann::json>;
  auto wipeout()                                          -> Result<nlohmann::json>;

  /// Fire the uber trick when trickyMeter >= kUberThreshold.
  /// Triggers kUberTrick phase for kUberAnimDuration seconds, then applies
  /// kUberScoreMultiplier to the current line score.
  auto uberTrick()                                        -> Result<nlohmann::json>;

  /// Player passes through a course gate (must be called for each of kGateCount gates).
  auto passGate()  -> Result<nlohmann::json>;
  /// Player misses a gate — deducts kGateMissDeduction points.
  auto missGate()  -> Result<nlohmann::json>;

  [[nodiscard]] auto lineScore()      const -> int32_t { return static_cast<int32_t>(m_lineScore); }
  [[nodiscard]] auto trickyMeter()    const -> float   { return m_trickyMeter; }
  [[nodiscard]] auto isUberReady()    const -> bool    { return m_trickyMeter >= kUberThreshold; }
  [[nodiscard]] auto gatesPassed()    const -> int32_t { return m_gatesPassed; }
  [[nodiscard]] auto gatesMissed()    const -> int32_t { return m_gatesMissed; }
  [[nodiscard]] auto ghostBestScore() const -> int32_t { return m_ghostBestScore; }
  [[nodiscard]] auto isRunComplete()  const -> bool {
    return m_phase == SnowPhase::kRunComplete;
  }
  [[nodiscard]] auto stateJson() const -> nlohmann::json;

private:
  void checkRunEnd();

  SnowPhase m_phase{SnowPhase::kRun};
  float   m_lineScore{0.0F};
  float   m_flowMeter{0.0F};
  float   m_trickyMeter{0.0F};   // SSX Tricky meter — fills with tricks, empties on wipeout
  float   m_uberTimer{0.0F};     // counts down during kUberTrick phase
  int32_t m_comboMultiplier{1};
  int32_t m_carvesLanded{0};
  int32_t m_jumpsLanded{0};
  int32_t m_butterMoves{0};
  int32_t m_grabs{0};
  int32_t m_wipeouts{0};
  int32_t m_peakCombo{1};
  // Gate tracking.
  int32_t m_gatesPassed{0};
  int32_t m_gatesMissed{0};
  // Personal-best ghost (persists across resets via static to simulate across runs).
  int32_t m_ghostBestScore{0};
};

} // namespace nexus::gameplay
