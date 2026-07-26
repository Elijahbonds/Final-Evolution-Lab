#include "nexus/creative/world_manipulator.h"

#include <algorithm>

namespace nexus::creative {

namespace {

auto parsePosition(const nlohmann::json& value) -> Result<Vec3i> {
  if (!value.is_array() || value.size() != 3) {
    return Result<Vec3i>::err("position must be a 3-item array");
  }
  if (!value[0].is_number_integer() || !value[1].is_number_integer() ||
      !value[2].is_number_integer()) {
    return Result<Vec3i>::err("position values must be integers");
  }
  return Result<Vec3i>::ok({value[0].get<int>(), value[1].get<int>(), value[2].get<int>()});
}

auto parseVoxel(const nlohmann::json& value) -> Result<Voxel> {
  if (!value.is_object()) {
    return Result<Voxel>::err("voxel must be an object");
  }
  const auto materialIt = value.find("material");
  const auto solidIt = value.find("solid");
  if (materialIt != value.end() && !materialIt->is_number_integer()) {
    return Result<Voxel>::err("voxel.material must be an integer");
  }
  if (solidIt != value.end() && !solidIt->is_boolean()) {
    return Result<Voxel>::err("voxel.solid must be a boolean");
  }

  Voxel voxel{};
  voxel.material = materialIt == value.end() ? 0 : materialIt->get<std::uint16_t>();
  voxel.solid = solidIt == value.end() ? voxel.material != 0 : solidIt->get<bool>();
  return Result<Voxel>::ok(voxel);
}

} // namespace

WorldManipulator::WorldManipulator(VoxelWorld& world) : m_world(world) {}

auto WorldManipulator::applyCommand(std::string_view command,
                                    const nlohmann::json& params) -> Result<nlohmann::json> {
  if (command == "terrain.set_voxels") {
    return setVoxels(params);
  }
  if (command == "terrain.fill_region") {
    return fillRegion(params);
  }
  return Result<nlohmann::json>::err("Unsupported creative command");
}

auto WorldManipulator::setVoxels(const nlohmann::json& params) -> Result<nlohmann::json> {
  if (!params.contains("voxels") || !params["voxels"].is_array()) {
    return Result<nlohmann::json>::err("terrain.set_voxels requires a voxels array");
  }

  std::size_t edited = 0;
  for (const auto& edit : params["voxels"]) {
    if (!edit.is_object() || !edit.contains("position") || !edit.contains("voxel")) {
      return Result<nlohmann::json>::err("each voxel edit requires position and voxel");
    }

    auto position = parsePosition(edit["position"]);
    if (position.isErr()) {
      return Result<nlohmann::json>::err(position.error());
    }
    auto voxel = parseVoxel(edit["voxel"]);
    if (voxel.isErr()) {
      return Result<nlohmann::json>::err(voxel.error());
    }
    auto applied = m_world.setVoxel(position.value(), voxel.value());
    if (applied.isErr()) {
      return Result<nlohmann::json>::err(applied.error());
    }
    ++edited;
  }

  return Result<nlohmann::json>::ok({
      {"edited_voxels", edited},
      {"dirty_chunks", m_world.dirtyChunkCount()},
  });
}

auto WorldManipulator::fillRegion(const nlohmann::json& params) -> Result<nlohmann::json> {
  if (!params.is_object() || !params.contains("min") || !params.contains("max") ||
      !params.contains("voxel")) {
    return Result<nlohmann::json>::err("terrain.fill_region requires min, max, and voxel");
  }

  auto minResult = parsePosition(params["min"]);
  auto maxResult = parsePosition(params["max"]);
  auto voxel = parseVoxel(params["voxel"]);
  if (minResult.isErr()) {
    return Result<nlohmann::json>::err(minResult.error());
  }
  if (maxResult.isErr()) {
    return Result<nlohmann::json>::err(maxResult.error());
  }
  if (voxel.isErr()) {
    return Result<nlohmann::json>::err(voxel.error());
  }

  const Vec3i minPos{
      std::min(minResult.value().x, maxResult.value().x),
      std::min(minResult.value().y, maxResult.value().y),
      std::min(minResult.value().z, maxResult.value().z),
  };
  const Vec3i maxPos{
      std::max(minResult.value().x, maxResult.value().x),
      std::max(minResult.value().y, maxResult.value().y),
      std::max(minResult.value().z, maxResult.value().z),
  };

  constexpr std::size_t kMaxFillVoxels = 32768;
  const std::size_t volume =
      static_cast<std::size_t>(maxPos.x - minPos.x + 1) *
      static_cast<std::size_t>(maxPos.y - minPos.y + 1) *
      static_cast<std::size_t>(maxPos.z - minPos.z + 1);
  if (volume > kMaxFillVoxels) {
    return Result<nlohmann::json>::err("terrain.fill_region exceeds maximum edit volume");
  }

  for (int z = minPos.z; z <= maxPos.z; ++z) {
    for (int y = minPos.y; y <= maxPos.y; ++y) {
      for (int x = minPos.x; x <= maxPos.x; ++x) {
        m_world.setVoxel({x, y, z}, voxel.value());
      }
    }
  }

  return Result<nlohmann::json>::ok({
      {"edited_voxels", volume},
      {"dirty_chunks", m_world.dirtyChunkCount()},
  });
}

} // namespace nexus::creative
