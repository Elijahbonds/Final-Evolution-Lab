// Skateboarding — Skate Park line/trick/combo simulator (skateboarding)
// Inspirator: Tony Hawk's Pro Skater
// Additions: 2-minute timed run (THPS spec), manual balance mechanic,
//            special tricks unlock after 10 landed tricks.
#pragma once

#include "nexus/core/result.h"

#include <nlohmann/json.hpp>
#include <cstdint>
#include <string>
#include <string_view>

// GCC 13.3 workaround: forward-declare enum classes before large STL includes.
namespace nexus { namespace gameplay {
  enum class SkatePhase : std::uint8_t;
} } // namespace nexus::gameplay

namespace nexus::gameplay {

enum class SkatePhase : std::uint8_t {
  kRun         = 0,
  kRunComplete = 1,
};

class SkateboardingMode {
public:
  // THPS-style 2-minute timed run; score at buzzer is submitted.
  static constexpr float   kRunDurationSeconds   = 120.0F;
  static constexpr int     kWinScore             = 50;   // retained as legacy threshold
  static constexpr int     kMaxBails             = 5;
  // Special tricks unlock after this many landed tricks without bail.
  static constexpr int32_t kSpecialsUnlockThreshold = 10;
  // Manual balance oscillates within this tolerance window (0–1 normalised).
  static constexpr float   kManualTolerance         = 0.30F;
  static constexpr float   kManualMaxDuration        = 8.0F;  // seconds

  void reset();
  void update(double deltaSeconds);

  auto landTrick(float difficulty, int32_t comboMultiplier) -> Result<nlohmann::json>;
  /// Named trick variant — resolves trick name to canonical difficulty and awards timing bonus.
  /// Base tricks: kickflip, heelflip, treflip, 360flip, noseslide, manual, 50-50, nollie, hardflip.
  /// Special tricks (unlocked after kSpecialsUnlockThreshold): 900, mcttwist, christ_air.
  auto onNamedTrick(std::string_view trickName, float timingNormalized) -> Result<nlohmann::json>;
  auto bail() -> Result<nlohmann::json>;

  /// Begin a manual grind — starts balance oscillation timer.
  /// Keeping balance alive chains score; a fall resets the combo.
  auto onManual(float balanceNormalized) -> Result<nlohmann::json>;
  /// End manual (land cleanly) — awards score bonus for duration held.
  auto endManual() -> Result<nlohmann::json>;

  [[nodiscard]] auto trickScore()       const -> int32_t  { return static_cast<int32_t>(m_trickScore); }
  [[nodiscard]] auto timeRemaining()    const -> float    { return kRunDurationSeconds - m_runTimer; }
  [[nodiscard]] auto specialsUnlocked() const -> bool     { return m_specialsUnlocked; }
  [[nodiscard]] auto isManualActive()   const -> bool     { return m_manualActive; }
  [[nodiscard]] auto isRunComplete()    const -> bool {
    return m_phase == SkatePhase::kRunComplete;
  }
  [[nodiscard]] auto stateJson() const -> nlohmann::json;

private:
  [[nodiscard]] static auto trickDifficulty(std::string_view trickName) -> float;
  [[nodiscard]] static auto timingBonus(float timingNormalized)          -> float;
  void checkRunEnd();

  SkatePhase m_phase{SkatePhase::kRun};
  float   m_trickScore{0.0F};
  float   m_runTimer{0.0F};       // seconds elapsed in run
  int32_t m_comboMultiplier{1};
  int32_t m_tricksLanded{0};
  int32_t m_tricksBailed{0};
  int32_t m_peakCombo{1};
  bool    m_specialsUnlocked{false};
  // Manual state.
  bool    m_manualActive{false};
  float   m_manualTimer{0.0F};
  std::string m_lastTrickName;
};

} // namespace nexus::gameplay
