#include "nexus/ai/game_prompt_adapter.h"

#include "nexus/ai/gemini_game_prompt_client.h"
#include "nexus/ai/nexus_ai_studio_config.h"
#include "nexus/gameplay/arena_mode_registry.h"

#include <algorithm>
#include <array>
#include <cctype>
#include <chrono>
#include <string_view>

namespace nexus::ai {

namespace {

using nexus::gameplay::ArenaModeConfig;
using nexus::gameplay::ArenaModeRegistry;

struct ModeKeywordRule {
  std::string_view modeId;
  std::initializer_list<std::string_view> keywords;
};

/// Ordered most-specific-first — first match wins (18 playable modes).
constexpr std::array<ModeKeywordRule, 19> kModeKeywordRules{{
    {"basketball_dunk", {"dunk contest", "slam dunk", "slam", "jam", "dunk"}},
    {"basketball_3v3", {"3v3", "three on three", "streetball"}},
    {"basketball_h2h", {"head to head", "h2h", "1v1 basketball", "venice pickup", "pickup game",
                        "one on one"}},
    {"court_carnival", {"court carnival", "trick shot party", "party mode", "carnival", "trick shot"}},
    {"karate_endless", {"karate endless", "endless karate", "endless wave", "wave survival"}},
    {"karate_h2h", {"karate 1v1", "karate sparring", "dojo duel", "karate", "dojo", "kata"}},
    {"who_scene_it", {"who scene", "scene it", "film quiz", "movie quiz"}},
    {"brain_brawl", {"brain brawl", "neuro quiz", "trivia brawl", "trivia", "quiz"}},
    {"baseball", {"home run derby", "home run", "baseball", "batter"}},
    {"football", {"kick return", "gridiron", "touchdown", "football"}},
    {"soccer", {"penalty shootout", "penalty kick", "soccer", "futbol"}},
    {"golf", {"closest to pin", "fairway", "putt", "golf", "links"}},
    {"volleyball", {"volleyball", "sand court", "spike set", "volleyball rally"}},
    {"tennis", {"tennis", "tennis rally", "backhand", "serve ace"}},
    {"gymnastics", {"floor routine", "balance beam", "gymnastics", "vault"}},
    {"surfing", {"surf break", "surfing", "surf board", "surf"}},
    {"skateboarding", {"skate park", "skateboard", "skateboarding", "ollie"}},
    {"snowboarding", {"mountain slope", "snowboarding", "snowboard", "halfpipe"}},
    {"basketball_dunk", {"basketball court", "hoops", "basketball"}},
}};

auto toLower(std::string_view text) -> std::string {
  std::string lowered(text);
  std::transform(lowered.begin(), lowered.end(), lowered.begin(), [](unsigned char c) {
    return static_cast<char>(std::tolower(c));
  });
  return lowered;
}

auto containsAny(std::string_view haystack, std::initializer_list<std::string_view> needles)
    -> bool {
  for (const std::string_view needle : needles) {
    if (haystack.find(needle) != std::string_view::npos) {
      return true;
    }
  }
  return false;
}

auto slugifySpecId(std::string_view prompt) -> std::string {
  std::string slug = "game_";
  bool pendingUnderscore = false;
  int written = 0;
  for (unsigned char character : prompt) {
    if (std::isalnum(character) != 0) {
      slug.push_back(static_cast<char>(std::tolower(character)));
      pendingUnderscore = true;
      ++written;
    } else if (pendingUnderscore && written < 20) {
      slug.push_back('_');
      pendingUnderscore = false;
    }
    if (written >= 20) {
      break;
    }
  }
  while (!slug.empty() && slug.back() == '_') {
    slug.pop_back();
  }
  if (slug.size() <= 5) {
    slug.append("custom");
  }
  const auto now = std::chrono::system_clock::now().time_since_epoch().count();
  slug.push_back('_');
  slug.append(std::to_string(static_cast<unsigned long long>(now) % 100000ULL));
  return slug;
}

auto inferModeId(std::string_view lowered) -> std::string {
  return inferModeIdFromPrompt(lowered);
}

auto inferDifficultyTier(std::string_view lowered) -> std::string {
  if (containsAny(lowered, {"harder", "hard", "intense", "extreme", "pro", "elite", "competitive"})) {
    return "hard";
  }
  if (containsAny(lowered,
                  {"easier", "easy", "casual", "beginner", "chill", "relaxed", "normal difficulty"})) {
    return "easy";
  }
  return "normal";
}

auto inferDurationMultiplier(std::string_view lowered) -> float {
  if (containsAny(lowered, {"longer", "extended", "marathon", "endurance"})) {
    return 1.5F;
  }
  if (containsAny(lowered, {"shorter", "quick", "blitz", "sprint match"})) {
    return 0.75F;
  }
  return 1.0F;
}

auto modeWeightForDifficulty(std::string_view tier, float baseWeight) -> float {
  if (tier == "hard") {
    return baseWeight * 1.25F;
  }
  if (tier == "easy") {
    return baseWeight * 0.85F;
  }
  return baseWeight;
}

auto hudThemeForMode(const ArenaModeConfig& config, std::string_view difficultyTier)
    -> nlohmann::json {
  struct ThemePalette {
    std::string_view primary;
    std::string_view accent;
    std::string_view badge;
  };

  static constexpr std::array<std::pair<std::string_view, ThemePalette>, 10> kPalettes{{
      {"basketball", {"#FF6B00", "#00D4FF", "HOOPS"}},
      {"karate", {"#8B5CF6", "#F59E0B", "DOJO"}},
      {"court_carnival", {"#EC4899", "#FBBF24", "CARNIVAL"}},
      {"brain", {"#6366F1", "#22D3EE", "BRAIN"}},
      {"scene", {"#A855F7", "#F472B6", "SCENE"}},
      {"field", {"#22C55E", "#EAB308", "FIELD"}},
      {"precision", {"#10B981", "#F8FAFC", "PRECISION"}},
      {"board", {"#06B6D4", "#F97316", "BOARD"}},
      {"academy", {"#C084FC", "#FBBF24", "ACADEMY"}},
      {"default", {"#14B8A6", "#F97316", "ARENA"}},
  }};

  std::string_view family = "default";
  const std::string modeId(config.id);
  if (modeId.rfind("basketball", 0) == 0) {
    family = "basketball";
  } else if (modeId.rfind("karate", 0) == 0) {
    family = "karate";
  } else if (modeId == "court_carnival") {
    family = "court_carnival";
  } else if (modeId.rfind("brain", 0) == 0) {
    family = "brain";
  } else if (modeId.rfind("who_scene", 0) == 0) {
    family = "scene";
  } else if (modeId == "baseball" || modeId == "football" || modeId == "soccer") {
    family = "field";
  } else if (modeId == "golf" || modeId == "tennis" || modeId == "volleyball") {
    family = "precision";
  } else if (modeId == "surfing" || modeId == "skateboarding" || modeId == "snowboarding") {
    family = "board";
  } else if (modeId == "gymnastics") {
    family = "academy";
  }

  ThemePalette palette = kPalettes.back().second;
  for (const auto& entry : kPalettes) {
    if (entry.first == family) {
      palette = entry.second;
      break;
    }
  }

  return {
      {"primary_color", std::string(palette.primary)},
      {"accent_color", std::string(palette.accent)},
      {"badge_label", std::string(palette.badge)},
      {"mode_display_name", std::string(config.displayName)},
      {"difficulty_tier", std::string(difficultyTier)},
      {"score_bar_style", "nexus_compact"},
      {"preview_label", "PREVIEW · GENERATED GAME SPEC"},
  };
}

auto buildRules(const ArenaModeConfig& config,
                std::string_view difficultyTier,
                float durationMultiplier) -> nlohmann::json {
  const float duration = config.defaultMatchDurationSeconds * durationMultiplier;
  return {
      {"difficulty_tier", std::string(difficultyTier)},
      {"mode_weight", modeWeightForDifficulty(difficultyTier, config.modeWeight)},
      {"match_duration_seconds", duration},
      {"scoring_enabled", config.scoringEnabled},
      {"input_scheme", std::string(config.inputScheme)},
      {"combo_multiplier_cap", difficultyTier == "hard" ? 3.0F : 2.0F},
  };
}

auto wantsArenaGeneration(std::string_view lowered) -> bool {
  return containsAny(lowered,
                    {"arena", "venue", "court", "environment", "voxel", "terrain", "hoop",
                     "sand", "dojo", "stadium", "mesh", "import", "scan", "park", "slope", "floor"});
}

auto isPlayableGameMode(std::string_view modeId) -> bool {
  if (modeId.empty()) {
    return false;
  }
  const auto config = ArenaModeRegistry::find(modeId);
  return config.has_value() &&
         config->releaseState == nexus::gameplay::ArenaReleaseState::kProduction;
}

auto buildSpec(std::string_view prompt, std::string_view lowered) -> Result<GameGenerationSpec> {
  const std::string modeId = inferModeId(lowered);
  const auto config = ArenaModeRegistry::find(modeId);
  if (!config.has_value()) {
    return Result<GameGenerationSpec>::err("Unknown mode_id from prompt: " + modeId);
  }

  const std::string difficultyTier = inferDifficultyTier(lowered);
  const float durationMultiplier = inferDurationMultiplier(lowered);

  GameGenerationSpec spec{
      .specId = slugifySpecId(prompt),
      .originalPrompt = std::string(prompt),
      .modeId = modeId,
      .displayName = std::string(config->displayName),
      .venueToken = std::string(config->venueToken),
      .rules = buildRules(*config, difficultyTier, durationMultiplier),
      .hudTheme = hudThemeForMode(*config, difficultyTier),
      .arenaPrompt = wantsArenaGeneration(lowered) ? std::string(prompt) : std::string{},
      .refinementHistory = {},
      .metadata = {
          {"adapter", "template_mvp"},
          {"ai_backend", "template_mvp"},
          {"release_state", static_cast<int>(config->releaseState)},
          {"nexus_mesh_path", std::string(config->nexusMeshPath)},
          {"generator_tier", "preview"},
          {"notes",
           "Template parser — not Seele full asset synthesis. Arena mesh steps optional via "
           "fel.generate.from_text when arena_prompt is set."},
      },
  };

  return Result<GameGenerationSpec>::ok(std::move(spec));
}

auto parseGamePromptWithTemplate(std::string_view prompt, bool geminiFallback = false)
    -> Result<GameGenerationSpec> {
  const std::string trimmed(prompt);
  if (trimmed.empty()) {
    return Result<GameGenerationSpec>::err("text prompt must not be empty");
  }
  auto result = buildSpec(trimmed, toLower(trimmed));
  if (result.isOk()) {
    result.value().metadata["adapter"] = "template_mvp";
    result.value().metadata["ai_backend"] = "template_mvp";
    result.value().metadata["ai_provider"] = "template_mvp";
    result.value().metadata["generator_tier"] = "template";
    if (geminiFallback) {
      result.value().metadata["fallback_used"] = true;
    }
  }
  return result;
}

auto applyGeminiHintsToTemplateSpec(GameGenerationSpec& spec, const nlohmann::json& hints)
    -> void {
  if (hints.contains("difficulty_tier") && hints["difficulty_tier"].is_string()) {
    const std::string tier = hints["difficulty_tier"].get<std::string>();
    if (tier == "easy" || tier == "normal" || tier == "hard") {
      const auto config = ArenaModeRegistry::find(spec.modeId);
      if (config.has_value()) {
        float durationMultiplier = 1.0F;
        const std::string durationModifier = hints.value("duration_modifier", "normal");
        if (durationModifier == "longer") {
          durationMultiplier = 1.5F;
        } else if (durationModifier == "shorter") {
          durationMultiplier = 0.75F;
        }
        spec.rules = buildRules(*config, tier, durationMultiplier);
        spec.hudTheme = hudThemeForMode(*config, tier);
      }
    }
  }

  if (hints.value("wants_arena_generation", false)) {
    spec.arenaPrompt = spec.originalPrompt;
  }

  if (hints.contains("rationale") && hints["rationale"].is_string()) {
    spec.metadata["gemini_partial_rationale"] = hints["rationale"].get<std::string>();
  }
}

auto buildSpecFromGeminiHintsInternal(std::string_view prompt, const nlohmann::json& hints)
    -> Result<GameGenerationSpec> {
  const std::string trimmed(prompt);
  if (trimmed.empty()) {
    return Result<GameGenerationSpec>::err("text prompt must not be empty");
  }
  if (!hints.is_object()) {
    return Result<GameGenerationSpec>::err("Gemini hints must be a JSON object");
  }

  const std::string modeId = normalizeGameModeId(hints.value("mode_id", ""));
  if (modeId.empty()) {
    return Result<GameGenerationSpec>::err("Gemini hints missing mode_id");
  }
  if (!isPlayableGameMode(modeId)) {
    return Result<GameGenerationSpec>::err("Gemini mode_id not in registry: " + modeId);
  }

  const auto config = ArenaModeRegistry::find(modeId);
  if (!config.has_value()) {
    return Result<GameGenerationSpec>::err("Gemini mode_id not in registry: " + modeId);
  }

  std::string difficultyTier = hints.value("difficulty_tier", "normal");
  if (difficultyTier != "easy" && difficultyTier != "normal" && difficultyTier != "hard") {
    difficultyTier = "normal";
  }

  float durationMultiplier = 1.0F;
  const std::string durationModifier = hints.value("duration_modifier", "normal");
  if (durationModifier == "longer") {
    durationMultiplier = 1.5F;
  } else if (durationModifier == "shorter") {
    durationMultiplier = 0.75F;
  }

  const bool wantsArena = hints.value("wants_arena_generation", false);
  const std::string lowered = toLower(trimmed);

  GameGenerationSpec spec{
      .specId = slugifySpecId(prompt),
      .originalPrompt = trimmed,
      .modeId = modeId,
      .displayName = std::string(config->displayName),
      .venueToken = std::string(config->venueToken),
      .rules = buildRules(*config, difficultyTier, durationMultiplier),
      .hudTheme = hudThemeForMode(*config, difficultyTier),
      .arenaPrompt = wantsArena || wantsArenaGeneration(lowered) ? trimmed : std::string{},
      .refinementHistory = {},
      .metadata = {
          {"adapter", "ai_studio_assisted"},
          {"ai_backend", "google_ai_studio"},
          {"ai_provider", "ai_studio"},
          {"release_state", static_cast<int>(config->releaseState)},
          {"nexus_mesh_path", std::string(config->nexusMeshPath)},
          {"generator_tier", "ai_studio_assisted"},
          {"gemini_rationale", hints.value("rationale", std::string{})},
          {"fallback_used", false},
          {"notes",
           "Google AI Studio Gemini REST — registry-validated mode/venue/rules. Arena mesh steps "
           "optional via fel.generate.from_text when arena_prompt is set."},
      },
  };

  return Result<GameGenerationSpec>::ok(std::move(spec));
}

} // namespace

auto normalizeGameModeId(std::string_view modeId) -> std::string {
  const std::string lowered = toLower(modeId);
  if (lowered == "venice_pickup" || lowered == "pickup" || lowered == "pickup_basketball") {
    return "basketball_h2h";
  }
  if (lowered == "karate_kata" || lowered == "kata_endless") {
    return "karate_endless";
  }
  if (lowered == "karate_1v1" || lowered == "karate_duel") {
    return "karate_h2h";
  }
  if (lowered == "market_browse" || lowered == "module_library" || lowered == "vault_shop") {
    return "";
  }
  if (const auto config = nexus::gameplay::ArenaModeRegistry::find(lowered);
      config.has_value() && config->releaseState != nexus::gameplay::ArenaReleaseState::kProduction) {
    return "";
  }
  return lowered;
}

auto inferModeIdFromPrompt(std::string_view loweredPrompt) -> std::string {
  for (const ModeKeywordRule& rule : kModeKeywordRules) {
    if (containsAny(loweredPrompt, rule.keywords)) {
      return std::string(rule.modeId);
    }
  }
  return "basketball_dunk";
}

auto sanitizeLlmJsonText(std::string_view text) -> std::string {
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

auto normalizeGeminiGameHints(const nlohmann::json& hints, std::string_view prompt)
    -> nlohmann::json {
  nlohmann::json normalized = hints.is_object() ? hints : nlohmann::json::object();

  std::string modeId;
  if (normalized.contains("mode_id") && normalized["mode_id"].is_string()) {
    modeId = normalizeGameModeId(normalized["mode_id"].get<std::string>());
  }
  if (modeId.empty() || !isPlayableGameMode(modeId)) {
    modeId = inferModeIdFromPrompt(toLower(prompt));
  }
  normalized["mode_id"] = modeId;

  std::string difficultyTier = normalized.value("difficulty_tier", "normal");
  if (difficultyTier != "easy" && difficultyTier != "normal" && difficultyTier != "hard") {
    difficultyTier = inferDifficultyTier(toLower(prompt));
  }
  normalized["difficulty_tier"] = difficultyTier;

  if (!normalized.contains("wants_arena_generation")) {
    normalized["wants_arena_generation"] = wantsArenaGeneration(toLower(prompt));
  }

  if (!normalized.contains("duration_modifier")) {
    const std::string lowered = toLower(prompt);
    if (containsAny(lowered, {"longer", "extended", "marathon"})) {
      normalized["duration_modifier"] = "longer";
    } else if (containsAny(lowered, {"shorter", "quick", "blitz"})) {
      normalized["duration_modifier"] = "shorter";
    } else {
      normalized["duration_modifier"] = "normal";
    }
  }

  return normalized;
}

auto buildSpecFromGeminiHints(std::string_view prompt, const nlohmann::json& hints)
    -> Result<GameGenerationSpec> {
  return buildSpecFromGeminiHintsInternal(prompt, hints);
}

auto GameGenerationSpec::toJson() const -> nlohmann::json {
  nlohmann::json history = nlohmann::json::array();
  for (const std::string& entry : refinementHistory) {
    history.push_back(entry);
  }

  return {
      {"spec_id", specId},
      {"original_prompt", originalPrompt},
      {"mode_id", modeId},
      {"display_name", displayName},
      {"venue_token", venueToken},
      {"rules", rules},
      {"hud_theme", hudTheme},
      {"arena_prompt", arenaPrompt},
      {"refinement_history", std::move(history)},
      {"metadata", metadata},
      {"export_path_hint", "NexusStudio/sandbox/generated_games/" + specId + ".json"},
  };
}

auto parseGamePrompt(std::string_view prompt, GamePromptAdapterOptions options)
    -> Result<GameGenerationSpec> {
  const std::string trimmed(prompt);
  if (trimmed.empty()) {
    return Result<GameGenerationSpec>::err("text prompt must not be empty");
  }

  if (!options.forceTemplate) {
    const NexusAIStudioConfig studioConfig = [&options]() {
      NexusAIStudioConfig config = NexusAIStudioConfig::resolve();
      if (!options.geminiApiKey.empty()) {
        config.apiKey = options.geminiApiKey;
        config.apiKeySource = "options_override";
      }
      if (!options.geminiModel.empty()) {
        config.model = options.geminiModel;
      }
      return config;
    }();

    if (studioConfig.isConfigured()) {
      GeminiGamePromptClientOptions geminiOptions{
          .apiKey = studioConfig.apiKey,
          .model = studioConfig.model,
          .baseUrl = studioConfig.baseUrl,
      };
      const auto hintsResult = requestGeminiGamePromptHints(trimmed, geminiOptions);
      if (hintsResult.isOk()) {
        const auto normalizedHints = normalizeGeminiGameHints(hintsResult.value(), trimmed);
        const auto geminiSpec = buildSpecFromGeminiHints(trimmed, normalizedHints);
        if (geminiSpec.isOk()) {
          auto spec = geminiSpec.value();
          spec.metadata["ai_studio_key_source"] = studioConfig.apiKeySource;
          spec.metadata["ai_studio_model"] = studioConfig.model;
          return Result<GameGenerationSpec>::ok(std::move(spec));
        }

        auto fallback = parseGamePromptWithTemplate(trimmed, true);
        if (fallback.isOk()) {
          applyGeminiHintsToTemplateSpec(fallback.value(), normalizedHints);
          fallback.value().metadata["ai_studio_attempted"] = true;
          fallback.value().metadata["gemini_attempted"] = true;
          fallback.value().metadata["ai_studio_fallback_reason"] = geminiSpec.error();
          fallback.value().metadata["gemini_fallback_reason"] = geminiSpec.error();
          fallback.value().metadata["adapter"] = "template_mvp";
          fallback.value().metadata["ai_backend"] = "template_mvp";
          fallback.value().metadata["generator_tier"] = "template_ai_studio_partial";
        }
        return fallback;
      }

      auto fallback = parseGamePromptWithTemplate(trimmed, true);
      if (fallback.isOk()) {
        fallback.value().metadata["ai_studio_attempted"] = true;
        fallback.value().metadata["gemini_attempted"] = true;
        fallback.value().metadata["ai_studio_fallback_reason"] = hintsResult.error();
        fallback.value().metadata["gemini_fallback_reason"] = hintsResult.error();
        fallback.value().metadata["ai_backend"] = "template_mvp";
      }
      return fallback;
    }
  }

  return parseGamePromptWithTemplate(trimmed, false);
}

auto refineGameSpec(const GameGenerationSpec& base, std::string_view refinementText)
    -> Result<GameGenerationSpec> {
  const std::string trimmed(refinementText);
  if (trimmed.empty()) {
    return Result<GameGenerationSpec>::err("refinement text must not be empty");
  }

  GameGenerationSpec refined = base;
  const std::string lowered = toLower(trimmed);
  refined.refinementHistory.push_back(trimmed);

  const std::string combinedContext = base.originalPrompt + " " + trimmed;
  const std::string refinementMode = inferModeIdFromPrompt(lowered);
  const std::string combinedMode = inferModeIdFromPrompt(toLower(combinedContext));
  if (refinementMode != combinedMode && refinementMode != "basketball_dunk") {
    refined.modeId = refinementMode;
  } else if (combinedMode != "basketball_dunk") {
    refined.modeId = combinedMode;
  } else {
    refined.modeId = base.modeId;
  }

  const auto config = ArenaModeRegistry::find(refined.modeId);
  if (!config.has_value()) {
    return Result<GameGenerationSpec>::err("Refinement produced unknown mode: " + refined.modeId);
  }

  refined.displayName = std::string(config->displayName);
  refined.venueToken = std::string(config->venueToken);
  refined.metadata["nexus_mesh_path"] = std::string(config->nexusMeshPath);
  refined.metadata["release_state"] = static_cast<int>(config->releaseState);

  std::string difficultyTier = refined.rules.value("difficulty_tier", "normal");
  if (containsAny(lowered, {"harder", "hard", "intense", "extreme", "elite", "competitive"})) {
    difficultyTier = "hard";
  } else if (containsAny(lowered, {"easier", "easy", "casual", "beginner", "relaxed"})) {
    difficultyTier = "easy";
  }

  float durationMultiplier = 1.0F;
  if (containsAny(lowered, {"longer", "extended", "marathon"})) {
    durationMultiplier = 1.5F;
  } else if (containsAny(lowered, {"shorter", "quick", "blitz"})) {
    durationMultiplier = 0.75F;
  }

  refined.rules = buildRules(*config, difficultyTier, durationMultiplier);
  refined.hudTheme = hudThemeForMode(*config, difficultyTier);
  refined.hudTheme["difficulty_tier"] = difficultyTier;

  if (wantsArenaGeneration(lowered)) {
    refined.arenaPrompt = trimmed;
  }

  refined.specId = base.specId + "_ref" + std::to_string(refined.refinementHistory.size());
  refined.metadata["adapter"] = base.metadata.value("adapter", "template_mvp");
  refined.metadata["ai_provider"] = base.metadata.value("ai_provider", "template_mvp");
  refined.metadata["generator_tier"] = base.metadata.value("generator_tier", "preview");
  return Result<GameGenerationSpec>::ok(std::move(refined));
}

auto gameSpecFromJson(const nlohmann::json& json) -> Result<GameGenerationSpec> {
  if (!json.is_object()) {
    return Result<GameGenerationSpec>::err("game spec must be a JSON object");
  }

  GameGenerationSpec spec{};
  spec.specId = json.value("spec_id", "");
  spec.originalPrompt = json.value("original_prompt", "");
  spec.modeId = normalizeGameModeId(json.value("mode_id", ""));
  spec.displayName = json.value("display_name", "");
  spec.venueToken = json.value("venue_token", "");
  spec.rules = json.contains("rules") && json["rules"].is_object() ? json["rules"]
                                                                   : nlohmann::json::object();
  spec.hudTheme = json.contains("hud_theme") && json["hud_theme"].is_object() ? json["hud_theme"]
                                                                              : nlohmann::json::object();
  spec.arenaPrompt = json.value("arena_prompt", "");
  spec.metadata = json.contains("metadata") && json["metadata"].is_object() ? json["metadata"]
                                                                            : nlohmann::json::object();

  if (json.contains("refinement_history") && json["refinement_history"].is_array()) {
    for (const auto& entry : json["refinement_history"]) {
      if (entry.is_string()) {
        spec.refinementHistory.push_back(entry.get<std::string>());
      }
    }
  }

  if (spec.modeId.empty()) {
    return Result<GameGenerationSpec>::err("game spec missing mode_id");
  }
  if (spec.specId.empty()) {
    spec.specId = slugifySpecId(spec.originalPrompt.empty() ? spec.modeId : spec.originalPrompt);
  }

  return Result<GameGenerationSpec>::ok(std::move(spec));
}

} // namespace nexus::ai
