#pragma once

#include "nexus/core/result.h"

#include <nlohmann/json.hpp>

#include <string>
#include <string_view>
#include <vector>

namespace nexus::ai {

struct ParsedAgentStep {
  std::string command;
  nlohmann::json params;
  std::string rationale;
};

struct TextGenerationPlan {
  std::string originalPrompt;
  std::string intent; // terrain | prop | environment | mixed
  std::vector<ParsedAgentStep> steps;
  nlohmann::json metadata;

  [[nodiscard]] auto toJson() const -> nlohmann::json;
};

struct TextPromptAdapterOptions {
  std::array<int, 3> defaultPosition{0, 0, 0};
  int defaultRadius{3};
  int defaultHeight{2};
  std::string assetIdPrefix{"gen_"};
  std::string venueIdPrefix{"prompt_venue_"};
};

/// Template-based MVP: maps natural language to fel.creative.* / fel.generate.* / fel.scan.* steps.
/// No external LLM API required.
[[nodiscard]] auto parseTextPrompt(std::string_view prompt,
                                   TextPromptAdapterOptions options = {})
    -> Result<TextGenerationPlan>;

[[nodiscard]] auto planToJson(const TextGenerationPlan& plan) -> nlohmann::json;

} // namespace nexus::ai
