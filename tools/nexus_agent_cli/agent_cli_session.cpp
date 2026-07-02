#include "agent_cli_session.h"

#include "nexus/core/log.h"

namespace nexus::tools {

AgentCliSession::AgentCliSession(AgentCliSessionConfig config)
    : m_config(std::move(config)),
      m_manipulator(m_world),
      m_pipeline([&]() {
        generative::GenerativePipelineConfig pipelineConfig{};
        pipelineConfig.scan.importRoot = m_config.importRoot;
        pipelineConfig.scan.manifestPath = m_config.manifestPath;
        pipelineConfig.generate.importRoot = m_config.importRoot;
        pipelineConfig.generate.manifestPath = m_config.manifestPath;
        pipelineConfig.environmentScan.importRoot = m_config.importRoot + "/environments";
        pipelineConfig.environmentScan.manifestPath = m_config.manifestPath;
        return generative::GenerativePipeline{pipelineConfig};
      }()),
      m_gameplay(m_manipulator, m_world) {}

auto AgentCliSession::init() -> Result<void> {
  if (m_initialized) {
    return Result<void>::err("AgentCliSession already initialized");
  }

  m_pipeline.setVoxelWorld(&m_world);
  m_gameplay.setGenerativePipeline(&m_pipeline);

  auto routerResult = m_router.init(&m_manipulator, &m_world, &m_pipeline);
  if (routerResult.isErr()) {
    return routerResult;
  }
  m_router.setGameplayHandler(&m_gameplay);

  auto serverResult = m_server.init(&m_router);
  if (serverResult.isErr()) {
    m_router.shutdown();
    return serverResult;
  }

  m_initialized = true;
  NEXUS_LOG_INFO(LogChannel::kAI, "Agent CLI session initialized");
  return Result<void>::ok();
}

auto AgentCliSession::dispatchLine(std::string_view jsonLine) -> std::vector<ai::AgentResponse> {
  if (!m_initialized) {
    return {{"", "error", {}, "AgentCliSession not initialized"}};
  }
  if (jsonLine.empty()) {
    return {};
  }

  const auto receiveResult = m_server.receiveJson(jsonLine);
  if (receiveResult.isErr()) {
    std::string correlationId;
    nlohmann::json parsed = nlohmann::json::parse(jsonLine, nullptr, false);
    if (!parsed.is_discarded() && parsed.is_object() && parsed.contains("id") &&
        parsed["id"].is_string()) {
      correlationId = parsed["id"].get<std::string>();
    }
    return {{std::move(correlationId), "error", {}, receiveResult.error()}};
  }

  return m_server.processQueuedCommands(m_config.queueBudget);
}

void AgentCliSession::shutdown() {
  if (!m_initialized) {
    return;
  }
  m_server.shutdown();
  m_router.shutdown();
  m_initialized = false;
  NEXUS_LOG_INFO(LogChannel::kAI, "Agent CLI session shutdown");
}

auto AgentCliSession::queueBudget() const -> std::size_t {
  return m_config.queueBudget;
}

auto AgentCliSession::agentServer() -> ai::AgentServer& {
  return m_server;
}

} // namespace nexus::tools
