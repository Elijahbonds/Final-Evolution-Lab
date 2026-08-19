// Port of EFELArenaMode / FELGameModeBase venue tables for NEXUS ship.
// NEXUS runtime resolves venues via `venueToken` + `nexusMeshPath` under `assets/nexus/imported/`.
// `legacyUeMapAlias` retains archived UE `/Game/FEL/Maps/*` strings for vault JSON compat only.
#pragma once

#include <nlohmann/json.hpp>

#include <cstdint>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <vector>

namespace nexus::gameplay {

enum class ArenaReleaseState : std::uint8_t {
  kProduction = 0,
  kStaging = 1,
  kPreview = 2,
  kNonGameModule = 3,
};

/// Canonical production mode ids — keep in sync with `scripts/nexus_validate_production_modes.sh`.
inline constexpr std::string_view kProductionModeIds[] = {
    "basketball_h2h",  "basketball_dunk", "basketball_3v3", "court_carnival",
    "karate_h2h",      "karate_endless",  "baseball",       "football",
    "soccer",          "golf",            "tennis",         "volleyball",
    "gymnastics",      "surfing",         "skateboarding",  "snowboarding",
    "brain_brawl",     "who_scene_it",
};

inline constexpr std::size_t kProductionModeCount = sizeof(kProductionModeIds) / sizeof(kProductionModeIds[0]);

struct ArenaModeConfig {
  std::string_view id;
  std::string_view displayName;
  std::string_view venueToken;
  std::string_view vaultDisplayMode;
  /// NEXUS ship mesh — relative to repo root, typically `*_mobile.nexusmesh.json`.
  std::string_view nexusMeshPath;
  /// Archived UE map alias for vault / legacy JSON only — not loaded by NEXUS runtime.
  std::string_view legacyUeMapAlias;
  std::string_view inputScheme;
  float modeWeight{1.0F};
  float defaultMatchDurationSeconds{300.0F};
  bool scoringEnabled{true};
  ArenaReleaseState releaseState{ArenaReleaseState::kProduction};
};

class ArenaModeRegistry {
public:
  [[nodiscard]] static auto allModes() -> std::span<const ArenaModeConfig>;
  [[nodiscard]] static auto find(std::string_view modeId) -> std::optional<ArenaModeConfig>;
  [[nodiscard]] static auto productionModes() -> std::vector<ArenaModeConfig>;
  [[nodiscard]] static auto venueTokenForMode(std::string_view modeId) -> std::string;
  [[nodiscard]] static auto vaultDisplayModeForMode(std::string_view modeId) -> std::string;
  [[nodiscard]] static auto nexusMeshPathForMode(std::string_view modeId) -> std::string;
  [[nodiscard]] static auto legacyUeMapAliasForMode(std::string_view modeId) -> std::string;
  [[nodiscard]] static auto modeToJson(const ArenaModeConfig& config) -> nlohmann::json;
};

} // namespace nexus::gameplay
