#pragma once

#include "nexus/ai/command_schema.h"

#include <memory>
#include <string_view>

namespace nexus::creative {
class WorldManipulator;
class VoxelWorld;
}

namespace nexus::ai {

class GameplayCommandHandler {
public:
  virtual ~GameplayCommandHandler() = default;

  /// Handles game/app-layer commands without adding app dependencies to the router.
  virtual auto handleGameplayCommand(std::string_view command,
                                     const nlohmann::json& params,
                                     std::string_view id) -> AgentResponse = 0;

  /// Handles game/app-layer queries without adding app dependencies to the router.
  virtual auto handleGameplayQuery(std::string_view query,
                                   const nlohmann::json& payload,
                                   std::string_view id) -> AgentResponse = 0;
};

class CommandRouter {
public:
  auto init(creative::WorldManipulator* creativeManipulator,
            creative::VoxelWorld* voxelWorld) -> Result<void>;
  [[nodiscard]] auto route(const AgentMessage& message) -> AgentResponse;
  void setGameplayHandler(GameplayCommandHandler* gameplayHandler);
  void shutdown();

private:
  creative::WorldManipulator* m_creativeManipulator{nullptr};
  creative::VoxelWorld* m_voxelWorld{nullptr};
  GameplayCommandHandler* m_gameplayHandler{nullptr};
};

} // namespace nexus::ai
