// File: app/gameplay/include/nexus/gameplay/scan_envelope_mapper.h
// Part of: Final Evolution Lab (FEL) — scan → fitness + generative arena mapping
#pragma once

#include "nexus/core/result.h"
#include "nexus/gameplay/fitness_data.h"

#include <nlohmann/json.hpp>
#include <array>
#include <string_view>

namespace nexus::gameplay {

struct ScanGenerativeParams {
  float arenaScale{1.0F};
  int difficultyTier{1};
  std::string recommendedModeId{"court_carnival"};
  int voxelMaterial{5};
  int paintRadius{4};
  std::array<int, 3> paintOrigin{0, 0, 0};
};

struct ScanEnvelopeMapResult {
  FRCMetrics frc;
  IAPMetrics iap;
  ScanGenerativeParams generative;
  nlohmann::json envelopeEcho;
};

/// Validates and maps a POST scan envelope into fitness + generative parameters.
[[nodiscard]] auto mapScanEnvelope(const nlohmann::json& envelope) -> Result<ScanEnvelopeMapResult>;

/// Builds agent command payloads (fitness.update + creative.fill_region) from a scan envelope.
[[nodiscard]] auto scanEnvelopeToCommandJson(const nlohmann::json& envelope) -> Result<nlohmann::json>;

} // namespace nexus::gameplay
