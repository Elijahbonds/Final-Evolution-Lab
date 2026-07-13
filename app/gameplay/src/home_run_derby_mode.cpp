#include "nexus/gameplay/home_run_derby_mode.h"

#include <algorithm>
#include <cmath>

namespace nexus::gameplay {

namespace {

constexpr float kTimingPerfect = 0.92F;
constexpr float kTimingGood = 0.65F;
constexpr float kPowerHRThreshold = 0.70F;

} // namespace

void HomeRunDerbyMode::reset() {
  m_phase = DerbyPhase::kBatting;
  m_pendingPitchSpeed = 0.5F;
  m_pendingPitchLocation = 0.0F;
  m_pitchLive = false;
  m_homeRuns = 0;
  m_outs = 0;
  m_totalSwings = 0;
  m_contacts = 0;
  m_opponentHomeRuns = 5;
}

void HomeRunDerbyMode::update(double /*deltaSeconds*/) {
  // No time-based transitions needed; pitch/swing are event-driven
}

auto HomeRunDerbyMode::pitch(float speed, float location) -> Result<nlohmann::json> {
  if (m_phase == DerbyPhase::kDerbyOver) {
    return Result<nlohmann::json>::err("derby already over");
  }

  m_pendingPitchSpeed = std::clamp(speed, 0.0F, 1.0F);
  m_pendingPitchLocation = std::clamp(location, -1.0F, 1.0F);
  m_pitchLive = true;

  nlohmann::json payload = stateJson();
  payload["pitch"] = {
      {"speed", m_pendingPitchSpeed},
      {"location", m_pendingPitchLocation},
      {"zone", std::abs(m_pendingPitchLocation) < 0.25F ? "center"
               : m_pendingPitchLocation < 0.0F          ? "inside"
                                                         : "outside"},
  };
  payload["agent_envelope"] = {
      {"command", "fel.baseball.pitch"},
      {"pitch_speed", m_pendingPitchSpeed},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto HomeRunDerbyMode::swing(float timing, float power) -> Result<nlohmann::json> {
  if (m_phase == DerbyPhase::kDerbyOver) {
    return Result<nlohmann::json>::err("derby already over");
  }
  if (!m_pitchLive) {
    return Result<nlohmann::json>::err("no live pitch to swing at");
  }

  m_pitchLive = false;
  ++m_totalSwings;

  const SwingGrade grade = gradeSwing(timing, power);

  if (grade == SwingGrade::kHomeRun) {
    ++m_homeRuns;
    if (m_homeRuns >= kWinHomeRuns) {
      m_phase = DerbyPhase::kDerbyOver;
    }
  } else if (grade == SwingGrade::kContact) {
    ++m_contacts;
  } else {
    // Miss counts as an out
    ++m_outs;
    if (m_outs >= kMaxOuts && m_homeRuns < kWinHomeRuns) {
      m_phase = DerbyPhase::kDerbyOver;
    }
  }

  nlohmann::json payload = stateJson();
  payload["swing"] = {
      {"timing", std::clamp(timing, 0.0F, 1.0F)},
      {"power", std::clamp(power, 0.0F, 1.0F)},
      {"grade", grade == SwingGrade::kHomeRun   ? "home_run"
                : grade == SwingGrade::kContact ? "contact"
                                                : "miss"},
  };
  payload["agent_envelope"] = {
      {"command", "fel.baseball.swing"},
      {"grade", grade == SwingGrade::kHomeRun   ? "home_run"
                : grade == SwingGrade::kContact ? "contact"
                                                : "miss"},
      {"home_runs", m_homeRuns},
      {"outs", m_outs},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto HomeRunDerbyMode::gradeSwing(float timing, float power) const -> SwingGrade {
  const float t = std::clamp(timing, 0.0F, 1.0F);
  const float p = std::clamp(power, 0.0F, 1.0F);

  // Adjust timing window for pitch difficulty (faster pitch = tighter window)
  const float adjustedPerfect = kTimingPerfect - m_pendingPitchSpeed * 0.08F;
  const float adjustedGood = kTimingGood - m_pendingPitchSpeed * 0.06F;

  if (t >= adjustedPerfect && p >= kPowerHRThreshold) {
    return SwingGrade::kHomeRun;
  }
  if (t >= adjustedGood) {
    return SwingGrade::kContact;
  }
  return SwingGrade::kMiss;
}

auto HomeRunDerbyMode::stateJson() const -> nlohmann::json {
  return {
      {"phase", static_cast<int>(m_phase)},
      {"home_runs", m_homeRuns},
      {"win_target", kWinHomeRuns},
      {"outs", m_outs},
      {"max_outs", kMaxOuts},
      {"total_swings", m_totalSwings},
      {"contacts", m_contacts},
      {"opponent_home_runs", m_opponentHomeRuns},
      {"pitch_live", m_pitchLive},
      {"pending_pitch_speed", m_pendingPitchSpeed},
      {"pending_pitch_location", m_pendingPitchLocation},
      {"derby_over", isDerbyOver()},
      {"victory", isVictory()},
      {"release_state", "validate_only"},
  };
}

} // namespace nexus::gameplay
