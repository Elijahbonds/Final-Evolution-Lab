#pragma once

#include "nexus/core/result.h"

#include <nlohmann/json.hpp>

#include <string>
#include <string_view>
#include <vector>

namespace nexus::ai {

struct GameGenerationSpec {
  std::string specId;
  std::string originalPrompt;
  std::string modeId;
  std::string displayName;
  std::string venueToken;
  nlohmann::json rules;
  nlohmann::json hudTheme;
  std::string arenaPrompt;
  std::vector<std::string> refinementHistory;
  nlohmann::json metadata;

  [[nodiscard]] auto toJson() const -> nlohmann::json;
};

struct GamePromptAdapterOptions {
  /// When true, skip Gemini even if API key is configured.
  bool forceTemplate{false};
  /// Optional override for tests; empty reads env (`NEXUS_AI_STUDIO_API_KEY`, etc.).
  std::string geminiApiKey;
  std::string geminiModel{"gemini-2.0-flash"};
};

/// Natural language → mode, venue, rules, HUD theme JSON.
/// Uses optional Google AI Studio when `NEXUS_AI_STUDIO_API_KEY` (or alias) is set; otherwise template heuristics.
[[nodiscard]] auto parseGamePrompt(std::string_view prompt,
                                   GamePromptAdapterOptions options = {})
    -> Result<GameGenerationSpec>;

/// Merge validated Gemini hint JSON into a registry-backed spec (testable without network).
[[nodiscard]] auto buildSpecFromGeminiHints(std::string_view prompt, const nlohmann::json& hints)
    -> Result<GameGenerationSpec>;

/// Apply iterative refinement ("make it harder", "add dunk contest", …) to an existing spec.
[[nodiscard]] auto refineGameSpec(const GameGenerationSpec& base, std::string_view refinementText)
    -> Result<GameGenerationSpec>;

[[nodiscard]] auto gameSpecFromJson(const nlohmann::json& json) -> Result<GameGenerationSpec>;

/// Registry alias normalization (`venice_pickup` → `basketball_h2h`, etc.).
[[nodiscard]] auto normalizeGameModeId(std::string_view modeId) -> std::string;

/// Template keyword inference for prompts (18 playable modes; excludes `market_browse`).
[[nodiscard]] auto inferModeIdFromPrompt(std::string_view loweredPrompt) -> std::string;

/// Sanitize LLM JSON text (strip markdown fences, trim).
[[nodiscard]] auto sanitizeLlmJsonText(std::string_view text) -> std::string;

/// Coerce Gemini hint objects with defaults and normalized mode ids.
[[nodiscard]] auto normalizeGeminiGameHints(const nlohmann::json& hints, std::string_view prompt)
    -> nlohmann::json;

} // namespace nexus::ai
