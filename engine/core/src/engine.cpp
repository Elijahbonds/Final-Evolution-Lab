#include "nexus/core/engine.h"

#include "nexus/ai/agent_server.h"
#include "nexus/core/log.h"
#include "nexus/physics/physics_world.h"
#include "nexus/renderer/vulkan_renderer.h"

#include <algorithm>

namespace nexus::core {

auto Engine::init(EngineConfig config,
                  renderer::VulkanRenderer* renderer,
                  physics::PhysicsWorld* physics,
                  ai::AgentServer* agentServer,
                  ApplicationUpdateHook* applicationHook) -> Result<void> {
  if (renderer == nullptr || physics == nullptr || agentServer == nullptr) {
    return Result<void>::err("Engine dependencies must not be null");
  }

  m_config = config;
  m_renderer = renderer;
  m_physics = physics;
  m_agentServer = agentServer;
  m_applicationHook = applicationHook;
  m_accumulatorSeconds = 0.0;
  m_latestAgentResponses.clear();
  NEXUS_LOG_INFO(LogChannel::kCore, "Engine initialized");
  return Result<void>::ok();
}

void Engine::run() {
  m_running = true;
  auto previousTime = Clock::now();

  while (m_running && !m_renderer->shouldClose()) {
    const auto currentTime = Clock::now();
    const std::chrono::duration<double> elapsed = currentTime - previousTime;
    previousTime = currentTime;

    const double frameTimeSeconds =
        std::min(elapsed.count(), m_config.maxFrameTimeSeconds);
    tick(frameTimeSeconds);
  }
}

void Engine::requestStop() {
  m_running = false;
}

void Engine::shutdown() {
  m_running = false;
  NEXUS_LOG_INFO(LogChannel::kCore, "Engine shutdown");
}

void Engine::tick(double frameTimeSeconds) {
  m_renderer->pollInput();

  // Agent commands are drained before physics and gameplay updates.
  m_latestAgentResponses =
      m_agentServer->processQueuedCommands(m_config.maxCommandsPerFrame);

  m_accumulatorSeconds += frameTimeSeconds;
  while (m_accumulatorSeconds >= m_config.fixedTimestepSeconds) {
    m_physics->step(m_config.fixedTimestepSeconds);
    m_accumulatorSeconds -= m_config.fixedTimestepSeconds;
  }

  if (m_applicationHook != nullptr) {
    m_applicationHook->update(frameTimeSeconds, *m_physics, m_latestAgentResponses);
  }

  m_renderer->advanceScene(frameTimeSeconds);
  m_renderer->renderFrame();
}

} // namespace nexus::core
