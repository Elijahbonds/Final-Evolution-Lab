#include "nexus/gameplay/snowboarding_mode.h"

#include <algorithm>

namespace nexus::gameplay {

namespace {

constexpr float kTimingPerfectThreshold = 0.92F;
constexpr float kTimingGoodThreshold = 0.65F;

} // namespace

void SnowboardingMode::reset() {
  m_phase           = SnowPhase::kRun;
  m_lineScore       = 0.0F;
  m_flowMeter       = 0.0F;
  m_trickyMeter     = 0.0F;
  m_uberTimer       = 0.0F;
  m_comboMultiplier = 1;
  m_carvesLanded    = 0;
  m_jumpsLanded     = 0;
  m_butterMoves     = 0;
  m_grabs           = 0;
  m_wipeouts        = 0;
  m_peakCombo       = 1;
  m_gatesPassed     = 0;
  m_gatesMissed     = 0;
  // Note: m_ghostBestScore intentionally persists across resets for personal-best ghost.
}

void SnowboardingMode::update(double deltaSeconds) {
  if (m_phase == SnowPhase::kRunComplete) {
    return;
  }

  // Advance uber-trick cinematic timer.
  if (m_phase == SnowPhase::kUberTrick) {
    m_uberTimer += static_cast<float>(deltaSeconds);
    if (m_uberTimer >= kUberAnimDuration) {
      // Apply the score multiplier once the animation finishes.
      m_lineScore *= kUberScoreMultiplier;
      m_phase = SnowPhase::kRun;
      m_uberTimer = 0.0F;
      checkRunEnd();
    }
    return;
  }

  m_flowMeter   = std::max(0.0F, m_flowMeter - 0.02F);
  m_trickyMeter = std::max(0.0F, m_trickyMeter - 0.5F);  // slowly drains when idle
}

auto SnowboardingMode::carve(float timing, float lineDifficulty) -> Result<nlohmann::json> {
  if (m_phase == SnowPhase::kRunComplete || m_phase == SnowPhase::kUberTrick) {
    return Result<nlohmann::json>::err("snow run already complete");
  }

  const float t         = std::clamp(timing, 0.0F, 1.0F);
  const float diff      = std::clamp(lineDifficulty, 0.1F, 1.0F);
  const float flowBoost = 1.0F + m_flowMeter * 0.25F;
  const float points    = (4.0F + diff * 6.0F) * flowBoost *
                          (t >= kTimingPerfectThreshold ? 1.15F
                           : t >= kTimingGoodThreshold  ? 1.0F
                                                        : 0.75F);

  m_lineScore   += points;
  m_flowMeter    = std::clamp(m_flowMeter + 0.12F, 0.0F, 1.0F);
  m_trickyMeter  = std::clamp(m_trickyMeter + 8.0F, 0.0F, kTrickyMeterMax);
  ++m_carvesLanded;
  checkRunEnd();

  nlohmann::json payload = nlohmann::json::object();
  payload.merge_patch(stateJson());
  payload["carve"] = nlohmann::json{
      {"timing", t},
      {"line_difficulty", diff},
      {"points", points},
      {"grade", t >= kTimingPerfectThreshold   ? "perfect"
                : t >= kTimingGoodThreshold    ? "good"
                                               : "miss"},
      {"flow_meter", m_flowMeter},
  };
  payload["agent_envelope"] = nlohmann::json{
      {"command", "fel.snow.carve"},
      {"flow_meter", m_flowMeter},
      {"line_score", static_cast<int32_t>(m_lineScore)},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto SnowboardingMode::jump(float airDifficulty, int32_t comboMultiplier)
    -> Result<nlohmann::json> {
  if (m_phase == SnowPhase::kRunComplete || m_phase == SnowPhase::kUberTrick) {
    return Result<nlohmann::json>::err("snow run already complete");
  }

  const float   diff  = std::clamp(airDifficulty, 0.1F, 1.0F);
  const int32_t combo = std::clamp(comboMultiplier, 1, 8);
  m_comboMultiplier   = combo;
  m_peakCombo         = std::max(m_peakCombo, combo);

  const float flowBoost = 1.0F + m_flowMeter * 0.35F;
  const float points    = (10.0F + diff * 14.0F) * static_cast<float>(combo) * flowBoost;
  m_lineScore   += points;
  m_flowMeter    = std::clamp(m_flowMeter + 0.08F, 0.0F, 1.0F);
  m_trickyMeter  = std::clamp(m_trickyMeter + 12.0F, 0.0F, kTrickyMeterMax);
  ++m_jumpsLanded;
  checkRunEnd();

  nlohmann::json payload = nlohmann::json::object();
  payload.merge_patch(stateJson());
  payload["jump"] = {
      {"air_difficulty", diff},
      {"combo_multiplier", combo},
      {"points", points},
      {"flow_meter", m_flowMeter},
  };
  payload["agent_envelope"] = {
      {"command", "fel.snow.jump"},
      {"combo_multiplier", combo},
      {"line_score", static_cast<int32_t>(m_lineScore)},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto SnowboardingMode::butter(float style) -> Result<nlohmann::json> {
  if (m_phase == SnowPhase::kRunComplete || m_phase == SnowPhase::kUberTrick) {
    return Result<nlohmann::json>::err("snow run already complete");
  }

  const float styleNorm = std::clamp(style, 0.1F, 1.0F);
  const float points    = 3.0F + styleNorm * 5.0F;
  m_lineScore   += points;
  m_flowMeter    = std::clamp(m_flowMeter + 0.18F, 0.0F, 1.0F);
  m_trickyMeter  = std::clamp(m_trickyMeter + 6.0F, 0.0F, kTrickyMeterMax);
  ++m_butterMoves;
  checkRunEnd();

  nlohmann::json payload = nlohmann::json::object();
  payload.merge_patch(stateJson());
  payload["butter"] = {{"style", styleNorm}, {"points", points}, {"flow_meter", m_flowMeter}};
  payload["agent_envelope"] = {
      {"command", "fel.snow.butter"},
      {"flow_meter", m_flowMeter},
      {"line_score", static_cast<int32_t>(m_lineScore)},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto SnowboardingMode::grab(std::string_view grabName, float timing) -> Result<nlohmann::json> {
  if (m_phase == SnowPhase::kRunComplete || m_phase == SnowPhase::kUberTrick) {
    return Result<nlohmann::json>::err("snow run already complete");
  }

  const float t = std::clamp(timing, 0.0F, 1.0F);

  // Style multiplier by grab type: technical grabs score higher.
  float styleMultiplier = 1.0F;
  if (grabName == "stalefish" || grabName == "mute") {
    styleMultiplier = 1.15F;
  } else if (grabName == "tail" || grabName == "nose") {
    styleMultiplier = 1.25F;
  }

  const float timingFactor = t >= kTimingPerfectThreshold ? 1.2F
                             : t >= kTimingGoodThreshold  ? 1.0F
                                                          : 0.75F;
  const float flowBoost = 1.0F + m_flowMeter * 0.3F;
  const float points    = 6.0F * styleMultiplier * timingFactor * flowBoost;
  m_lineScore   += points;
  m_flowMeter    = std::clamp(m_flowMeter + 0.10F, 0.0F, 1.0F);
  m_trickyMeter  = std::clamp(m_trickyMeter + 10.0F, 0.0F, kTrickyMeterMax);
  ++m_grabs;
  checkRunEnd();

  const std::string grade = t >= kTimingPerfectThreshold ? "perfect"
                            : t >= kTimingGoodThreshold  ? "good"
                                                         : "miss";
  nlohmann::json payload = nlohmann::json::object();
  payload.merge_patch(stateJson());
  payload["grab"] = {
      {"name", std::string(grabName)},
      {"timing", t},
      {"grade", grade},
      {"style_multiplier", styleMultiplier},
      {"points", points},
      {"flow_meter", m_flowMeter},
  };
  payload["agent_envelope"] = {
      {"command", "fel.snow.grab"},
      {"grab_name", std::string(grabName)},
      {"grabs", m_grabs},
      {"line_score", static_cast<int32_t>(m_lineScore)},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto SnowboardingMode::wipeout() -> Result<nlohmann::json> {
  if (m_phase == SnowPhase::kRunComplete) {
    return Result<nlohmann::json>::err("snow run already complete");
  }

  ++m_wipeouts;
  m_comboMultiplier = 1;
  m_flowMeter       = 0.0F;
  m_trickyMeter     = 0.0F;  // SSX: wipeout fully resets the Tricky meter

  checkRunEnd();

  nlohmann::json payload = nlohmann::json::object();
  payload.merge_patch(stateJson());
  payload["wipeout"] = {{"wipeouts", m_wipeouts}, {"combo_reset", true}, {"flow_meter", 0.0F}};
  payload["agent_envelope"] = {
      {"command", "fel.snow.wipeout"},
      {"wipeouts", m_wipeouts},
      {"line_score", static_cast<int32_t>(m_lineScore)},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto SnowboardingMode::stateJson() const -> nlohmann::json {
  nlohmann::json out = nlohmann::json::object();
  out["phase"]           = static_cast<int>(m_phase);
  out["line_score"]      = static_cast<int32_t>(m_lineScore);
  out["win_target"]      = kWinScore;
  out["flow_meter"]      = m_flowMeter;
  out["tricky_meter"]    = m_trickyMeter;
  out["tricky_max"]      = kTrickyMeterMax;
  out["uber_ready"]      = isUberReady();
  out["combo_multiplier"]= m_comboMultiplier;
  out["peak_combo"]      = m_peakCombo;
  out["carves_landed"]   = m_carvesLanded;
  out["jumps_landed"]    = m_jumpsLanded;
  out["butter_moves"]    = m_butterMoves;
  out["grabs"]           = m_grabs;
  out["wipeouts"]        = m_wipeouts;
  out["max_wipeouts"]    = kMaxWipeouts;
  out["gates_passed"]    = m_gatesPassed;
  out["gates_missed"]    = m_gatesMissed;
  out["gate_count"]      = kGateCount;
  out["ghost_best_score"]= m_ghostBestScore;
  out["run_complete"]    = isRunComplete();
  out["release_state"]   = "validate_only";
  return out;
}

// ── New gate / uber API ──────────────────────────────────────────────────────

auto SnowboardingMode::uberTrick() -> Result<nlohmann::json> {
  if (m_phase == SnowPhase::kRunComplete) {
    return Result<nlohmann::json>::err("snow run already complete");
  }
  if (m_trickyMeter < kUberThreshold) {
    return Result<nlohmann::json>::err("tricky meter not full — cannot fire uber trick");
  }

  m_phase       = SnowPhase::kUberTrick;
  m_uberTimer   = 0.0F;
  m_trickyMeter = 0.0F;  // consume the meter

  nlohmann::json payload = nlohmann::json::object();
  payload.merge_patch(stateJson());
  payload["uber"] = {
      {"multiplier",   kUberScoreMultiplier},
      {"anim_duration", kUberAnimDuration},
      {"note",         "cinematic pause — apply multiplier after anim completes"},
  };
  payload["agent_envelope"] = {
      {"command",     "fel.snow.uber_trick"},
      {"line_score",  static_cast<int32_t>(m_lineScore)},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto SnowboardingMode::passGate() -> Result<nlohmann::json> {
  if (m_phase == SnowPhase::kRunComplete) {
    return Result<nlohmann::json>::err("snow run already complete");
  }

  ++m_gatesPassed;
  // Reward: small flow boost for staying on the racing line.
  m_flowMeter   = std::clamp(m_flowMeter + 0.06F, 0.0F, 1.0F);
  m_trickyMeter = std::clamp(m_trickyMeter + 5.0F, 0.0F, kTrickyMeterMax);

  nlohmann::json payload = nlohmann::json::object();
  payload.merge_patch(stateJson());
  payload["gate"] = {
      {"result",      "pass"},
      {"gates_passed", m_gatesPassed},
      {"gates_total", kGateCount},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto SnowboardingMode::missGate() -> Result<nlohmann::json> {
  if (m_phase == SnowPhase::kRunComplete) {
    return Result<nlohmann::json>::err("snow run already complete");
  }

  ++m_gatesMissed;
  m_lineScore   = std::max(m_lineScore - kGateMissDeduction, 0.0F);
  // Missing a gate also breaks flow.
  m_flowMeter   = std::max(m_flowMeter - 0.15F, 0.0F);

  checkRunEnd();

  nlohmann::json payload = nlohmann::json::object();
  payload.merge_patch(stateJson());
  payload["gate"] = {
      {"result",       "miss"},
      {"deduction",    kGateMissDeduction},
      {"gates_missed", m_gatesMissed},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

void SnowboardingMode::checkRunEnd() {
  if (static_cast<int32_t>(m_lineScore) >= kWinScore || m_wipeouts >= kMaxWipeouts) {
    if (static_cast<int32_t>(m_lineScore) > m_ghostBestScore) {
      m_ghostBestScore = static_cast<int32_t>(m_lineScore);
    }
    m_phase = SnowPhase::kRunComplete;
  }
}

} // namespace nexus::gameplay
