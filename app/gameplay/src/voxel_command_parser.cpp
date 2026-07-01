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

auto boundsJson(std::array<int, 3> minPosition, std::array<int, 3> maxPosition) -> nlohmann::json {
  return {
      {"min", minPosition},
      {"max", maxPosition},
  };
}

auto wrapCreativeEnvelope(std::string_view command,
                          const nlohmann::json& regionBounds,
                          int clampedRadius,
                          int clampedHeight,
                          const nlohmann::json& inner) -> nlohmann::json {
  const std::size_t edited = inner.value("edited_voxels", 0);
  const std::size_t chunks = inner.value("dirty_chunks", 0);
  const std::size_t painted = inner.value("painted_voxels", 0);

  std::string summary = std::string(command) + ": edited " + std::to_string(edited) +
                        " voxel(s) across " + std::to_string(chunks) + " chunk(s)";
  if (painted > 0) {
    summary += ", painted " + std::to_string(painted);
  }
  if (clampedRadius > 0) {
    summary += " (radius=" + std::to_string(clampedRadius) + ")";
  }

  nlohmann::json envelope = inner;
  envelope["creative"] = {
      {"command", std::string(command)},
      {"region_bounds", regionBounds},
      {"chunk_count", chunks},
      {"edited_voxels", edited},
      {"clamped_radius", clampedRadius},
      {"clamped_height", clampedHeight},
  };
  if (painted > 0) {
    envelope["creative"]["painted_voxels"] = painted;
  }
  envelope["agent_summary"] = summary;
  envelope["status"] = edited > 0 || painted > 0 ? "applied" : "no_op";
  return envelope;
}

} // namespace

VoxelCommandParser::VoxelCommandParser(creative::WorldManipulator& manipulator,
                                         const creative::VoxelWorld& world)
    : m_manipulator(manipulator), m_world(world) {}

auto VoxelCommandParser::apply_command(std::string_view command, const nlohmann::json& params)
    -> Result<nlohmann::json> {
  if (command == "fel.creative.set_voxels") {
    logCreativeCommand(command);
    auto result = m_manipulator.applyCommand("terrain.set_voxels", params);
    if (result.isErr()) {
      return result;
    }
    nlohmann::json bounds = nlohmann::json::object();
    if (params.contains("voxels") && params["voxels"].is_array() && !params["voxels"].empty()) {
      std::array<int, 3> minPos{0, 0, 0};
      std::array<int, 3> maxPos{0, 0, 0};
      bool initialized = false;
      for (const auto& edit : params["voxels"]) {
        if (!edit.contains("position") || !edit["position"].is_array()) {
          continue;
        }
        const std::array<int, 3> pos = {
            edit["position"][0].get<int>(),
            edit["position"][1].get<int>(),
            edit["position"][2].get<int>(),
        };
        if (!initialized) {
          minPos = pos;
          maxPos = pos;
          initialized = true;
        } else {
          for (int axis = 0; axis < 3; ++axis) {
            minPos[static_cast<std::size_t>(axis)] =
                std::min(minPos[static_cast<std::size_t>(axis)], pos[axis]);
            maxPos[static_cast<std::size_t>(axis)] =
                std::max(maxPos[static_cast<std::size_t>(axis)], pos[axis]);
          }
        }
      }
      if (initialized) {
        bounds = boundsJson(minPos, maxPos);
      }
    }
    return Result<nlohmann::json>::ok(
        wrapCreativeEnvelope(command, bounds, 0, 0, result.value()));
  }
  if (command == "fel.creative.fill_region") {
    logCreativeCommand(command);
    auto result = m_manipulator.applyCommand("terrain.fill_region", params);
    if (result.isErr()) {
      return result;
    }
    nlohmann::json bounds = nlohmann::json::object();
    if (params.contains("min") && params.contains("max")) {
      bounds = {{"min", params["min"]}, {"max", params["max"]}};
    }
    return Result<nlohmann::json>::ok(
        wrapCreativeEnvelope(command, bounds, 0, 0, result.value()));
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
  const auto minPos = std::array<int, 3>{
      position.value()[0] - clampedRadius, minY, position.value()[2] - clampedRadius};
  const auto maxPos = std::array<int, 3>{
      position.value()[0] + clampedRadius, maxY, position.value()[2] + clampedRadius};

  logCreativeCommand(raise ? "fel.creative.raise_terrain" : "fel.creative.lower_terrain");
  auto applied = m_manipulator.applyCommand("terrain.fill_region", fillParams(minPos, maxPos, fillMaterial));
  if (applied.isErr()) {
    return applied;
  }
  return Result<nlohmann::json>::ok(wrapCreativeEnvelope(
      raise ? "fel.creative.raise_terrain" : "fel.creative.lower_terrain",
      boundsJson(minPos, maxPos),
      clampedRadius,
      clampedHeight,
      applied.value()));
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
  const auto clearMin = std::array<int, 3>{x - clampedRadius, y + 1, z - clampedRadius};
  const auto clearMax = std::array<int, 3>{x + clampedRadius, y + kMaxCreativeRadius, z + clampedRadius};
  const auto floorMin = std::array<int, 3>{x - clampedRadius, y, z - clampedRadius};
  const auto floorMax = std::array<int, 3>{x + clampedRadius, y, z + clampedRadius};

  logCreativeCommand("fel.creative.flatten_terrain");
  auto clearAbove = m_manipulator.applyCommand(
      "terrain.fill_region",
      fillParams(clearMin, clearMax, 0));
  if (clearAbove.isErr()) {
    return clearAbove;
  }

  auto flattened = m_manipulator.applyCommand(
      "terrain.fill_region",
      fillParams(floorMin, floorMax, material.value()));
  if (flattened.isErr()) {
    return flattened;
  }

  nlohmann::json merged = flattened.value();
  merged["edited_voxels"] =
      clearAbove.value()["edited_voxels"].get<std::size_t>() +
      flattened.value()["edited_voxels"].get<std::size_t>();
  merged["dirty_chunks"] = flattened.value()["dirty_chunks"];
  return Result<nlohmann::json>::ok(wrapCreativeEnvelope(
      "fel.creative.flatten_terrain",
      boundsJson(floorMin, clearMax),
      clampedRadius,
      1,
      merged));
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
  const auto minPos = std::array<int, 3>{x - clampedRadius, y, z - clampedRadius};
  const auto maxPos = std::array<int, 3>{x + clampedRadius, y, z + clampedRadius};

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
    return Result<nlohmann::json>::ok(wrapCreativeEnvelope(
        "fel.creative.paint_terrain",
        boundsJson(minPos, maxPos),
        clampedRadius,
        1,
        {
            {"edited_voxels", 0},
            {"painted_voxels", 0},
            {"dirty_chunks", 0},
        }));
  }

  logCreativeCommand("fel.creative.paint_terrain");
  auto painted = m_manipulator.applyCommand("terrain.set_voxels", {{"voxels", voxels}});
  if (painted.isErr()) {
    return painted;
  }
  nlohmann::json applied = painted.value();
  applied["painted_voxels"] = voxels.size();
  return Result<nlohmann::json>::ok(wrapCreativeEnvelope(
      "fel.creative.paint_terrain",
      boundsJson(minPos, maxPos),
      clampedRadius,
      1,
      std::move(applied)));
}

} // namespace nexus::gameplay
