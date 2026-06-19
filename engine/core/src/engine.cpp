#include "nexus/core/engine.h"

#include "nexus/ai/agent_server.h"
#include "nexus/ai/command_schema.h"
#include "nexus/core/dev_stats.h"
#include "nexus/core/log.h"
#include "nexus/physics/physics_world.h"
#include "nexus/renderer/vulkan_renderer.h"

#include <nlohmann/json.hpp>

#include <algorithm>
#include <cstdlib>
#include <vector>

namespace {

std::vector<nexus::ai::AgentResponse> g_playtestAgentResponses;

} // namespace

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
  m_playtestFrameCounter = 0;
  g_playtestAgentResponses.clear();
  if (const char* mode = std::getenv("NEXUS_PLAYTEST_MODE"); mode != nullptr && mode[0] != '\0') {
    m_playtestModeId = mode;
  }
  if (const char* venue = std::getenv("NEXUS_PLAYTEST_VENUE"); venue != nullptr && venue[0] != '\0') {
    m_playtestVenueId = venue;
  }
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
  m_perfMonitor.beginFrame();
  m_renderer->pollInput();

  const double smoothedFrameSeconds =
      m_framePacer.smoothDelta(frameTimeSeconds, m_config.maxFrameTimeSeconds);

  // Agent commands are drained before physics and gameplay updates.
  m_latestAgentResponses =
      m_agentServer->processQueuedCommands(m_config.maxCommandsPerFrame);

  m_accumulatorSeconds += frameTimeSeconds;
  while (m_accumulatorSeconds >= m_config.fixedTimestepSeconds) {
    m_physics->step(m_config.fixedTimestepSeconds);
    m_accumulatorSeconds -= m_config.fixedTimestepSeconds;
  }

  if (m_applicationHook != nullptr) {
    m_applicationHook->update(smoothedFrameSeconds, *m_physics, m_latestAgentResponses);
  }

  m_renderer->advanceScene(smoothedFrameSeconds);
  m_renderer->renderFrame();
  m_perfMonitor.endFrame();

  const auto drawStats = m_renderer->lastFrameDrawStats();
  const FrameDevStats frameStats{
      .fps = m_perfMonitor.fps(),
      .frameTimeMs = m_perfMonitor.frameTimeMs(),
      .visibleDraws = drawStats.visibleDraws,
      .culledDraws = drawStats.culledDraws,
      .triangleCount = drawStats.triangleCount,
      .withinDrawBudget = drawStats.withinBudget(),
  };

  ++m_devHudLogCounter;
  if (devHudOverlayEnabled() && m_devHudLogCounter % 30 == 0) {
    logDevHudOverlay(frameStats);
  }

  ++m_devStatsLogCounter;
  if (m_devStatsLogCounter % 120 == 0) {
    logFrameDevStats(frameStats);
  }

  if (playtestExportEnabled()) {
    ++m_playtestFrameCounter;
    for (const ai::AgentResponse& response : m_latestAgentResponses) {
      g_playtestAgentResponses.push_back(response);
    }
    constexpr std::size_t kMaxPlaytestResponses = 64;
    if (g_playtestAgentResponses.size() > kMaxPlaytestResponses) {
      g_playtestAgentResponses.erase(
          g_playtestAgentResponses.begin(),
          g_playtestAgentResponses.begin() +
              static_cast<std::ptrdiff_t>(g_playtestAgentResponses.size() - kMaxPlaytestResponses));
    }
    nlohmann::json responses = nlohmann::json::array();
    for (const ai::AgentResponse& response : g_playtestAgentResponses) {
      responses.push_back(response.serialize());
    }
    exportPlaytestTickSnapshot(
        frameStats,
        PlaytestExportContext{
            .frame = m_playtestFrameCounter,
            .modeId = m_playtestModeId,
            .venueId = m_playtestVenueId,
            .agentResponsesJson = responses.dump(),
        });
  }
}

} // namespace nexus::core
