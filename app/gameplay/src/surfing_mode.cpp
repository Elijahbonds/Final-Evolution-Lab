#include "nexus/gameplay/surfing_mode.h"

#include <algorithm>

namespace nexus::gameplay {

namespace {

constexpr float kTimingPerfectThreshold = 0.92F;
constexpr float kTimingGoodThreshold = 0.65F;

} // namespace

void SurfingMode::reset() {
  m_phase = SurfPhase::kRun;
  m_waveScore = 0.0F;
  m_flowMeter = 0.0F;
  m_comboMultiplier = 1;
  m_carvesLanded = 0;
  m_aerialsLanded = 0;
  m_tubeRides = 0;
  m_wipeouts = 0;
  m_peakCombo = 1;
}

void SurfingMode::update(double /*deltaSeconds*/) {
  if (m_phase == SurfPhase::kRunComplete) {
    return;
  }
  m_flowMeter = std::max(0.0F, m_flowMeter - 0.025F);
}

auto SurfingMode::carve(float timing, float waveDifficulty) -> Result<nlohmann::json> {
  if (m_phase == SurfPhase::kRunComplete) {
    return Result<nlohmann::json>::err("surf run already complete");
  }

  const float t = std::clamp(timing, 0.0F, 1.0F);
  const float diff = std::clamp(waveDifficulty, 0.1F, 1.0F);
  const float flowBoost = 1.0F + m_flowMeter * 0.3F;
  const float points = (5.0F + diff * 7.0F) * flowBoost *
                       (t >= kTimingPerfectThreshold ? 1.2F
                        : t >= kTimingGoodThreshold   ? 1.0F
                                                      : 0.7F);

  m_waveScore += points;
  m_flowMeter = std::clamp(m_flowMeter + 0.14F, 0.0F, 1.0F);
  ++m_carvesLanded;

  if (static_cast<int32_t>(m_waveScore) >= kWinScore) {
    m_phase = SurfPhase::kRunComplete;
  }

  nlohmann::json payload = nlohmann::json::object();
  payload.merge_patch(stateJson());
  payload["carve"] = nlohmann::json{
      {"timing", t},
      {"wave_difficulty", diff},
      {"points", points},
      {"grade", t >= kTimingPerfectThreshold   ? "perfect"
                : t >= kTimingGoodThreshold    ? "good"
                                               : "miss"},
      {"flow_meter", m_flowMeter},
  };
  payload["agent_envelope"] = nlohmann::json{
      {"command", "fel.surf.carve"},
      {"flow_meter", m_flowMeter},
      {"wave_score", static_cast<int32_t>(m_waveScore)},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto SurfingMode::aerial(float airDifficulty, int32_t comboMultiplier)
    -> Result<nlohmann::json> {
  if (m_phase == SurfPhase::kRunComplete) {
    return Result<nlohmann::json>::err("surf run already complete");
  }

  const float diff = std::clamp(airDifficulty, 0.1F, 1.0F);
  const int32_t combo = std::clamp(comboMultiplier, 1, 8);
  m_comboMultiplier = combo;
  m_peakCombo = std::max(m_peakCombo, combo);

  const float flowBoost = 1.0F + m_flowMeter * 0.4F;
  const float points = (12.0F + diff * 16.0F) * static_cast<float>(combo) * flowBoost;
  m_waveScore += points;
  ++m_aerialsLanded;
  m_flowMeter = std::clamp(m_flowMeter + 0.1F, 0.0F, 1.0F);

  if (static_cast<int32_t>(m_waveScore) >= kWinScore) {
    m_phase = SurfPhase::kRunComplete;
  }

  nlohmann::json payload = nlohmann::json::object();
  payload.merge_patch(stateJson());
  payload["aerial"] = {
      {"air_difficulty", diff},
      {"combo_multiplier", combo},
      {"points", points},
      {"flow_meter", m_flowMeter},
  };
  payload["agent_envelope"] = {
      {"command", "fel.surf.aerial"},
      {"combo_multiplier", combo},
      {"wave_score", static_cast<int32_t>(m_waveScore)},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto SurfingMode::tubeRide(float tubeDepth, float duration) -> Result<nlohmann::json> {
  if (m_phase == SurfPhase::kRunComplete) {
    return Result<nlohmann::json>::err("surf run already complete");
  }

  const float depth = std::clamp(tubeDepth, 0.0F, 1.0F);
  const float dur = std::clamp(duration, 0.0F, 1.0F);

  // Tube rides require good positioning — penalise if flow meter is too low.
  if (m_flowMeter < 0.35F) {
    ++m_wipeouts;
    m_flowMeter = 0.0F;
    if (m_wipeouts >= kMaxWipeouts && static_cast<int32_t>(m_waveScore) < kWinScore) {
      m_phase = SurfPhase::kRunComplete;
    }
    nlohmann::json payload = nlohmann::json::object();
    payload.merge_patch(stateJson());
    payload["tube_ride"] = {{"depth", depth}, {"duration", dur}, {"result", "wipeout"},
                            {"reason", "insufficient_flow"}};
    payload["agent_envelope"] = {{"command", "fel.surf.tube_ride"}, {"result", "wipeout"},
                                  {"wave_score", static_cast<int32_t>(m_waveScore)}};
    return Result<nlohmann::json>::ok(std::move(payload));
  }

  // Deep barrel + long hold = big points. Base: 20 pts, scaled by depth × duration × flow.
  const float flowBoost = 1.0F + m_flowMeter * 0.5F;
  const float points = (20.0F + depth * 25.0F) * (0.5F + dur * 0.5F) * flowBoost;
  m_waveScore += points;
  ++m_tubeRides;
  m_flowMeter = std::clamp(m_flowMeter + 0.20F, 0.0F, 1.0F);

  if (static_cast<int32_t>(m_waveScore) >= kWinScore) {
    m_phase = SurfPhase::kRunComplete;
  }

  const std::string grade = depth >= 0.75F && dur >= 0.7F ? "barrel"
                            : depth >= 0.5F               ? "tube"
                                                          : "curl";

  nlohmann::json payload = nlohmann::json::object();
  payload.merge_patch(stateJson());
  payload["tube_ride"] = {
      {"depth", depth},
      {"duration", dur},
      {"result", "made"},
      {"grade", grade},
      {"points", points},
      {"flow_meter", m_flowMeter},
  };
  payload["agent_envelope"] = {
      {"command", "fel.surf.tube_ride"},
      {"grade", grade},
      {"tube_rides", m_tubeRides},
      {"wave_score", static_cast<int32_t>(m_waveScore)},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto SurfingMode::wipeout() -> Result<nlohmann::json> {
  if (m_phase == SurfPhase::kRunComplete) {
    return Result<nlohmann::json>::err("surf run already complete");
  }

  ++m_wipeouts;
  m_comboMultiplier = 1;
  m_flowMeter = 0.0F;

  if (m_wipeouts >= kMaxWipeouts && static_cast<int32_t>(m_waveScore) < kWinScore) {
    m_phase = SurfPhase::kRunComplete;
  }

  nlohmann::json payload = nlohmann::json::object();
  payload.merge_patch(stateJson());
  payload["wipeout"] = {{"wipeouts", m_wipeouts}, {"combo_reset", true}, {"flow_meter", 0.0F}};
  payload["agent_envelope"] = {
      {"command", "fel.surf.wipeout"},
      {"wipeouts", m_wipeouts},
      {"wave_score", static_cast<int32_t>(m_waveScore)},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto SurfingMode::stateJson() const -> nlohmann::json {
  nlohmann::json out = nlohmann::json::object();
  out["phase"] = static_cast<int>(m_phase);
  out["wave_score"] = static_cast<int32_t>(m_waveScore);
  out["win_target"] = kWinScore;
  out["flow_meter"] = m_flowMeter;
  out["combo_multiplier"] = m_comboMultiplier;
  out["peak_combo"] = m_peakCombo;
  out["carves_landed"] = m_carvesLanded;
  out["aerials_landed"] = m_aerialsLanded;
  out["tube_rides"] = m_tubeRides;
  out["wipeouts"] = m_wipeouts;
  out["max_wipeouts"] = kMaxWipeouts;
  out["run_complete"] = isRunComplete();
  out["release_state"] = "validate_only";
  return out;
}

} // namespace nexus::gameplay
