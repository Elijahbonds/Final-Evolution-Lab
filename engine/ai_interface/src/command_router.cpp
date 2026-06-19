#include "nexus/ai/command_router.h"

#include "nexus/core/log.h"
#include "nexus/creative/voxel_world.h"
#include "nexus/creative/world_manipulator.h"

namespace nexus::ai {

auto CommandRouter::init(creative::WorldManipulator* creativeManipulator,
                         creative::VoxelWorld* voxelWorld) -> Result<void> {
  if (creativeManipulator == nullptr || voxelWorld == nullptr) {
    return Result<void>::err("CommandRouter requires creative systems");
  }
  m_creativeManipulator = creativeManipulator;
  m_voxelWorld = voxelWorld;
  NEXUS_LOG_INFO(LogChannel::kAI, "Command router initialized");
  return Result<void>::ok();
}

auto CommandRouter::route(const AgentMessage& message) -> AgentResponse {
  if (message.type == MessageType::kAuth) {
    return {message.id, "ok", {{"authenticated", true}}, {}};
  }

  if (message.type == MessageType::kQuery) {
    const auto queryIt = message.payload.find("query");
    if (queryIt == message.payload.end() || !queryIt->is_string()) {
      return {message.id, "error", {}, "Query messages require payload.query"};
    }

    if (queryIt->get<std::string>() == "world.dirty_chunks") {
      return {message.id,
              "ok",
              {{"chunks", m_voxelWorld->serializeDirtyChunks(8)}},
              {}};
    }

    if (m_gameplayHandler != nullptr && queryIt->get<std::string>().rfind("fel.", 0) == 0) {
      return m_gameplayHandler->handleGameplayQuery(queryIt->get<std::string>(),
                                                    message.payload,
                                                    message.id);
    }

    return {message.id, "error", {}, "Unsupported query"};
  }

  const auto commandIt = message.payload.find("command");
  if (commandIt == message.payload.end() || !commandIt->is_string()) {
    return {message.id, "error", {}, "Command messages require payload.command"};
  }

  const auto paramsIt = message.payload.find("params");
  const nlohmann::json emptyParams = nlohmann::json::object();
  const nlohmann::json& params = paramsIt == message.payload.end() ? emptyParams : *paramsIt;
  const std::string command = commandIt->get<std::string>();

  if (command.rfind("terrain.", 0) == 0) {
    auto result = m_creativeManipulator->applyCommand(command, params);
    if (result.isErr()) {
      return {message.id, "error", {}, result.error()};
    }
    return {message.id, "ok", result.value(), {}};
  }

  if (m_gameplayHandler != nullptr &&
      (command.rfind("fel.", 0) == 0 || command.rfind("fitness.", 0) == 0)) {
    return m_gameplayHandler->handleGameplayCommand(command, params, message.id);
  }

  return {message.id, "error", {}, "Unsupported command"};
}

void CommandRouter::setGameplayHandler(GameplayCommandHandler* gameplayHandler) {
  m_gameplayHandler = gameplayHandler;
}

void CommandRouter::shutdown() {
  m_creativeManipulator = nullptr;
  m_voxelWorld = nullptr;
  m_gameplayHandler = nullptr;
  NEXUS_LOG_INFO(LogChannel::kAI, "Command router shutdown");
}

} // namespace nexus::ai
