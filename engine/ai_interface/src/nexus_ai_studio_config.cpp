#include "nexus/ai/nexus_ai_studio_config.h"

#include "nexus/core/log.h"

#include <nlohmann/json.hpp>

#include <array>
#include <cctype>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <string_view>

namespace nexus::ai {

namespace {

constexpr std::string_view kDefaultModel = "gemini-2.0-flash";
constexpr std::string_view kDefaultBaseUrl = "https://generativelanguage.googleapis.com";

auto trimCopy(std::string_view text) -> std::string {
  std::size_t start = 0;
  while (start < text.size() && std::isspace(static_cast<unsigned char>(text[start])) != 0) {
    ++start;
  }
  std::size_t end = text.size();
  while (end > start && std::isspace(static_cast<unsigned char>(text[end - 1])) != 0) {
    --end;
  }
  return std::string(text.substr(start, end - start));
}

auto looksLikeGoogleApiKey(std::string_view value) -> bool {
  return value.size() > 8 && value.rfind("AIza", 0) == 0;
}

auto looksLikeEnvVarName(std::string_view value) -> bool {
  if (value.empty()) {
    return false;
  }
  for (unsigned char character : value) {
    if (!(std::isupper(character) != 0 || character == '_' || std::isdigit(character) != 0)) {
      return false;
    }
  }
  return std::isupper(static_cast<unsigned char>(value.front())) != 0;
}

auto readEnvValue(std::string_view envKey) -> std::string {
  if (const char* value = std::getenv(std::string(envKey).c_str());
      value != nullptr && value[0] != '\0') {
    return std::string(value);
  }
  return {};
}

auto resolveApiKeyFromEnv() -> std::pair<std::string, std::string> {
  static constexpr std::array<std::string_view, 5> kEnvKeys{
      "NEXUS_AI_STUDIO_API_KEY",
      "NEXUS_AGENT_GEMINI_KEY",
      "GEMINI_API_KEY",
      "GOOGLE_API_KEY",
      "FEL_LLM_KEY",
  };
  for (const std::string_view envKey : kEnvKeys) {
    const std::string value = readEnvValue(envKey);
    if (!value.empty()) {
      return {value, std::string("env:") + std::string(envKey)};
    }
  }
  return {{}, "none"};
}

auto resolveModelFromEnv() -> std::string {
  if (const char* envModel = std::getenv("NEXUS_AI_STUDIO_MODEL");
      envModel != nullptr && envModel[0] != '\0') {
    return std::string(envModel);
  }
  if (const char* legacyModel = std::getenv("NEXUS_AGENT_GEMINI_MODEL");
      legacyModel != nullptr && legacyModel[0] != '\0') {
    return std::string(legacyModel);
  }
  return std::string(kDefaultModel);
}

auto resolveBaseUrlFromEnv() -> std::string {
  if (const char* envBase = std::getenv("NEXUS_AI_STUDIO_BASE_URL");
      envBase != nullptr && envBase[0] != '\0') {
    return std::string(envBase);
  }
  if (const char* legacyBase = std::getenv("NEXUS_AGENT_GEMINI_BASE_URL");
      legacyBase != nullptr && legacyBase[0] != '\0') {
    return std::string(legacyBase);
  }
  return std::string(kDefaultBaseUrl);
}

auto resolveApiKeyReference(std::string_view reference) -> std::pair<std::string, std::string> {
  const std::string trimmed = trimCopy(reference);
  if (trimmed.empty()) {
    return {{}, "none"};
  }

  if (looksLikeGoogleApiKey(trimmed)) {
    return {trimmed, "aistudio_json:embedded_key"};
  }

  std::string envName = trimmed;
  if (envName.rfind("${", 0) == 0 && envName.size() > 3 && envName.back() == '}') {
    envName = envName.substr(2, envName.size() - 3);
  } else if (envName.rfind("$", 0) == 0 && envName.size() > 1) {
    envName = envName.substr(1);
  }

  if (looksLikeEnvVarName(envName)) {
    const std::string value = readEnvValue(envName);
    if (!value.empty()) {
      return {value, std::string("aistudio_json:env:") + envName};
    }
    return {{}, std::string("aistudio_json:missing_env:") + envName};
  }

  return {{}, "aistudio_json:unresolved_reference"};
}

auto applyJsonObjectToConfig(const nlohmann::json& object, NexusAIStudioConfig& config) -> void {
  if (!object.is_object()) {
    return;
  }

  static constexpr std::array<std::string_view, 6> kApiKeyRefFields{
      "apiKeyEnvVar", "api_key_env", "apiKeyReference", "api_key_reference", "geminiApiKeyEnv",
      "GOOGLE_GENAI_API_KEY_ENV",
  };
  for (const std::string_view field : kApiKeyRefFields) {
    if (object.contains(field.data()) && object[field.data()].is_string()) {
      const auto [key, source] = resolveApiKeyReference(object[field.data()].get<std::string>());
      if (!key.empty()) {
        config.apiKey = key;
        config.apiKeySource = source;
      }
      break;
    }
  }

  if (config.apiKey.empty() && object.contains("apiKey") && object["apiKey"].is_string()) {
    const auto [key, source] = resolveApiKeyReference(object["apiKey"].get<std::string>());
    if (!key.empty()) {
      config.apiKey = key;
      config.apiKeySource = source;
    }
  }

  static constexpr std::array<std::string_view, 4> kModelFields{
      "model", "defaultModel", "geminiModel", "modelId",
  };
  for (const std::string_view field : kModelFields) {
    if (object.contains(field.data()) && object[field.data()].is_string()) {
      const std::string model = trimCopy(object[field.data()].get<std::string>());
      if (!model.empty()) {
        config.model = model;
        break;
      }
    }
  }

  static constexpr std::array<std::string_view, 3> kBaseUrlFields{
      "baseUrl", "apiBaseUrl", "generativeLanguageBaseUrl",
  };
  for (const std::string_view field : kBaseUrlFields) {
    if (object.contains(field.data()) && object[field.data()].is_string()) {
      const std::string baseUrl = trimCopy(object[field.data()].get<std::string>());
      if (!baseUrl.empty()) {
        config.baseUrl = baseUrl;
        break;
      }
    }
  }
}

auto parseDotEnvLine(std::string_view line, NexusAIStudioConfig& config) -> void {
  const std::string trimmed = trimCopy(line);
  if (trimmed.empty() || trimmed[0] == '#') {
    return;
  }
  const auto equals = trimmed.find('=');
  if (equals == std::string::npos) {
    return;
  }
  const std::string key = trimCopy(trimmed.substr(0, equals));
  const std::string value = trimCopy(trimmed.substr(equals + 1));
  if (key == "GEMINI_API_KEY" || key == "GOOGLE_API_KEY" || key == "NEXUS_AGENT_GEMINI_KEY") {
    if (!value.empty() && !looksLikeEnvVarName(value) && config.apiKey.empty()) {
      config.apiKey = value;
      config.apiKeySource = "aistudio_dotenv:" + key;
    }
  }
  if (key == "NEXUS_AGENT_GEMINI_MODEL" && !value.empty()) {
    config.model = value;
  }
}

auto isCandidateAIStudioFile(const std::filesystem::path& path) -> bool {
  if (!std::filesystem::is_regular_file(path)) {
    return false;
  }
  const std::string filename = path.filename().string();
  const std::string lower = [&filename]() {
    std::string copy = filename;
    for (char& character : copy) {
      character = static_cast<char>(std::tolower(static_cast<unsigned char>(character)));
    }
    return copy;
  }();

  if (lower == ".env" || lower == ".env.local" || lower == ".env.example") {
    return true;
  }
  if (path.extension() != ".json") {
    return false;
  }
  return lower.find("aistudio") != std::string::npos || lower.find("gemini") != std::string::npos ||
         lower.find("google_ai") != std::string::npos ||
         lower.find("generativelanguage") != std::string::npos;
}

auto scanDownloadsForAIStudioConfig() -> NexusAIStudioConfig {
  NexusAIStudioConfig config{};
  config.model = resolveModelFromEnv();
  config.baseUrl = resolveBaseUrlFromEnv();

  std::filesystem::path configPath;
  if (const char* overridePath = std::getenv("NEXUS_AI_STUDIO_CONFIG_PATH");
      overridePath != nullptr && overridePath[0] != '\0') {
    configPath = std::filesystem::path(overridePath);
  } else {
    const char* home = std::getenv("HOME");
    if (home == nullptr || home[0] == '\0') {
      return config;
    }
    configPath = std::filesystem::path(home) / "Downloads";
  }

  std::error_code ec;
  if (!std::filesystem::exists(configPath, ec) || !std::filesystem::is_directory(configPath, ec)) {
    return config;
  }

  for (const auto& entry : std::filesystem::directory_iterator(configPath, ec)) {
    if (ec || !isCandidateAIStudioFile(entry.path())) {
      continue;
    }

    NexusAIStudioConfig parsed{};
    parsed.model = config.model;
    parsed.baseUrl = config.baseUrl;

    if (entry.path().extension() == ".json") {
      parsed = NexusAIStudioConfig::fromAIStudioJsonFile(entry.path().string());
      if (parsed.model.empty()) {
        parsed.model = config.model;
      }
      if (parsed.baseUrl.empty()) {
        parsed.baseUrl = config.baseUrl;
      }
    } else {
      std::ifstream in(entry.path());
      if (!in) {
        continue;
      }
      std::string line;
      while (std::getline(in, line)) {
        parseDotEnvLine(line, parsed);
      }
    }

    if (parsed.isConfigured()) {
      NEXUS_LOG_INFO(LogChannel::kAI,
                     "AI Studio config loaded from " + entry.path().filename().string() + " (" +
                         parsed.apiKeySource + ")");
      return parsed;
    }
    if (!parsed.model.empty() && parsed.model != std::string(kDefaultModel)) {
      config.model = parsed.model;
    }
    if (!parsed.baseUrl.empty() && parsed.baseUrl != std::string(kDefaultBaseUrl)) {
      config.baseUrl = parsed.baseUrl;
    }
  }

  return config;
}

} // namespace

auto NexusAIStudioConfig::generateContentUrl() const -> std::string {
  std::string url = baseUrl;
  if (!url.empty() && url.back() == '/') {
    url.pop_back();
  }
  return url + "/v1beta/models/" + model + ":generateContent?key=" + apiKey;
}

auto NexusAIStudioConfig::fromAIStudioJsonFile(std::string_view path) -> NexusAIStudioConfig {
  NexusAIStudioConfig config{};
  config.model = resolveModelFromEnv();
  config.baseUrl = resolveBaseUrlFromEnv();

  std::ifstream in{std::string(path)};
  if (!in) {
    return config;
  }

  nlohmann::json root{};
  try {
    in >> root;
  } catch (const std::exception&) {
    return config;
  }

  if (root.is_object()) {
    applyJsonObjectToConfig(root, config);
    for (const char* nestedKey : {"gemini", "aiStudio", "generativeLanguage", "googleAI"}) {
      if (root.contains(nestedKey) && root[nestedKey].is_object()) {
        applyJsonObjectToConfig(root[nestedKey], config);
      }
    }
  }

  if (config.apiKeySource == "none" && config.isConfigured()) {
    config.apiKeySource = "aistudio_json:" + trimCopy(path);
  }

  return config;
}

auto NexusAIStudioConfig::resolve() -> NexusAIStudioConfig {
  NexusAIStudioConfig config = scanDownloadsForAIStudioConfig();

  const auto [envKey, envSource] = resolveApiKeyFromEnv();
  if (!envKey.empty()) {
    config.apiKey = envKey;
    config.apiKeySource = envSource;
  }

  if (config.model.empty()) {
    config.model = resolveModelFromEnv();
  }
  if (config.baseUrl.empty()) {
    config.baseUrl = resolveBaseUrlFromEnv();
  }

  return config;
}

auto resolvedGeminiApiKey() -> std::string {
  return NexusAIStudioConfig::resolve().apiKey;
}

} // namespace nexus::ai
