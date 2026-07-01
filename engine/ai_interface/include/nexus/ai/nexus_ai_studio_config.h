#pragma once

#include <string>
#include <string_view>

namespace nexus::ai {

/// Unified Google AI Studio / Gemini REST config for NEXUS engine (direct API — not Firebase AI Logic).
struct NexusAIStudioConfig {
  std::string apiKey;
  std::string model{"gemini-2.0-flash"};
  std::string baseUrl{"https://generativelanguage.googleapis.com"};
  /// Diagnostic only — e.g. `env:NEXUS_AGENT_GEMINI_KEY`, `aistudio_json:~/Downloads/foo.json`.
  std::string apiKeySource{"none"};

  [[nodiscard]] auto isConfigured() const -> bool { return !apiKey.empty(); }

  [[nodiscard]] auto generateContentUrl() const -> std::string;

  /// Env vars → optional AI Studio JSON in Downloads (`NEXUS_AI_STUDIO_CONFIG_PATH` override).
  [[nodiscard]] static auto resolve() -> NexusAIStudioConfig;

  /// Parse exported AI Studio JSON; resolves api-key references via env (never persists secrets).
  [[nodiscard]] static auto fromAIStudioJsonFile(std::string_view path) -> NexusAIStudioConfig;
};

/// Back-compat alias — same resolution order as `NexusAIStudioConfig::resolve().apiKey`.
[[nodiscard]] auto resolvedGeminiApiKey() -> std::string;

} // namespace nexus::ai
