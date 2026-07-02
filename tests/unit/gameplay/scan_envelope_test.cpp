#include "nexus/gameplay/gameplay_application.h"
#include "nexus/gameplay/scan_envelope_mapper.h"

#include "nexus/creative/voxel_world.h"
#include "nexus/creative/world_manipulator.h"

#include <cstdio>
#include <cstdlib>
#include <string>

namespace {

void require(bool condition, const char* message) {
  if (!condition) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    std::exit(1);
  }
}

void scan_envelope_maps_to_fitness_and_generative_params() {
  const nlohmann::json envelope = {
      {"schema_version", 1},
      {"scan_id", "unit_scan_001"},
      {"source", "simulated"},
      {"confidence01", 0.82},
      {"joints",
       {
           {"left_knee_angle_deg", 98.0},
           {"right_knee_angle_deg", 102.0},
           {"left_shoulder_reach01", 0.74},
           {"right_shoulder_reach01", 0.71},
           {"hip_stability01", 0.88},
       }},
      {"motion",
       {
           {"vertical_estimate_inches", 28.5},
           {"flight_time_seconds", 0.58},
           {"peak_accel_g", 1.35},
       }},
      {"frc_proxies",
       {
           {"mobility01", 0.72},
           {"active_range01", 0.68},
           {"control01", 0.81},
       }},
  };

  const auto mapped = nexus::gameplay::mapScanEnvelope(envelope);
  require(mapped.isOk(), "scan envelope maps");
  require(mapped.value().frc.mobilityScore == 0.72F, "frc mobility from envelope");
  require(mapped.value().generative.difficultyTier >= 2, "high reach/control -> tier 2+");
  require(mapped.value().generative.arenaScale >= 0.85F &&
              mapped.value().generative.arenaScale <= 1.15F,
          "arena scale clamped");
  require(mapped.value().generative.recommendedModeId == "basketball_dunk",
          "vertical drives dunk mode");
}

void scan_envelope_to_command_json_includes_fitness_and_fill_region() {
  const nlohmann::json envelope = {
      {"schema_version", 1},
      {"source", "vision_camera"},
      {"confidence01", 0.65},
      {"joints",
       {
           {"left_knee_angle_deg", 130.0},
           {"right_knee_angle_deg", 128.0},
           {"left_shoulder_reach01", 0.55},
           {"right_shoulder_reach01", 0.52},
       }},
      {"motion",
       {
           {"vertical_estimate_inches", 20.0},
           {"flight_time_seconds", 0.42},
       }},
  };

  const auto commandJson = nexus::gameplay::scanEnvelopeToCommandJson(envelope);
  require(commandJson.isOk(), "command json built");
  require(commandJson.value().contains("commands"), "commands array present");
  const auto& commands = commandJson.value()["commands"];
  require(commands.is_array() && commands.size() == 3, "three commands emitted");

  bool hasFitness = false;
  bool hasFill = false;
  bool hasArena = false;
  for (const auto& entry : commands) {
    const std::string cmd = entry.value("command", std::string{});
    if (cmd == "fel.fitness.update") {
      hasFitness = true;
      require(entry["params"].contains("frc_mobility"), "fitness params include frc_mobility");
    }
    if (cmd == "fel.creative.fill_region") {
      hasFill = true;
      require(entry["params"].contains("min"), "fill_region has min");
      require(entry["params"].contains("max"), "fill_region has max");
    }
    if (cmd == "fel.generate.arena_from_scan") {
      hasArena = true;
    }
  }
  require(hasFitness && hasFill && hasArena, "expected command triple present");
  require(commandJson.value()["generative"].contains("arena_scale"), "generative arena_scale");
}

void arena_from_scan_command_applies_fitness_and_voxels() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);

  const nlohmann::json envelope = {
      {"schema_version", 1},
      {"source", "coremotion"},
      {"confidence01", 0.55},
      {"joints",
       {
           {"left_knee_angle_deg", 145.0},
           {"right_knee_angle_deg", 142.0},
           {"left_shoulder_reach01", 0.48},
           {"right_shoulder_reach01", 0.46},
       }},
      {"motion",
       {
           {"vertical_estimate_inches", 22.0},
           {"flight_time_seconds", 0.40},
           {"peak_accel_g", 0.95},
       }},
  };

  const auto response = gameplay.handleGameplayCommand("fel.generate.arena_from_scan", envelope, "scan_test");
  require(response.status == "ok", "arena_from_scan ok");
  require(response.payload.contains("fitness"), "response includes fitness");
  require(response.payload.contains("generative"), "response includes generative");
  require(response.payload.contains("creative"), "response includes creative");
  require(response.payload["commands_applied"].is_array(), "commands_applied array");

  const auto fitness = gameplay.fitness_data().snapshot();
  require(fitness.revision == 1, "fitness revision incremented");
  require(fitness.frc.mobilityScore > 0.0F, "mobility applied from scan");

  const int material = response.payload["generative"]["voxel_material"].get<int>();
  require(world.voxelAt({0, 0, 0}).material == material, "center voxel painted");
}

void invalid_scan_envelope_returns_error() {
  const auto mapped = nexus::gameplay::mapScanEnvelope(nlohmann::json::array());
  require(mapped.isErr(), "non-object envelope rejected");

  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  const auto response =
      gameplay.handleGameplayCommand("fel.generate.arena_from_scan", {{"schema_version", 99}}, "bad");
  require(response.status == "error", "unsupported schema rejected");
}

} // namespace

int main() {
  scan_envelope_maps_to_fitness_and_generative_params();
  scan_envelope_to_command_json_includes_fitness_and_fill_region();
  arena_from_scan_command_applies_fitness_and_voxels();
  invalid_scan_envelope_returns_error();
  std::fprintf(stdout, "PASS: scan_envelope_test\n");
  return 0;
}
