#include "nexus/gameplay/snowboarding_mode.h"

#include "nexus/gameplay/arena_mode_registry.h"

#include <algorithm>
#include <string>

namespace nexus::gameplay {

namespace {

constexpr float kTimingPerfectThreshold = 0.92F;
constexpr float kTimingGoodThreshold = 0.65F;

} // namespace

void SnowboardingMode::reset() {
  m_phase = SnowPhase::kRun;
  m_lineScore = 0.0F;
  m_flowMeter = 0.0F;
  m_comboMultiplier = 1;
  m_carvesLanded = 0;
  m_jumpsLanded = 0;
  m_butterMoves = 0;
  m_wipeouts = 0;
  m_peakCombo = 1;
}

void SnowboardingMode::update(double /*deltaSeconds*/) {
  if (m_phase == SnowPhase::kRunComplete) {
    return;
  }
  m_flowMeter = std::max(0.0F, m_flowMeter - 0.02F);
}

auto SnowboardingMode::carve(float timing, float lineDifficulty) -> Result<nlohmann::json> {
  if (m_phase == SnowPhase::kRunComplete) {
    return Result<nlohmann::json>::err("snow run already complete");
  }

  const float t = std::clamp(timing, 0.0F, 1.0F);
  const float diff = std::clamp(lineDifficulty, 0.1F, 1.0F);
  const float flowBoost = 1.0F + m_flowMeter * 0.25F;
  const float points = (4.0F + diff * 6.0F) * flowBoost *
                       (t >= kTimingPerfectThreshold ? 1.15F
                        : t >= kTimingGoodThreshold   ? 1.0F
                                                      : 0.75F);

  m_lineScore += points;
  m_flowMeter = std::clamp(m_flowMeter + 0.12F, 0.0F, 1.0F);
  ++m_carvesLanded;

  if (static_cast<int32_t>(m_lineScore) >= kWinScore) {
    m_phase = SnowPhase::kRunComplete;
  }

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
  if (m_phase == SnowPhase::kRunComplete) {
    return Result<nlohmann::json>::err("snow run already complete");
  }

  const float diff = std::clamp(airDifficulty, 0.1F, 1.0F);
  const int32_t combo = std::clamp(comboMultiplier, 1, 8);
  m_comboMultiplier = combo;
  m_peakCombo = std::max(m_peakCombo, combo);

  const float flowBoost = 1.0F + m_flowMeter * 0.35F;
  const float points = (10.0F + diff * 14.0F) * static_cast<float>(combo) * flowBoost;
  m_lineScore += points;
  ++m_jumpsLanded;
  m_flowMeter = std::clamp(m_flowMeter + 0.08F, 0.0F, 1.0F);

  if (static_cast<int32_t>(m_lineScore) >= kWinScore) {
    m_phase = SnowPhase::kRunComplete;
  }

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
  if (m_phase == SnowPhase::kRunComplete) {
    return Result<nlohmann::json>::err("snow run already complete");
  }

  const float styleNorm = std::clamp(style, 0.1F, 1.0F);
  const float points = 3.0F + styleNorm * 5.0F;
  m_lineScore += points;
  ++m_butterMoves;
  m_flowMeter = std::clamp(m_flowMeter + 0.18F, 0.0F, 1.0F);

  if (static_cast<int32_t>(m_lineScore) >= kWinScore) {
    m_phase = SnowPhase::kRunComplete;
  }

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

auto SnowboardingMode::wipeout() -> Result<nlohmann::json> {
  if (m_phase == SnowPhase::kRunComplete) {
    return Result<nlohmann::json>::err("snow run already complete");
  }

  ++m_wipeouts;
  m_comboMultiplier = 1;
  m_flowMeter = 0.0F;

  if (m_wipeouts >= kMaxWipeouts && static_cast<int32_t>(m_lineScore) < kWinScore) {
    m_phase = SnowPhase::kRunComplete;
  }

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
  out["phase"] = static_cast<int>(m_phase);
  out["line_score"] = static_cast<int32_t>(m_lineScore);
  out["win_target"] = kWinScore;
  out["flow_meter"] = m_flowMeter;
  out["combo_multiplier"] = m_comboMultiplier;
  out["peak_combo"] = m_peakCombo;
  out["carves_landed"] = m_carvesLanded;
  out["jumps_landed"] = m_jumpsLanded;
  out["butter_moves"] = m_butterMoves;
  out["wipeouts"] = m_wipeouts;
  out["max_wipeouts"] = kMaxWipeouts;
  out["run_complete"] = isRunComplete();
  out["release_state"] = std::string(ArenaModeRegistry::releaseStateStringForMode("snowboarding"));
  return out;
}

} // namespace nexus::gameplay
