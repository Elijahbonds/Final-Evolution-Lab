// File: app/gameplay/include/nexus/gameplay/gameplay_application.h
// Part of: Final Evolution Lab (FEL) Game Logic
// Spec: 01 Gameplay Loop Protocol, 06 NEXUS Integration Map, 10 Phase 0/4
#pragma once

#include "nexus/ai/command_router.h"
#include "nexus/core/engine.h"
#include "nexus/gameplay/dunk_contest.h"
#include "nexus/gameplay/fitness_data.h"
#include "nexus/gameplay/throw_catch_physics.h"
#include "nexus/gameplay/voxel_command_parser.h"

#include <cstddef>
#include <nlohmann/json.hpp>
#include <optional>
#include <vector>

namespace nexus::generative {
class GenerativePipeline;
}

namespace nexus::creative {
class VoxelWorld;
class WorldManipulator;
}

namespace nexus::gameplay {

struct GameplayUpdateStats {
  // Number of agent commands drained in the latest app update.
  std::size_t processedAgentMessages{0};
  // Agent responses with error status in the latest update.
  std::size_t latestAgentErrors{0};
  // Total number of app updates completed.
  std::uint64_t updatesCompleted{0};
};

class GameplayApplication final : public core::ApplicationUpdateHook,
                                  public ai::GameplayCommandHandler {
public:
  explicit GameplayApplication(creative::WorldManipulator& manipulator,
                               const creative::VoxelWorld& voxelWorld);

  void setGenerativePipeline(generative::GenerativePipeline* generativePipeline);

  /// Runs app/gameplay updates after agent drain and fixed physics stepping.
  void update(double deltaSeconds,
              physics::PhysicsWorld& physicsWorld,
              std::span<const ai::AgentResponse> agentResponses) override;

  /// Handles fitness and creative app-layer commands from the agent bridge.
  auto handleGameplayCommand(std::string_view command,
                             const nlohmann::json& params,
                             std::string_view id) -> ai::AgentResponse override;

  /// Handles app-layer state queries from the agent bridge.
  auto handleGameplayQuery(std::string_view query,
                           const nlohmann::json& payload,
                           std::string_view id) -> ai::AgentResponse override;

  /// Returns the thread-safe fitness container owned by gameplay logic.
  [[nodiscard]] auto fitness_data() -> ThreadSafeFitnessData&;

  /// Returns the current throw-catch controller state.
  [[nodiscard]] auto throw_catch_state() const -> const ThrowCatchState&;

  /// Returns the active Basketball Dunk Contest, if one has been started.
  [[nodiscard]] auto dunk_contest() const -> const DunkContest*;

  /// Returns latest update-loop counters for smoke tests and diagnostics.
  [[nodiscard]] auto stats() const -> const GameplayUpdateStats&;

private:
  auto applyFitnessCommand(std::string_view command,
                           const nlohmann::json& params,
                           std::string_view id) -> ai::AgentResponse;
  auto applyDunkCommand(std::string_view command,
                        const nlohmann::json& params,
                        std::string_view id) -> ai::AgentResponse;
  [[nodiscard]] auto sessionStatePayload() const -> nlohmann::json;

  ThreadSafeFitnessData m_fitnessData;
  ThrowCatchPhysicsController m_throwCatch;
  VoxelCommandParser m_voxelParser;
  std::optional<DunkContest> m_dunkContest;
  generative::GenerativePipeline* m_generativePipeline{nullptr};
  GameplayUpdateStats m_stats;
  std::vector<ai::AgentResponse> m_latestResponses;
};

} // namespace nexus::gameplay
