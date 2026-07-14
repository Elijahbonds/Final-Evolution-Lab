#include "nexus/gameplay/arena_mode_registry.h"

#include <array>
#include <string>

namespace nexus::gameplay {

namespace {

constexpr std::array<ArenaModeConfig, 20> kModes{{
    {.id = "basketball_h2h",
     .displayName = "Head to Head",
     .venueToken = "Venice_Beach_Court",
     .vaultDisplayMode = "Venice_Beach_Street",
     .nexusMeshPath = "assets/nexus/imported/venice_beach_court_model_fbx_mobile.nexusmesh.json",
     .legacyUeMapAlias = "/Game/FEL/Maps/Venice_Beach_Court",
     .inputScheme = "charge",
     .modeWeight = 1.2F,
     .defaultMatchDurationSeconds = 300.0F,
     .scoringEnabled = true,
     .releaseState = ArenaReleaseState::kProduction},
    {.id = "basketball_dunk",
     .displayName = "Dunk Contest",
     .venueToken = "Venice_Beach_Court",
     .vaultDisplayMode = "Venice_Beach_Dunk",
     .nexusMeshPath = "assets/nexus/imported/venice_beach_court_model_fbx_mobile.nexusmesh.json",
     .legacyUeMapAlias = "/Game/FEL/Maps/Venice_Beach_Court",
     .inputScheme = "charge",
     .modeWeight = 1.0F,
     .defaultMatchDurationSeconds = 300.0F,
     .scoringEnabled = true,
     .releaseState = ArenaReleaseState::kProduction},
    {.id = "basketball_3v3",
     .displayName = "3v3 Streetball",
     .venueToken = "Venice_Beach_Court",
     .vaultDisplayMode = "Venice_Beach_3v3",
     .nexusMeshPath = "assets/nexus/imported/venice_beach_court_model_fbx_mobile.nexusmesh.json",
     .legacyUeMapAlias = "/Game/FEL/Maps/Venice_Beach_Court",
     .inputScheme = "charge",
     .modeWeight = 1.3F,
     .defaultMatchDurationSeconds = 300.0F,
     .scoringEnabled = true,
     .releaseState = ArenaReleaseState::kProduction},
    {.id = "karate_h2h",
     .displayName = "Karate 1v1",
     .venueToken = "Zen_Dojo",
     .vaultDisplayMode = "Zen_Dojo_Karate",
     .nexusMeshPath = "assets/nexus/imported/zen_dojo_environment_model_fbx_mobile.nexusmesh.json",
     .legacyUeMapAlias = "/Game/FEL/Maps/Zen_Dojo",
     .inputScheme = "charge",
     .modeWeight = 1.4F,
     .defaultMatchDurationSeconds = 300.0F,
     .scoringEnabled = true,
     .releaseState = ArenaReleaseState::kProduction},
    {.id = "karate_endless",
     .displayName = "Karate: Dojo Breach",
     .venueToken = "Zen_Dojo",
     .vaultDisplayMode = "Zen_Dojo_Karate",
     .nexusMeshPath = "assets/nexus/imported/zen_dojo_environment_model_fbx_mobile.nexusmesh.json",
     .legacyUeMapAlias = "/Game/FEL/Maps/Zen_Dojo",
     .inputScheme = "charge",
     .modeWeight = 1.4F,
     .defaultMatchDurationSeconds = 300.0F,
     .scoringEnabled = true,
     .releaseState = ArenaReleaseState::kProduction},
    {.id = "baseball",
     .displayName = "Home Run Derby",
     .venueToken = "Baseball_Park",
     .vaultDisplayMode = "baseball",
     .nexusMeshPath = "assets/nexus/imported/baseball_park_environment_model_fbx_mobile.nexusmesh.json",
     .legacyUeMapAlias = "/Game/FEL/Maps/Baseball_Park",
     .inputScheme = "swipe",
     .modeWeight = 1.0F,
     .defaultMatchDurationSeconds = 300.0F,
     .scoringEnabled = true,
     .releaseState = ArenaReleaseState::kProduction},
    {.id = "football",
     .displayName = "Kick Return",
     .venueToken = "Gridiron_Stadium",
     .vaultDisplayMode = "football",
     .nexusMeshPath = "assets/nexus/imported/gridiron_stadium_environment_model_fbx_mobile.nexusmesh.json",
     .legacyUeMapAlias = "/Game/FEL/Maps/Gridiron_Stadium",
     .inputScheme = "kick_return",
     .modeWeight = 1.5F,
     .defaultMatchDurationSeconds = 300.0F,
     .scoringEnabled = true,
     .releaseState = ArenaReleaseState::kProduction},
    // venue_mesh audit id: stadium_pitch (Soccer_Stadium mobile sidecar)
    {.id = "soccer",
     .displayName = "Penalty Shootout",
     .venueToken = "Soccer_Stadium",
     .vaultDisplayMode = "soccer",
     .nexusMeshPath = "assets/nexus/imported/soccer_stadium_environment_model_fbx_mobile.nexusmesh.json",
     .legacyUeMapAlias = "/Game/FEL/Maps/Soccer_Stadium",
     .inputScheme = "penalty_kick",
     .modeWeight = 1.1F,
     .defaultMatchDurationSeconds = 300.0F,
     .scoringEnabled = true,
     .releaseState = ArenaReleaseState::kProduction},
    {.id = "golf",
     .displayName = "Closest to Pin",
     .venueToken = "Links_Course",
     .vaultDisplayMode = "golf",
     .nexusMeshPath = "assets/nexus/imported/golf_course_environment_model_fbx_mobile.nexusmesh.json",
     .legacyUeMapAlias = "/Game/FEL/Maps/Links_Course",
     .inputScheme = "swipe_golf",
     .modeWeight = 0.9F,
     .defaultMatchDurationSeconds = 300.0F,
     .scoringEnabled = true,
     .releaseState = ArenaReleaseState::kProduction},
    {.id = "tennis",
     .displayName = "Rally Ace",
     .venueToken = "Tennis_Court",
     .vaultDisplayMode = "tennis",
     .nexusMeshPath = "assets/nexus/imported/tennis_court_environment_model_fbx_mobile.nexusmesh.json",
     .legacyUeMapAlias = "/Game/FEL/Maps/Tennis_Court",
     .inputScheme = "rally_ace",
     .modeWeight = 1.1F,
     .defaultMatchDurationSeconds = 300.0F,
     .scoringEnabled = true,
     .releaseState = ArenaReleaseState::kProduction},
    {.id = "volleyball",
     .displayName = "Beach Volleyball",
     .venueToken = "Sand_Court",
     .vaultDisplayMode = "volleyball",
     .nexusMeshPath = "assets/nexus/imported/volleyball_sand_court_environment_model_fbx_mobile.nexusmesh.json",
     .legacyUeMapAlias = "/Game/FEL/Maps/Sand_Court",
     .inputScheme = "rally_ace",
     .modeWeight = 1.2F,
     .defaultMatchDurationSeconds = 300.0F,
     .scoringEnabled = true,
     .releaseState = ArenaReleaseState::kProduction},
    {.id = "gymnastics",
     .displayName = "Gymnastics",
     .venueToken = "Training_Floor",
     .vaultDisplayMode = "gymnastics",
     .nexusMeshPath = "assets/nexus/imported/gymnastics_floor_environment_model_fbx_mobile.nexusmesh.json",
     .legacyUeMapAlias = "/Game/FEL/Maps/Training_Floor",
     .inputScheme = "rhythm_tap",
     .modeWeight = 1.0F,
     .defaultMatchDurationSeconds = 300.0F,
     .scoringEnabled = true,
     .releaseState = ArenaReleaseState::kProduction},
    // Surfing: intentional venue proxy — shares Venice beach court mesh until a dedicated
    // surf-break asset exists (manifest venue_key venice_beach_surf → venice_beach_court_model_fbx).
    {.id = "surfing",
     .displayName = "Surfing",
     .venueToken = "Venice_Beach_Surf",
     .vaultDisplayMode = "Venice_Beach_Surf",
     .nexusMeshPath = "assets/nexus/imported/venice_beach_court_model_fbx_mobile.nexusmesh.json",
     .legacyUeMapAlias = "/Game/FEL/Maps/Venice_Beach_Surf",
     .inputScheme = "rhythm_tap",
     .modeWeight = 1.05F,
     .defaultMatchDurationSeconds = 300.0F,
     .scoringEnabled = true,
     .releaseState = ArenaReleaseState::kProduction},
    {.id = "skateboarding",
     .displayName = "Skateboarding",
     .venueToken = "Skate_Park",
     .vaultDisplayMode = "skateboarding",
     .nexusMeshPath = "assets/nexus/imported/skate_park_environment_model_fbx_mobile.nexusmesh.json",
     .legacyUeMapAlias = "/Game/FEL/Maps/Skate_Park",
     .inputScheme = "rhythm_tap",
     .modeWeight = 0.9F,
     .defaultMatchDurationSeconds = 180.0F,
     .scoringEnabled = true,
     .releaseState = ArenaReleaseState::kProduction},
    {.id = "snowboarding",
     .displayName = "Snowboarding",
     .venueToken = "Mountain_Slope",
     .vaultDisplayMode = "snowboarding",
     .nexusMeshPath = "assets/nexus/imported/mountain_slope_environment_model_fbx_mobile.nexusmesh.json",
     .legacyUeMapAlias = "/Game/FEL/Maps/Mountain_Slope",
     .inputScheme = "rhythm_tap",
     .modeWeight = 0.9F,
     .defaultMatchDurationSeconds = 180.0F,
     .scoringEnabled = true,
     .releaseState = ArenaReleaseState::kProduction},
    {.id = "brain_brawl",
     .displayName = "Brain Brawl",
     .venueToken = "Neuro_Arena",
     .vaultDisplayMode = "Neuro_Arena",
     .nexusMeshPath = "assets/nexus/imported/neuro_arena_environment_model_fbx_mobile.nexusmesh.json",
     .legacyUeMapAlias = "/Game/FEL/Maps/Neuro_Arena",
     .inputScheme = "rhythm_tap",
     .modeWeight = 1.0F,
     .defaultMatchDurationSeconds = 300.0F,
     .scoringEnabled = false,
     .releaseState = ArenaReleaseState::kProduction},
    {.id = "who_scene_it",
     .displayName = "Who Scene It",
     .venueToken = "Neuro_Arena",
     .vaultDisplayMode = "Neuro_Arena",
     .nexusMeshPath = "assets/nexus/imported/neuro_arena_environment_model_fbx_mobile.nexusmesh.json",
     .legacyUeMapAlias = "/Game/FEL/Maps/Neuro_Arena",
     .inputScheme = "film_quiz",
     .modeWeight = 1.1F,
     .defaultMatchDurationSeconds = 120.0F,
     .scoringEnabled = false,
     .releaseState = ArenaReleaseState::kProduction},
    {.id = "court_carnival",
     .displayName = "Court Carnival",
     .venueToken = "Venice_Beach_Court",
     .vaultDisplayMode = "Venice_Beach_Court",
     .nexusMeshPath = "assets/nexus/imported/venice_beach_court_model_fbx_mobile.nexusmesh.json",
     .legacyUeMapAlias = "/Game/FEL/Maps/Venice_Beach_Court",
     .inputScheme = "party_board",
     .modeWeight = 1.0F,
     .defaultMatchDurationSeconds = 300.0F,
     .scoringEnabled = true,
     .releaseState = ArenaReleaseState::kProduction},
    {.id = "market_browse",
     .displayName = "Module Library",
     .venueToken = "Vault_Shop",
     .vaultDisplayMode = "market_browse",
     .nexusMeshPath = "assets/nexus/imported/luma_venice_shop_environment_model_fbx_mobile.nexusmesh.json",
     .legacyUeMapAlias = "/Game/FEL/Maps/Vault_Shop",
     .inputScheme = "drag_tap",
     .modeWeight = 0.0F,
     .defaultMatchDurationSeconds = 0.0F,
     .scoringEnabled = false,
     .releaseState = ArenaReleaseState::kNonGameModule},
    // Story mode — KH1-style action RPG traversal through the expanded Venice Beach world.
    // Uses the court_carnival_story_map expanded layout (5 streaming zones, 20 board spaces).
    // Release state: kStaging until full boss fight polish + renderer integration passes.
    {.id = "story_carnival",
     .displayName = "Legends of the Boardwalk",
     .venueToken = "Venice_Beach_Court",
     .vaultDisplayMode = "Venice_Beach_Story",
     .nexusMeshPath = "assets/nexus/imported/venice_beach_court_model_fbx_mobile.nexusmesh.json",
     .legacyUeMapAlias = "/Game/FEL/Maps/Venice_Beach_Story",
     .inputScheme = "story_action",
     .modeWeight = 1.5F,
     .defaultMatchDurationSeconds = 0.0F,
     .scoringEnabled = true,
     .releaseState = ArenaReleaseState::kStaging},
}};

[[nodiscard]] auto resolveModeId(std::string_view modeId) -> std::string_view {
  if (modeId == "venice_pickup") {
    return "basketball_h2h";
  }
  if (modeId == "karate_kata") {
    return "karate_endless";
  }
  return modeId;
}

[[nodiscard]] auto lookup(std::string_view modeId) -> const ArenaModeConfig* {
  const std::string_view resolved = resolveModeId(modeId);
  for (const ArenaModeConfig& config : kModes) {
    if (config.id == resolved) {
      return &config;
    }
  }
  return nullptr;
}

} // namespace

auto ArenaModeRegistry::allModes() -> std::span<const ArenaModeConfig> {
  return kModes;
}

auto ArenaModeRegistry::find(std::string_view modeId) -> std::optional<ArenaModeConfig> {
  if (const ArenaModeConfig* found = lookup(modeId)) {
    return *found;
  }
  return std::nullopt;
}

auto ArenaModeRegistry::productionModes() -> std::vector<ArenaModeConfig> {
  std::vector<ArenaModeConfig> modes;
  for (const ArenaModeConfig& config : kModes) {
    if (config.releaseState == ArenaReleaseState::kProduction) {
      modes.push_back(config);
    }
  }
  return modes;
}

auto ArenaModeRegistry::venueTokenForMode(std::string_view modeId) -> std::string {
  if (const ArenaModeConfig* found = lookup(modeId)) {
    return std::string(found->venueToken);
  }
  return {};
}

auto ArenaModeRegistry::vaultDisplayModeForMode(std::string_view modeId) -> std::string {
  if (const ArenaModeConfig* found = lookup(modeId)) {
    return std::string(found->vaultDisplayMode);
  }
  return modeId.empty() ? "Venice_Beach_Default" : std::string(modeId);
}

auto ArenaModeRegistry::nexusMeshPathForMode(std::string_view modeId) -> std::string {
  if (const ArenaModeConfig* found = lookup(modeId)) {
    return std::string(found->nexusMeshPath);
  }
  return {};
}

auto ArenaModeRegistry::legacyUeMapAliasForMode(std::string_view modeId) -> std::string {
  if (const ArenaModeConfig* found = lookup(modeId)) {
    return std::string(found->legacyUeMapAlias);
  }
  return {};
}

auto ArenaModeRegistry::modeToJson(const ArenaModeConfig& config) -> nlohmann::json {
  return {
      {"mode_id", std::string(config.id)},
      {"display_name", std::string(config.displayName)},
      {"venue_token", std::string(config.venueToken)},
      {"vault_display_mode", std::string(config.vaultDisplayMode)},
      {"nexus_mesh_path", std::string(config.nexusMeshPath)},
      {"legacy_ue_map_alias", std::string(config.legacyUeMapAlias)},
      {"input_scheme", std::string(config.inputScheme)},
      {"mode_weight", config.modeWeight},
      {"default_match_duration_seconds", config.defaultMatchDurationSeconds},
      {"scoring_enabled", config.scoringEnabled},
      {"release_state", static_cast<int>(config.releaseState)},
  };
}

} // namespace nexus::gameplay
