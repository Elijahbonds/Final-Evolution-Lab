#include "nexus/ai/text_prompt_adapter.h"

#include <algorithm>
#include <cctype>
#include <sstream>
#include <unordered_set>

namespace nexus::ai {

namespace {

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

auto slugifyAssetId(std::string_view prompt, std::string_view prefix) -> std::string {
  std::string slug;
  slug.reserve(prefix.size() + 24);
  slug.append(prefix);
  bool pendingUnderscore = false;
  int written = 0;
  for (unsigned char character : prompt) {
    if (std::isalnum(character) != 0) {
      slug.push_back(static_cast<char>(std::tolower(character)));
      pendingUnderscore = true;
      ++written;
    } else if (pendingUnderscore && written < 24) {
      slug.push_back('_');
      pendingUnderscore = false;
    }
    if (written >= 24) {
      break;
    }
  }
  while (!slug.empty() && slug.back() == '_') {
    slug.pop_back();
  }
  if (slug.size() <= prefix.size()) {
    slug.append("arena_asset");
  }
  return slug;
}

auto inferRadius(std::string_view lowered, int defaultRadius) -> int {
  if (containsAny(lowered, {"massive", "huge", "large", "wide", "expansive"})) {
    return 8;
  }
  if (containsAny(lowered, {"small", "tiny", "compact", "narrow"})) {
    return 1;
  }
  if (containsAny(lowered, {"medium", "moderate"})) {
    return 4;
  }
  return defaultRadius;
}

auto inferHeight(std::string_view lowered, int defaultHeight) -> int {
  if (containsAny(lowered, {"tall", "high", "towering", "steep"})) {
    return 5;
  }
  if (containsAny(lowered, {"flat", "level", "shallow"})) {
    return 1;
  }
  return defaultHeight;
}

auto inferMaterial(std::string_view lowered) -> int {
  if (containsAny(lowered, {"sand", "beach", "dune"})) {
    return 7;
  }
  if (containsAny(lowered, {"grass", "field", "turf", "green"})) {
    return 2;
  }
  if (containsAny(lowered, {"rock", "stone", "granite"})) {
    return 3;
  }
  if (containsAny(lowered, {"snow", "ice"})) {
    return 9;
  }
  if (containsAny(lowered, {"water", "pool"})) {
    return 4;
  }
  if (containsAny(lowered, {"court", "floor", "concrete", "hardwood"})) {
    return 5;
  }
  return 1;
}

auto inferPosition(std::string_view lowered, std::array<int, 3> fallback) -> std::array<int, 3> {
  if (containsAny(lowered, {"north"})) {
    return {fallback[0], fallback[1], fallback[2] - 6};
  }
  if (containsAny(lowered, {"south"})) {
    return {fallback[0], fallback[1], fallback[2] + 6};
  }
  if (containsAny(lowered, {"east"})) {
    return {fallback[0] + 6, fallback[1], fallback[2]};
  }
  if (containsAny(lowered, {"west"})) {
    return {fallback[0] - 6, fallback[1], fallback[2]};
  }
  if (containsAny(lowered, {"center", "centre", "middle"})) {
    return {0, 0, 0};
  }
  return fallback;
}

auto appendTerrainSteps(std::string_view lowered,
                        std::string_view originalPrompt,
                        const TextPromptAdapterOptions& options,
                        std::vector<ParsedAgentStep>& steps) -> void {
  const auto position = inferPosition(lowered, options.defaultPosition);
  const int radius = inferRadius(lowered, options.defaultRadius);
  const int height = inferHeight(lowered, options.defaultHeight);
  const int material = inferMaterial(lowered);

  const bool wantsFlatten =
      containsAny(lowered, {"flatten", "level", "flat court", "even floor", "smooth"});
  const bool wantsLower =
      containsAny(lowered, {"lower", "dig", "depression", "pit", "crater", "sink"});
  const bool wantsRaise = containsAny(lowered,
                                      {"raise", "hill", "mound", "dune", "elevate", "ramp",
                                       "platform", "plateau", "bump", "mountain"});
  const bool wantsPaint =
      containsAny(lowered, {"paint", "color", "colour", "sand", "grass", "court", "floor"});

  if (wantsFlatten || containsAny(lowered, {"court", "arena floor", "playing surface"})) {
    steps.push_back({
        .command = "fel.creative.flatten_terrain",
        .params = {{"position", position}, {"radius", radius}, {"material", material}},
        .rationale = "Level playing surface for arena description",
    });
  }

  if (wantsLower) {
    steps.push_back({
        .command = "fel.creative.lower_terrain",
        .params = {{"position", position},
                   {"radius", radius},
                   {"height", height},
                   {"material", material}},
        .rationale = "Excavate terrain feature from prompt",
    });
  } else if (wantsRaise) {
    steps.push_back({
        .command = "fel.creative.raise_terrain",
        .params = {{"position", position},
                   {"radius", radius},
                   {"height", height},
                   {"material", material}},
        .rationale = "Raise terrain feature from prompt",
    });
  }

  if (wantsPaint && !wantsFlatten) {
    steps.push_back({
        .command = "fel.creative.paint_terrain",
        .params = {{"position", position}, {"radius", radius}, {"material", material}},
        .rationale = "Repaint existing solids to match surface material",
    });
  }

  if (steps.empty() &&
      containsAny(lowered, {"terrain", "ground", "landscape", "topography", "surface"})) {
    steps.push_back({
        .command = "fel.creative.raise_terrain",
        .params = {{"position", position},
                   {"radius", radius},
                   {"height", height},
                   {"material", material}},
        .rationale = "Default terrain sculpt for generic landscape prompt",
    });
  }

  (void)originalPrompt;
}

auto appendPropSteps(std::string_view lowered,
                     std::string_view originalPrompt,
                     const TextPromptAdapterOptions& options,
                     std::vector<ParsedAgentStep>& steps) -> void {
  struct PropKeyword {
    std::string_view keyword;
    std::string_view label;
    std::string_view kind;
  };

  static constexpr PropKeyword kPropKeywords[] = {
      {"hoop", "basketball hoop", "prop"},
      {"cone", "training cone", "prop"},
      {"bench", "sideline bench", "prop"},
      {"marker", "venue marker", "prop"},
      {"goal", "goal post", "prop"},
      {"net", "sports net", "prop"},
      {"prop", "arena prop", "prop"},
      {"obstacle", "training obstacle", "prop"},
  };

  for (const PropKeyword& keyword : kPropKeywords) {
    if (lowered.find(keyword.keyword) == std::string_view::npos) {
      continue;
    }

    const std::string assetId = slugifyAssetId(originalPrompt, options.assetIdPrefix);
    steps.push_back({
        .command = "fel.generate.create_model",
        .params = {{"prompt", std::string(keyword.label) + " from: " + std::string(originalPrompt)},
                   {"asset_id", assetId},
                   {"name", std::string(keyword.label)},
                   {"kind", std::string(keyword.kind)}},
        .rationale = "Procedural mesh job for prop noun in prompt",
    });
    break;
  }
}

auto appendEnvironmentSteps(std::string_view lowered,
                            std::string_view originalPrompt,
                            const TextPromptAdapterOptions& options,
                            std::vector<ParsedAgentStep>& steps) -> void {
  const bool wantsScanImport = containsAny(
      lowered, {"scan", "photogrammetry", "luma", "arkit", "room scan", "environment import"});
  const bool wantsVenue = containsAny(
      lowered,
      {"arena", "stadium", "venue", "environment", "park", "course", "dojo", "import venue"});
  const bool mentionsCourtSurface =
      containsAny(lowered, {"court floor", "playing surface", "hardwood", "flatten court"});

  if (!wantsScanImport && !wantsVenue) {
    return;
  }

  const std::string venueId = slugifyAssetId(originalPrompt, options.venueIdPrefix);
  std::string source = "procedural";
  std::string inputPath = "fixtures/demo_venue_marker.nexusmesh.json";
  if (containsAny(lowered, {"luma", "venice", "shop"})) {
    source = "luma";
    inputPath = "fixtures/luma_venue_stub.ply";
  } else if (containsAny(lowered, {"arkit", "room", "indoor"})) {
    source = "arkit";
    inputPath = "fixtures/arkit_room_export.usdz";
  }

  if (wantsScanImport || (wantsVenue && !mentionsCourtSurface)) {
    steps.push_back({
        .command = "fel.scan.import_environment",
        .params = {{"input_path", inputPath},
                   {"venue_id", venueId},
                   {"source", source},
                   {"name", std::string(originalPrompt)},
                   {"bounds", {{"min", {-32, 0, -32}}, {"max", {32, 8, 32}}}}},
        .rationale = wantsScanImport ? "Environment scan import from prompt"
                                     : "Venue shell import for arena description",
    });
  }
}

auto inferIntent(const std::vector<ParsedAgentStep>& steps) -> std::string {
  bool hasCreative = false;
  bool hasGenerate = false;
  bool hasScan = false;
  for (const ParsedAgentStep& step : steps) {
    if (step.command.rfind("fel.creative.", 0) == 0) {
      hasCreative = true;
    } else if (step.command.rfind("fel.generate.", 0) == 0) {
      hasGenerate = true;
    } else if (step.command.rfind("fel.scan.", 0) == 0) {
      hasScan = true;
    }
  }

  const int kinds = static_cast<int>(hasCreative) + static_cast<int>(hasGenerate) +
                    static_cast<int>(hasScan);
  if (kinds > 1) {
    return "mixed";
  }
  if (hasScan) {
    return "environment";
  }
  if (hasGenerate) {
    return "prop";
  }
  if (hasCreative) {
    return "terrain";
  }
  return "unknown";
}

} // namespace

auto TextGenerationPlan::toJson() const -> nlohmann::json {
  return planToJson(*this);
}

auto planToJson(const TextGenerationPlan& plan) -> nlohmann::json {
  nlohmann::json steps = nlohmann::json::array();
  for (const ParsedAgentStep& step : plan.steps) {
    steps.push_back({
        {"command", step.command},
        {"params", step.params},
        {"rationale", step.rationale},
    });
  }

  return {
      {"original_prompt", plan.originalPrompt},
      {"intent", plan.intent},
      {"steps", std::move(steps)},
      {"metadata", plan.metadata},
  };
}

auto parseTextPrompt(std::string_view prompt, TextPromptAdapterOptions options)
    -> Result<TextGenerationPlan> {
  const std::string trimmed(prompt);
  if (trimmed.empty()) {
    return Result<TextGenerationPlan>::err("text prompt must not be empty");
  }

  const std::string lowered = toLower(trimmed);
  TextGenerationPlan plan{
      .originalPrompt = trimmed,
      .intent = "unknown",
      .steps = {},
      .metadata = {
          {"adapter", "template_mvp"},
          {"import_pipeline", "scripts/nexus_import_assets.py"},
          {"notes",
           "External Meshy/Seele exports can be registered via nexus_import_assets.py after "
           "fel.generate.create_model completes"},
      },
  };

  appendTerrainSteps(lowered, trimmed, options, plan.steps);
  appendPropSteps(lowered, trimmed, options, plan.steps);
  appendEnvironmentSteps(lowered, trimmed, options, plan.steps);

  if (plan.steps.empty()) {
    const std::string assetId = slugifyAssetId(trimmed, options.assetIdPrefix);
    plan.steps.push_back({
        .command = "fel.generate.create_model",
        .params = {{"prompt", trimmed}, {"asset_id", assetId}, {"kind", "prop"}},
        .rationale = "Fallback procedural mesh generation for unrecognized prompt",
    });
  }

  plan.intent = inferIntent(plan.steps);
  return Result<TextGenerationPlan>::ok(std::move(plan));
}

} // namespace nexus::ai
