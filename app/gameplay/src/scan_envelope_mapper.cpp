// File: app/gameplay/src/scan_envelope_mapper.cpp
#include "nexus/gameplay/scan_envelope_mapper.h"

#include <algorithm>
#include <cmath>
#include <string>

namespace nexus::gameplay {

namespace {

[[nodiscard]] auto clampUnit(float value) -> float {
  if (!std::isfinite(value)) {
    return 0.0F;
  }
  return std::clamp(value, 0.0F, 1.0F);
}

[[nodiscard]] auto optionalFloatRaw(const nlohmann::json& object,
                                  std::string_view key,
                                  float defaultValue) -> float {
  const auto found = object.find(std::string(key));
  if (found == object.end() || !found->is_number()) {
    return defaultValue;
  }
  const float value = found->get<float>();
  return std::isfinite(value) ? value : defaultValue;
}

[[nodiscard]] auto optionalFloat(const nlohmann::json& object,
                               std::string_view key,
                               float defaultValue) -> float {
  const auto found = object.find(std::string(key));
  if (found == object.end() || !found->is_number()) {
    return defaultValue;
  }
  return clampUnit(found->get<float>());
}

[[nodiscard]] auto optionalInt(const nlohmann::json& object,
                             std::string_view key,
                             int defaultValue) -> int {
  const auto found = object.find(std::string(key));
  if (found == object.end() || !found->is_number_integer()) {
    return defaultValue;
  }
  return found->get<int>();
}

[[nodiscard]] auto difficultyFromReachAndControl(float reach01, float control01) -> int {
  const float composite = clampUnit(reach01 * 0.55F + control01 * 0.45F);
  if (composite >= 0.78F) {
    return 3;
  }
  if (composite >= 0.58F) {
    return 2;
  }
  if (composite >= 0.38F) {
    return 1;
  }
  return 0;
}

[[nodiscard]] auto arenaScaleFromMobility(float mobility01, float confidence01) -> float {
  const float base = 0.88F + mobility01 * 0.24F;
  const float confidenceAdj = (confidence01 - 0.5F) * 0.06F;
  return std::clamp(base + confidenceAdj, 0.85F, 1.15F);
}

[[nodiscard]] auto modeFromMetrics(float verticalInches, float kneeAngleDeg) -> std::string {
  if (verticalInches >= 26.0F) {
    return "basketball_dunk";
  }
  if (kneeAngleDeg <= 110.0F) {
    return "karate_endless";
  }
  return "court_carnival";
}

[[nodiscard]] auto materialFromTier(int tier) -> int {
  switch (tier) {
  case 3:
    return 9;
  case 2:
    return 7;
  case 1:
    return 5;
  default:
    return 3;
  }
}

[[nodiscard]] auto paintRadiusFromReach(float reach01) -> int {
  return std::clamp(static_cast<int>(std::lround(2.0F + reach01 * 10.0F)), 2, 12);
}

} // namespace

auto mapScanEnvelope(const nlohmann::json& envelope) -> Result<ScanEnvelopeMapResult> {
  if (!envelope.is_object()) {
    return Result<ScanEnvelopeMapResult>::err("scan envelope must be a JSON object");
  }

  const int schemaVersion = optionalInt(envelope, "schema_version", 1);
  if (schemaVersion < 1 || schemaVersion > 2) {
    return Result<ScanEnvelopeMapResult>::err("unsupported scan envelope schema_version");
  }

  const float confidence01 = clampUnit(optionalFloat(envelope, "confidence01", 0.5F));

  const nlohmann::json joints =
      envelope.contains("joints") && envelope["joints"].is_object() ? envelope["joints"]
                                                                    : nlohmann::json::object();
  const nlohmann::json motion =
      envelope.contains("motion") && envelope["motion"].is_object() ? envelope["motion"]
                                                                    : nlohmann::json::object();
  const nlohmann::json frcProxies =
      envelope.contains("frc_proxies") && envelope["frc_proxies"].is_object()
          ? envelope["frc_proxies"]
          : nlohmann::json::object();

  const float leftKnee = optionalFloatRaw(joints, "left_knee_angle_deg", 165.0F);
  const float rightKnee = optionalFloatRaw(joints, "right_knee_angle_deg", 165.0F);
  const float avgKnee = (leftKnee + rightKnee) * 0.5F;
  const float reach01 = clampUnit(
      (optionalFloat(joints, "left_shoulder_reach01", 0.5F) +
       optionalFloat(joints, "right_shoulder_reach01", 0.5F)) *
      0.5F);
  const float hipStability = clampUnit(optionalFloat(joints, "hip_stability01", 0.6F));

  const float verticalInches = optionalFloatRaw(motion, "vertical_estimate_inches", 22.0F);
  const float flightSeconds = optionalFloatRaw(motion, "flight_time_seconds", 0.45F);
  const float peakAccelG = optionalFloatRaw(motion, "peak_accel_g", 1.0F);

  const float mobility =
      frcProxies.contains("mobility01")
          ? optionalFloat(frcProxies, "mobility01", 0.5F)
          : clampUnit(1.0F - std::abs(avgKnee - 165.0F) / 90.0F);
  const float activeRange =
      frcProxies.contains("active_range01")
          ? optionalFloat(frcProxies, "active_range01", 0.5F)
          : clampUnit(reach01 * 0.7F + (180.0F - avgKnee) / 180.0F * 0.3F);
  const float control =
      frcProxies.contains("control01") ? optionalFloat(frcProxies, "control01", 0.5F)
                                       : clampUnit(hipStability * 0.6F + confidence01 * 0.4F);

  FRCMetrics frc{mobility, activeRange, control};
  IAPMetrics iap{
      clampUnit(flightSeconds / 0.72F),
      clampUnit(confidence01 * 0.85F + peakAccelG / 3.0F * 0.15F),
      flightSeconds > 0.5F ? static_cast<std::int8_t>(1) : static_cast<std::int8_t>(0),
  };

  ScanGenerativeParams generative;
  generative.arenaScale = arenaScaleFromMobility(mobility, confidence01);
  generative.difficultyTier = difficultyFromReachAndControl(reach01, control);
  generative.recommendedModeId = modeFromMetrics(verticalInches, avgKnee);
  generative.voxelMaterial = materialFromTier(generative.difficultyTier);
  generative.paintRadius = paintRadiusFromReach(reach01);
  generative.paintOrigin = {0, 0, 0};

  ScanEnvelopeMapResult mapped{
      frc,
      iap,
      generative,
      envelope,
  };
  return Result<ScanEnvelopeMapResult>::ok(std::move(mapped));
}

auto scanEnvelopeToCommandJson(const nlohmann::json& envelope) -> Result<nlohmann::json> {
  const auto mapped = mapScanEnvelope(envelope);
  if (mapped.isErr()) {
    return Result<nlohmann::json>::err(mapped.error());
  }

  const auto& result = mapped.value();
  const int radius = result.generative.paintRadius;
  const int material = result.generative.voxelMaterial;
  const auto origin = result.generative.paintOrigin;

  nlohmann::json commands = nlohmann::json::array();
  commands.push_back({
      {"command", "fel.fitness.update"},
      {"params",
       {
           {"frc_mobility", result.frc.mobilityScore},
           {"frc_active_range", result.frc.activeRangeScore},
           {"frc_control", result.frc.controlScore},
           {"iap_engagement", result.iap.engagementScore},
           {"iap_confidence", result.iap.confidence},
           {"breath_phase", result.iap.breathPhase},
       }},
  });
  commands.push_back({
      {"command", "fel.creative.fill_region"},
      {"params",
       {
           {"min", {origin[0] - radius, origin[1], origin[2] - radius}},
           {"max", {origin[0] + radius, origin[1], origin[2] + radius}},
           {"voxel", {{"material", material}, {"solid", true}}},
       }},
  });
  commands.push_back({
      {"command", "fel.generate.arena_from_scan"},
      {"params", envelope},
  });

  return Result<nlohmann::json>::ok({
      {"schema_version", 1},
      {"commands", std::move(commands)},
      {"generative",
       {
           {"arena_scale", result.generative.arenaScale},
           {"difficulty_tier", result.generative.difficultyTier},
           {"recommended_mode_id", result.generative.recommendedModeId},
           {"voxel_material", material},
           {"paint_radius", radius},
       }},
  });
}

} // namespace nexus::gameplay
