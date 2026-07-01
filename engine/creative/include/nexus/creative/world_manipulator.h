#pragma once

#include "nexus/core/result.h"
#include "nexus/creative/voxel_world.h"

#include <nlohmann/json.hpp>
#include <string_view>

namespace nexus::creative {

class WorldManipulator {
public:
  explicit WorldManipulator(VoxelWorld& world);

  auto applyCommand(std::string_view command, const nlohmann::json& params) -> Result<nlohmann::json>;

private:
  auto setVoxels(const nlohmann::json& params) -> Result<nlohmann::json>;
  auto fillRegion(const nlohmann::json& params) -> Result<nlohmann::json>;

  VoxelWorld& m_world;
};

} // namespace nexus::creative
