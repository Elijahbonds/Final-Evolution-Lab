#include "nexus/gameplay/exercise_demo_pipeline.h"

#include "nexus/gameplay/arena_mode_registry.h"

#include <array>

namespace nexus::gameplay {

namespace {

struct DemoEntry {
  std::string_view modeId;
  std::string_view moduleId;
  std::string_view montageSuffix;
  std::string_view displayLabel;
};

constexpr std::array<DemoEntry, kProductionModeCount> kProductionDemoEntries{{
    {"basketball_h2h", "mod1", "Intro", "Court IQ Warmup"},
    {"basketball_dunk", "mod2", "HangTime", "Hang Time Prep"},
    {"basketball_3v3", "mod3", "TeamFlow", "Team Flow Drill"},
    {"karate_h2h", "mod4", "Stance", "Stance & Strike"},
    {"karate_endless", "mod5", "Endurance", "Endurance Kata"},
    {"baseball", "mod6", "Swing", "Rotational Power"},
    {"football", "mod7", "Sprint", "Explosive Drive"},
    {"soccer", "mod8", "Kick", "Kick Mechanics"},
    {"golf", "mod9", "Rotation", "Torso Rotation"},
    {"tennis", "mod10", "Serve", "Serve Chain"},
    {"volleyball", "mod11", "Jump", "Vertical Jump"},
    {"surfing", "mod12", "Balance", "Balance Line"},
    {"gymnastics", "mod13", "Landing", "Landing Control"},
    {"skateboarding", "mod14", "TrickFlow", "Trick Flow"},
    {"snowboarding", "mod15", "Edge", "Edge Control"},
    {"brain_brawl", "mod16", "Cognition", "Cognition Primer"},
    {"who_scene_it", "mod17", "SceneRecall", "Scene Recall"},
    {"court_carnival", "mod18", "PartyFlow", "Party Flow"},
}};

[[nodiscard]] auto findEntry(std::string_view modeId) -> const DemoEntry* {
  for (const DemoEntry& entry : kProductionDemoEntries) {
    if (entry.modeId == modeId) {
      return &entry;
    }
  }
  return nullptr;
}

[[nodiscard]] auto montagePathFor(const DemoEntry& entry) -> std::string {
  return std::string("/Game/FEL/Academy/Modules/") + std::string(entry.moduleId) +
         "/MONT_" + std::string(entry.moduleId) + "_" + std::string(entry.montageSuffix);
}

} // namespace

auto ExerciseDemoPipeline::mappingForMode(std::string_view modeId)
    -> std::optional<ExerciseDemoMapping> {
  if (const DemoEntry* entry = findEntry(modeId)) {
    return ExerciseDemoMapping{
        .moduleId = std::string(entry->moduleId),
        .montagePath = montagePathFor(*entry),
        .displayLabel = std::string(entry->displayLabel),
    };
  }
  return std::nullopt;
}

auto ExerciseDemoPipeline::mappingJson(std::string_view modeId) -> nlohmann::json {
  if (const auto mapping = mappingForMode(modeId)) {
    return {
        {"mode_id", std::string(modeId)},
        {"module_id", mapping->moduleId},
        {"montage_path", mapping->montagePath},
        {"display_label", mapping->displayLabel},
    };
  }
  return {
      {"mode_id", std::string(modeId)},
      {"module_id", nullptr},
      {"montage_path", nullptr},
      {"display_label", nullptr},
      {"note", "No academy montage mapped — staging/preview/non-game mode"},
  };
}

auto ExerciseDemoPipeline::allProductionMappings() -> nlohmann::json {
  nlohmann::json entries = nlohmann::json::array();
  for (const DemoEntry& entry : kProductionDemoEntries) {
    entries.push_back({
        {"mode_id", std::string(entry.modeId)},
        {"module_id", std::string(entry.moduleId)},
        {"montage_path", montagePathFor(entry)},
        {"display_label", std::string(entry.displayLabel)},
    });
  }
  return {{"production_demo_mappings", std::move(entries)},
          {"count", kProductionDemoEntries.size()}};
}

} // namespace nexus::gameplay
