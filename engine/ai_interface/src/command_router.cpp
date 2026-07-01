#include "nexus/ai/command_router.h"

#include <nlohmann/json.hpp>

#include "nexus/core/log.h"
#include "nexus/creative/voxel_world.h"
#include "nexus/creative/world_manipulator.h"
#include "nexus/generative/generative_pipeline.h"

namespace nexus::ai {

auto CommandRouter::init(creative::WorldManipulator* creativeManipulator,
                         creative::VoxelWorld* voxelWorld,
                         generative::GenerativePipeline* generativePipeline) -> Result<void> {
  if (creativeManipulator == nullptr || voxelWorld == nullptr) {
    return Result<void>::err("CommandRouter requires creative systems");
  }
  m_creativeManipulator = creativeManipulator;
  m_voxelWorld = voxelWorld;
  m_generativePipeline = generativePipeline;
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

    const std::string queryName = queryIt->get<std::string>();

    if (queryName.rfind("fel.studio.", 0) == 0) {
      if (queryName == "fel.studio.list_artifacts") {
        return {message.id,
                "ok",
                {{"artifacts",
                  {{"playtest_latest", "artifacts/playtest/latest.json"},
                   {"playtest_mirror", "artifacts/cursor-nexus/last-playtest.json"},
                   {"hud_snapshot", "artifacts/cursor-nexus/last-hud-snapshot.json"},
                   {"dev_stats_tick", "artifacts/playtest/dev_stats_tick.json"},
                   {"build_gate_log", "artifacts/cursor-nexus/last-build-gate.log"}}},
                 {"doc", "docs/NEXUS_PLAYTEST_FOR_CURSOR.md"}},
                {}};
      }
      if (queryName == "fel.studio.open_file") {
        const auto pathIt = message.payload.find("path");
        if (pathIt == message.payload.end() || !pathIt->is_string()) {
          return {message.id, "error", {}, "fel.studio.open_file requires string path"};
        }
        const std::string relativePath = pathIt->get<std::string>();
        const int line = message.payload.value("line", 0);
        nlohmann::json payload = {{"relative_path", relativePath},
                                  {"cursor_uri_hint", "cursor://file/{repo_root}/" + relativePath}};
        if (line > 0) {
          payload["line"] = line;
        }
        return {message.id, "ok", std::move(payload), {}};
      }
      if (queryName == "fel.studio.run_playtest") {
        const std::string modeId = message.payload.value("mode_id", "basketball_dunk");
        return {message.id,
                "ok",
                {{"mode_id", modeId},
                 {"manual_command", "./scripts/nexus_playtest.sh --mode " + modeId + " --skip-build"},
                 {"mcp_tool", "studio_run_playtest"},
                 {"artifact", "artifacts/playtest/latest.json"}},
                {}};
      }
      return {message.id, "error", {}, "Unsupported fel.studio query"};
    }

    if (m_generativePipeline != nullptr &&
        (queryName.rfind("fel.generate.", 0) == 0 || queryName.rfind("fel.scan.", 0) == 0)) {
      if (m_gameplayHandler != nullptr &&
          (queryName == "fel.generate.parse_prompt" || queryName == "fel.generate.parse_game")) {
        return m_gameplayHandler->handleGameplayQuery(queryName, message.payload, message.id);
      }
      auto result = m_generativePipeline->handleQuery(queryName, message.payload);
      if (result.isErr()) {
        return {message.id, "error", {}, result.error()};
      }
      return {message.id, "ok", result.value(), {}};
    }

    if (m_gameplayHandler != nullptr && queryName.rfind("fel.", 0) == 0) {
      return m_gameplayHandler->handleGameplayQuery(queryName, message.payload, message.id);
    }

    return {message.id, "error", {}, "Unsupported query"};
  }

  const auto commandIt = message.payload.find("command");
  if (commandIt == message.payload.end() || !commandIt->is_string()) {
    return {message.id, "error", {}, "Command messages require payload.command"};
  }

  const auto paramsIt = message.payload.find("params");
  const nlohmann::json emptyParams = nlohmann::json::object();
  if (paramsIt != message.payload.end() && paramsIt->is_array()) {
    return {message.id, "error", {}, "command params must be a JSON object"};
  }
  const nlohmann::json& params =
      paramsIt == message.payload.end() || paramsIt->is_null() ? emptyParams : *paramsIt;
  const std::string command = commandIt->get<std::string>();

  if (command.rfind("terrain.", 0) == 0) {
    auto result = m_creativeManipulator->applyCommand(command, params);
    if (result.isErr()) {
      return {message.id, "error", {}, result.error()};
    }
    return {message.id, "ok", result.value(), {}};
  }

  if (m_generativePipeline != nullptr &&
      (command.rfind("fel.generate.", 0) == 0 || command.rfind("fel.scan.", 0) == 0)) {
    if (m_gameplayHandler != nullptr &&
        (command == "fel.generate.from_text" || command == "fel.creative.from_text" ||
         command == "fel.generate.game" || command == "fel.generate.refine_game")) {
      return m_gameplayHandler->handleGameplayCommand(command, params, message.id);
    }
    auto result = m_generativePipeline->handleCommand(command, params);
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

auto CommandRouter::generativePipeline() const -> generative::GenerativePipeline* {
  return m_generativePipeline;
}

void CommandRouter::shutdown() {
  m_creativeManipulator = nullptr;
  m_voxelWorld = nullptr;
  m_generativePipeline = nullptr;
  m_gameplayHandler = nullptr;
  NEXUS_LOG_INFO(LogChannel::kAI, "Command router shutdown");
}

} // namespace nexus::ai
