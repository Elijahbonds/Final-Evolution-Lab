// File: app/gameplay/src/voxel_command_parser.cpp
// Part of: Final Evolution Lab (FEL) Game Logic
// Spec: 04 Creative Mode Protocol, 10 Phase 4 Creative Mode
#include "nexus/gameplay/voxel_command_parser.h"

#include "nexus/core/log.h"
#include "nexus/creative/voxel_world.h"
#include "nexus/creative/world_manipulator.h"

#include <algorithm>
#include <array>
#include <string>

namespace nexus::gameplay {

namespace {

constexpr int kMaxCreativeRadius = 16;
constexpr int kDefaultTerrainMaterial = 1;

auto parsePosition(const nlohmann::json& params) -> Result<std::array<int, 3>> {
  const auto positionIt = params.find("position");
  if (positionIt == params.end() || !positionIt->is_array() || positionIt->size() != 3) {
    return Result<std::array<int, 3>>::err("creative command requires position [x, y, z]");
  }
  if (!(*positionIt)[0].is_number_integer() || !(*positionIt)[1].is_number_integer() ||
      !(*positionIt)[2].is_number_integer()) {
    return Result<std::array<int, 3>>::err("creative command position values must be integers");
  }
  return Result<std::array<int, 3>>::ok({
      (*positionIt)[0].get<int>(),
      (*positionIt)[1].get<int>(),
      (*positionIt)[2].get<int>(),
  });
}

auto integerParam(const nlohmann::json& params,
                  std::string_view name,
                  int defaultValue) -> Result<int> {
  const auto found = params.find(std::string(name));
  if (found == params.end()) {
    return Result<int>::ok(defaultValue);
  }
  if (!found->is_number_integer()) {
    return Result<int>::err("creative command integer parameter has invalid type");
  }
  return Result<int>::ok(found->get<int>());
}

auto materialParam(const nlohmann::json& params) -> Result<int> {
  auto material = integerParam(params, "material", kDefaultTerrainMaterial);
  if (material.isErr()) {
    return material;
  }
  if (material.value() < 0 || material.value() > 65535) {
    return Result<int>::err("creative material must be between 0 and 65535");
  }
  return material;
}

auto solidVoxel(int material) -> nlohmann::json {
  return {{"material", material}, {"solid", material != 0}};
}

auto fillParams(std::array<int, 3> minPosition,
                std::array<int, 3> maxPosition,
                int material) -> nlohmann::json {
  return {
      {"min", minPosition},
      {"max", maxPosition},
      {"voxel", solidVoxel(material)},
  };
}

void logCreativeCommand(std::string_view command) {
  const std::string message = "LLM creative command applied: " + std::string(command);
  NEXUS_LOG_INFO(LogChannel::kCreative, message);
}

} // namespace

VoxelCommandParser::VoxelCommandParser(creative::WorldManipulator& manipulator,
                                         const creative::VoxelWorld& world)
    : m_manipulator(manipulator), m_world(world) {}

auto VoxelCommandParser::apply_command(std::string_view command, const nlohmann::json& params)
    -> Result<nlohmann::json> {
  if (command == "fel.creative.set_voxels") {
    logCreativeCommand(command);
    return m_manipulator.applyCommand("terrain.set_voxels", params);
  }
  if (command == "fel.creative.fill_region") {
    logCreativeCommand(command);
    return m_manipulator.applyCommand("terrain.fill_region", params);
  }
  if (command == "fel.creative.raise_terrain") {
    return apply_raise_or_lower(true, params);
  }
  if (command == "fel.creative.lower_terrain") {
    return apply_raise_or_lower(false, params);
  }
  if (command == "fel.creative.flatten_terrain") {
    return apply_flatten(params);
  }
  if (command == "fel.creative.paint_terrain") {
    return apply_paint(params);
  }

  return Result<nlohmann::json>::err("Unsupported FEL creative command");
}

auto VoxelCommandParser::apply_raise_or_lower(bool raise, const nlohmann::json& params)
    -> Result<nlohmann::json> {
  auto position = parsePosition(params);
  auto radius = integerParam(params, "radius", 1);
  auto height = integerParam(params, "height", 1);
  auto material = materialParam(params);
  if (position.isErr()) {
    return Result<nlohmann::json>::err(position.error());
  }
  if (radius.isErr()) {
    return Result<nlohmann::json>::err(radius.error());
  }
  if (height.isErr()) {
    return Result<nlohmann::json>::err(height.error());
  }
  if (material.isErr()) {
    return Result<nlohmann::json>::err(material.error());
  }

  const int clampedRadius = std::clamp(radius.value(), 0, kMaxCreativeRadius);
  const int clampedHeight = std::clamp(height.value(), 1, kMaxCreativeRadius);
  const int minY = raise ? position.value()[1] : position.value()[1] - clampedHeight + 1;
  const int maxY = raise ? position.value()[1] + clampedHeight - 1 : position.value()[1];
  const int fillMaterial = raise ? material.value() : 0;

  logCreativeCommand(raise ? "fel.creative.raise_terrain" : "fel.creative.lower_terrain");
  return m_manipulator.applyCommand(
      "terrain.fill_region",
      fillParams({position.value()[0] - clampedRadius, minY, position.value()[2] - clampedRadius},
                 {position.value()[0] + clampedRadius, maxY, position.value()[2] + clampedRadius},
                 fillMaterial));
}

auto VoxelCommandParser::apply_flatten(const nlohmann::json& params) -> Result<nlohmann::json> {
  auto position = parsePosition(params);
  auto radius = integerParam(params, "radius", 1);
  auto material = materialParam(params);
  if (position.isErr()) {
    return Result<nlohmann::json>::err(position.error());
  }
  if (radius.isErr()) {
    return Result<nlohmann::json>::err(radius.error());
  }
  if (material.isErr()) {
    return Result<nlohmann::json>::err(material.error());
  }

  const int clampedRadius = std::clamp(radius.value(), 0, kMaxCreativeRadius);
  const int x = position.value()[0];
  const int y = position.value()[1];
  const int z = position.value()[2];

  logCreativeCommand("fel.creative.flatten_terrain");
  auto clearAbove = m_manipulator.applyCommand(
      "terrain.fill_region",
      fillParams({x - clampedRadius, y + 1, z - clampedRadius},
                 {x + clampedRadius, y + kMaxCreativeRadius, z + clampedRadius},
                 0));
  if (clearAbove.isErr()) {
    return clearAbove;
  }

  return m_manipulator.applyCommand(
      "terrain.fill_region",
      fillParams({x - clampedRadius, y, z - clampedRadius},
                 {x + clampedRadius, y, z + clampedRadius},
                 material.value()));
}

auto VoxelCommandParser::apply_paint(const nlohmann::json& params) -> Result<nlohmann::json> {
  auto position = parsePosition(params);
  auto radius = integerParam(params, "radius", 1);
  auto material = materialParam(params);
  if (position.isErr()) {
    return Result<nlohmann::json>::err(position.error());
  }
  if (radius.isErr()) {
    return Result<nlohmann::json>::err(radius.error());
  }
  if (material.isErr()) {
    return Result<nlohmann::json>::err(material.error());
  }

  const int clampedRadius = std::clamp(radius.value(), 0, kMaxCreativeRadius);
  const int x = position.value()[0];
  const int y = position.value()[1];
  const int z = position.value()[2];

  nlohmann::json voxels = nlohmann::json::array();
  for (int dz = -clampedRadius; dz <= clampedRadius; ++dz) {
    for (int dx = -clampedRadius; dx <= clampedRadius; ++dx) {
      const creative::Vec3i voxelPosition{x + dx, y, z + dz};
      const auto existing = m_world.voxelAt(voxelPosition);
      if (!existing.solid) {
        continue;
      }
      voxels.push_back({
          {"position", {voxelPosition.x, voxelPosition.y, voxelPosition.z}},
          {"voxel", {{"material", material.value()}, {"solid", true}}},
      });
    }
  }

  if (voxels.empty()) {
    return Result<nlohmann::json>::ok({
        {"edited_voxels", 0},
        {"painted_voxels", 0},
    });
  }

  logCreativeCommand("fel.creative.paint_terrain");
  auto painted = m_manipulator.applyCommand("terrain.set_voxels", {{"voxels", voxels}});
  if (painted.isErr()) {
    return painted;
  }
  painted.value()["painted_voxels"] = voxels.size();
  return painted;
}

} // namespace nexus::gameplay
