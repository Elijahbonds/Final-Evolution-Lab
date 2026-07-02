#pragma once

#include "nexus/ai/agent_server.h"
#include "nexus/ai/command_router.h"
#include "nexus/ai/command_schema.h"
#include "nexus/core/result.h"
#include "nexus/creative/voxel_world.h"
#include "nexus/creative/world_manipulator.h"
#include "nexus/gameplay/gameplay_application.h"
#include "nexus/generative/generative_pipeline.h"

#include <cstddef>
#include <string>
#include <string_view>
#include <vector>

namespace nexus::tools {

struct AgentCliSessionConfig {
  std::size_t queueBudget{8};
  std::string importRoot{"assets/nexus/imported"};
  std::string manifestPath{"assets/nexus/manifests/nexus_asset_manifest.json"};
};

/// Headless CommandRouter + AgentServer stack for external agent clients (Cursor, MCP).
class AgentCliSession {
public:
  explicit AgentCliSession(AgentCliSessionConfig config = {});

  auto init() -> Result<void>;
  auto dispatchLine(std::string_view jsonLine) -> std::vector<ai::AgentResponse>;
  void shutdown();

  [[nodiscard]] auto queueBudget() const -> std::size_t;
  [[nodiscard]] auto agentServer() -> ai::AgentServer&;

private:
  AgentCliSessionConfig m_config;
  creative::VoxelWorld m_world;
  creative::WorldManipulator m_manipulator;
  generative::GenerativePipeline m_pipeline;
  gameplay::GameplayApplication m_gameplay;
  ai::CommandRouter m_router;
  ai::AgentServer m_server;
  bool m_initialized{false};
};

} // namespace nexus::tools
