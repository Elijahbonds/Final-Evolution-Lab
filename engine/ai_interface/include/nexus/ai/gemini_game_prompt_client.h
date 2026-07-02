#pragma once

#include "nexus/ai/nexus_ai_studio_config.h"
#include "nexus/core/result.h"

#include <nlohmann/json.hpp>

#include <string>
#include <string_view>

namespace nexus::ai {

struct GeminiGamePromptClientOptions {
  std::string apiKey;
  std::string model{"gemini-2.0-flash"};
  std::string baseUrl;
  /// When true, skip network (headless unit tests).
  bool useStubTransport{false};
  /// Injected response for stub transport tests.
  nlohmann::json stubResponse{};
};

/// REST `generateContent` with JSON schema — returns parsed hint object (not full game spec).
[[nodiscard]] auto requestGeminiGamePromptHints(std::string_view prompt,
                                                GeminiGamePromptClientOptions options = {})
    -> Result<nlohmann::json>;

} // namespace nexus::ai
