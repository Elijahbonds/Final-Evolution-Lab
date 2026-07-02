// File: app/gameplay/include/nexus/gameplay/voxel_command_parser.h
// Part of: Final Evolution Lab (FEL) Game Logic
// Spec: 04 Creative Mode Protocol, 10 Phase 4 Creative Mode
#pragma once

#include "nexus/core/result.h"

#include <nlohmann/json.hpp>
#include <string_view>

namespace nexus::creative {
class VoxelWorld;
class WorldManipulator;
}

namespace nexus::gameplay {

class VoxelCommandParser {
public:
  explicit VoxelCommandParser(creative::WorldManipulator& manipulator,
                              const creative::VoxelWorld& world);

  /// Parses fel.creative commands and applies safe terrain/voxel edits.
  auto apply_command(std::string_view command, const nlohmann::json& params)
      -> Result<nlohmann::json>;

private:
  auto apply_raise_or_lower(bool raise, const nlohmann::json& params) -> Result<nlohmann::json>;
  auto apply_flatten(const nlohmann::json& params) -> Result<nlohmann::json>;
  auto apply_paint(const nlohmann::json& params) -> Result<nlohmann::json>;

  creative::WorldManipulator& m_manipulator;
  const creative::VoxelWorld& m_world;
};

} // namespace nexus::gameplay
