#include "nexus/ai/gemini_game_prompt_client.h"

#include "nexus/ai/nexus_ai_studio_config.h"
#include "nexus/core/log.h"

#include <array>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <sstream>

namespace nexus::ai {

namespace {

constexpr std::string_view kSystemInstruction =
    "You map natural-language game ideas to NEXUS arena mode specs. "
    "Return JSON only. mode_id MUST be one of the registered ids. "
    "difficulty_tier is easy, normal, or hard. "
    "wants_arena_generation is true when the user mentions venue, court, arena, "
    "environment, voxel, terrain, mesh, or scan.";

constexpr std::array<std::string_view, 18> kRegisteredModeIds{{
    "basketball_h2h",  "basketball_dunk", "basketball_3v3", "court_carnival",
    "karate_h2h",      "karate_endless",  "baseball",       "football",
    "soccer",          "golf",            "tennis",         "volleyball",
    "surfing",         "who_scene_it",    "brain_brawl",    "gymnastics",
    "skateboarding",   "snowboarding",
}};

auto stripMarkdownCodeFence(std::string_view text) -> std::string {
  std::string trimmed(text);
  while (!trimmed.empty() && std::isspace(static_cast<unsigned char>(trimmed.front())) != 0) {
    trimmed.erase(trimmed.begin());
  }
  while (!trimmed.empty() && std::isspace(static_cast<unsigned char>(trimmed.back())) != 0) {
    trimmed.pop_back();
  }

  if (trimmed.rfind("```", 0) == 0) {
    const auto firstNewline = trimmed.find('\n');
    if (firstNewline != std::string::npos) {
      trimmed = trimmed.substr(firstNewline + 1);
    }
    const auto closingFence = trimmed.rfind("```");
    if (closingFence != std::string::npos) {
      trimmed = trimmed.substr(0, closingFence);
    }
    while (!trimmed.empty() && std::isspace(static_cast<unsigned char>(trimmed.front())) != 0) {
      trimmed.erase(trimmed.begin());
    }
    while (!trimmed.empty() && std::isspace(static_cast<unsigned char>(trimmed.back())) != 0) {
      trimmed.pop_back();
    }
  }

  return trimmed;
}

auto buildModeEnumSchema() -> nlohmann::json {
  nlohmann::json values = nlohmann::json::array();
  for (const std::string_view modeId : kRegisteredModeIds) {
    values.push_back(std::string(modeId));
  }
  return values;
}

auto buildRequestBody(std::string_view prompt) -> nlohmann::json {
  return {
      {"systemInstruction", {{"parts", {{{"text", std::string(kSystemInstruction)}}}}}},
      {"contents",
       {{{"role", "user"},
         {"parts", {{{"text", std::string(prompt)}}}}}}},
      {"generationConfig",
       {{"responseMimeType", "application/json"},
        {"responseSchema",
         {{"type", "OBJECT"},
          {"properties",
           {{"mode_id", {{"type", "STRING"}, {"enum", buildModeEnumSchema()}}},
            {"difficulty_tier",
             {{"type", "STRING"}, {"enum", nlohmann::json::array({"easy", "normal", "hard"})}}},
            {"wants_arena_generation", {{"type", "BOOLEAN"}}},
            {"duration_modifier",
             {{"type", "STRING"},
              {"enum", nlohmann::json::array({"shorter", "normal", "longer"})}}},
            {"rationale", {{"type", "STRING"}}}}},
          {"required", nlohmann::json::array({"mode_id", "difficulty_tier", "wants_arena_generation"})}}}}},
  };
}

auto extractTextFromGeminiResponse(const nlohmann::json& root) -> Result<std::string> {
  if (!root.contains("candidates") || !root["candidates"].is_array() || root["candidates"].empty()) {
    return Result<std::string>::err("Gemini response missing candidates");
  }
  const auto& content = root["candidates"][0].value("content", nlohmann::json::object());
  if (!content.contains("parts") || !content["parts"].is_array() || content["parts"].empty()) {
    return Result<std::string>::err("Gemini response missing content parts");
  }
  for (const auto& part : content["parts"]) {
    if (part.contains("text") && part["text"].is_string()) {
      return Result<std::string>::ok(part["text"].get<std::string>());
    }
  }
  return Result<std::string>::err("Gemini response has no text part");
}

auto postJsonViaCurl(std::string_view url, std::string_view jsonBody) -> Result<std::string> {
  const auto tempPath = std::filesystem::temp_directory_path() / "nexus_gemini_game_req.json";
  {
    std::ofstream out(tempPath);
    if (!out) {
      return Result<std::string>::err("failed to open temp file for Gemini request body");
    }
    out.write(jsonBody.data(), static_cast<std::streamsize>(jsonBody.size()));
    if (!out) {
      return Result<std::string>::err("failed to write Gemini request body");
    }
  }

  std::ostringstream command;
  command << "curl -sS -X POST -H 'Content-Type: application/json' -d @'" << tempPath.string()
          << "' '" << url << "'";

  FILE* readPipe = popen(command.str().c_str(), "r");
  if (readPipe == nullptr) {
    std::error_code ignored;
    std::filesystem::remove(tempPath, ignored);
    return Result<std::string>::err("failed to spawn curl for Gemini request");
  }

  std::string responseBody;
  std::array<char, 4096> buffer{};
  while (true) {
    const std::size_t read = std::fread(buffer.data(), 1, buffer.size(), readPipe);
    if (read == 0) {
      break;
    }
    responseBody.append(buffer.data(), read);
  }

  const int readClose = pclose(readPipe);
  std::error_code ignored;
  std::filesystem::remove(tempPath, ignored);

  if (readClose != 0) {
    return Result<std::string>::err("curl Gemini request failed with exit " + std::to_string(readClose));
  }
  if (responseBody.empty()) {
    return Result<std::string>::err("Gemini curl returned empty body");
  }
  return Result<std::string>::ok(std::move(responseBody));
}

} // namespace

auto requestGeminiGamePromptHints(std::string_view prompt,
                                  GeminiGamePromptClientOptions options) -> Result<nlohmann::json> {
  const std::string trimmed(prompt);
  if (trimmed.empty()) {
    return Result<nlohmann::json>::err("prompt must not be empty");
  }

  if (options.useStubTransport) {
    if (options.stubResponse.is_object() && !options.stubResponse.empty()) {
      return Result<nlohmann::json>::ok(options.stubResponse);
    }
    return Result<nlohmann::json>::err("Gemini stub transport has no stubResponse");
  }

  NexusAIStudioConfig studioConfig = NexusAIStudioConfig::resolve();
  if (!options.apiKey.empty()) {
    studioConfig.apiKey = options.apiKey;
    studioConfig.apiKeySource = "options_override";
  }
  if (!options.model.empty()) {
    studioConfig.model = options.model;
  }
  if (!options.baseUrl.empty()) {
    studioConfig.baseUrl = options.baseUrl;
  }

  if (!studioConfig.isConfigured()) {
    return Result<nlohmann::json>::err("Google AI Studio API key not configured");
  }

  const nlohmann::json requestBody = buildRequestBody(trimmed);
  const std::string requestJson = requestBody.dump();
  const std::string url = studioConfig.generateContentUrl();

  const auto httpResult = postJsonViaCurl(url, requestJson);
  if (httpResult.isErr()) {
    NEXUS_LOG_WARN(LogChannel::kAI, "Gemini game prompt request failed: " + httpResult.error());
    return Result<nlohmann::json>::err(httpResult.error());
  }

  nlohmann::json root{};
  try {
    root = nlohmann::json::parse(httpResult.value());
  } catch (const std::exception& ex) {
    return Result<nlohmann::json>::err(std::string("Gemini response JSON parse error: ") + ex.what());
  }

  if (root.contains("error")) {
    const std::string message = root["error"].value("message", "unknown Gemini error");
    return Result<nlohmann::json>::err("Gemini API error: " + message);
  }

  const auto textResult = extractTextFromGeminiResponse(root);
  if (textResult.isErr()) {
    return Result<nlohmann::json>::err(textResult.error());
  }

  try {
    const std::string sanitized = stripMarkdownCodeFence(textResult.value());
    nlohmann::json hints = nlohmann::json::parse(sanitized);
    if (!hints.is_object()) {
      return Result<nlohmann::json>::err("Gemini hints must be a JSON object");
    }
    return Result<nlohmann::json>::ok(std::move(hints));
  } catch (const std::exception& ex) {
    return Result<nlohmann::json>::err(std::string("Gemini hints JSON parse error: ") + ex.what());
  }
}

} // namespace nexus::ai
