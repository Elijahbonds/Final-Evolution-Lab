#pragma once

#include "nexus/core/result.h"

#include <nlohmann/json.hpp>

#include <string>
#include <string_view>

namespace nexus::generative {

/// Builds a placeholder .nexusmesh.json document from a text prompt (Sprint 1 fallback).
[[nodiscard]] auto buildProceduralMeshJson(std::string_view name,
                                           std::string_view prompt) -> nlohmann::json;

[[nodiscard]] auto writeNexusMeshJson(const nlohmann::json& meshJson,
                                      const std::string& outputPath) -> Result<void>;

} // namespace nexus::generative
