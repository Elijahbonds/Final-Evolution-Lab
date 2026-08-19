#pragma once

#include "nexus/core/job_system.h"
#include "nexus/core/perf_monitor.h"
#include "nexus/core/result.h"

#include <chrono>
#include <cstddef>
#include <cstdint>
#include <span>
#include <string>
#include <vector>

namespace nexus::ai {
class AgentResponse;
class AgentServer;
}

namespace nexus::physics {
class PhysicsWorld;
}

namespace nexus::renderer {
class VulkanRenderer;
}

namespace nexus::core {

struct EngineConfig {
  double fixedTimestepSeconds{1.0 / 60.0};
  double maxFrameTimeSeconds{0.25};
  std::size_t maxCommandsPerFrame{32};
};

class ApplicationUpdateHook {
public:
  virtual ~ApplicationUpdateHook() = default;

  /// Runs app/gameplay updates after agent drain and fixed physics stepping.
  virtual void update(double deltaSeconds,
                      physics::PhysicsWorld& physicsWorld,
                      std::span<const ai::AgentResponse> agentResponses) = 0;
};

class Engine {
public:
  auto init(EngineConfig config,
            renderer::VulkanRenderer* renderer,
            physics::PhysicsWorld* physics,
            ai::AgentServer* agentServer,
            ApplicationUpdateHook* applicationHook = nullptr) -> Result<void>;
  void run();
  void requestStop();
  void shutdown();

  /// Work-stealing scheduler shared by physics integration and future render prep.
  [[nodiscard]] auto jobSystem() -> JobSystem& { return m_jobSystem; }

private:
  using Clock = std::chrono::steady_clock;

  void tick(double frameTimeSeconds);

  EngineConfig m_config;
  renderer::VulkanRenderer* m_renderer{nullptr};
  physics::PhysicsWorld* m_physics{nullptr};
  ai::AgentServer* m_agentServer{nullptr};
  ApplicationUpdateHook* m_applicationHook{nullptr};
  JobSystem m_jobSystem{};
  PerfMonitor m_perfMonitor{};
  FramePacer m_framePacer{};
  std::uint64_t m_devStatsLogCounter{0};
  std::uint64_t m_devHudLogCounter{0};
  std::uint64_t m_playtestFrameCounter{0};
  std::string m_playtestModeId;
  std::string m_playtestVenueId;
  std::vector<ai::AgentResponse> m_latestAgentResponses;
  bool m_running{false};
  double m_accumulatorSeconds{0.0};
};

} // namespace nexus::core
