// File: app/gameplay/include/nexus/gameplay/gameplay_application.h
// Part of: Final Evolution Lab (FEL) Game Logic
// Spec: 01 Gameplay Loop Protocol, 06 NEXUS Integration Map, 10 Phase 0/4
#pragma once

#include "nexus/ai/command_router.h"
#include "nexus/ai/game_prompt_adapter.h"
#include "nexus/ai/text_prompt_adapter.h"
#include "nexus/core/engine.h"
#include "nexus/gameplay/arena_session_manager.h"
#include "nexus/gameplay/exercise_demo_pipeline.h"
#include "nexus/gameplay/fel_bridge_service.h"
#include "nexus/gameplay/fitness_data.h"
#include "nexus/gameplay/gameplay_manager.h"
#include "nexus/gameplay/hud_relay_service.h"
#include "nexus/gameplay/mode_runtime.h"
#include "nexus/gameplay/throw_catch_physics.h"
#include "nexus/gameplay/venue_volume_registry.h"
#include "nexus/gameplay/voxel_command_parser.h"

#include <cstdint>
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

  /// Returns latest update-loop counters for smoke tests and diagnostics.
  [[nodiscard]] auto stats() const -> const GameplayUpdateStats&;

  [[nodiscard]] auto arena_session() const -> const ArenaSessionManager&;
  [[nodiscard]] auto gameplay_manager() const -> const GameplayManager&;
  [[nodiscard]] auto fel_bridge() const -> const FelBridgeService&;
  [[nodiscard]] auto hud_relay() const -> const HudRelayService&;
  [[nodiscard]] auto mode_runtime() const -> const ModeRuntime&;

private:
  auto applyFitnessCommand(std::string_view command,
                           const nlohmann::json& params,
                           std::string_view id) -> ai::AgentResponse;
  auto applyArenaCommand(std::string_view command,
                         const nlohmann::json& params,
                         std::string_view id) -> ai::AgentResponse;
  auto applyBridgeCommand(std::string_view command,
                          const nlohmann::json& params,
                          std::string_view id) -> ai::AgentResponse;
  auto applyVenueCommand(std::string_view command,
                         const nlohmann::json& params,
                         std::string_view id) -> ai::AgentResponse;
  auto applyHudCommand(std::string_view command,
                       const nlohmann::json& params,
                       std::string_view id) -> ai::AgentResponse;
  auto applyTextGenerationCommand(std::string_view command,
                                  const nlohmann::json& params,
                                  std::string_view id) -> ai::AgentResponse;
  auto applyTextGenerationQuery(std::string_view query,
                                const nlohmann::json& payload,
                                std::string_view id) -> ai::AgentResponse;
  auto applyGameGenerationCommand(std::string_view command,
                                  const nlohmann::json& params,
                                  std::string_view id) -> ai::AgentResponse;
  auto applyGameGenerationQuery(std::string_view query,
                                const nlohmann::json& payload,
                                std::string_view id) -> ai::AgentResponse;
  [[nodiscard]] auto executeTextPlan(const ai::TextGenerationPlan& plan,
                                     bool creativeOnly) -> Result<nlohmann::json>;
  auto applyScanGenerateCommand(std::string_view command,
                                const nlohmann::json& params,
                                std::string_view id) -> ai::AgentResponse;
  [[nodiscard]] auto parseMatchScoreInput(const nlohmann::json& params) const
      -> MatchScoreInput;
  [[nodiscard]] auto resolveEndSessionScores(const nlohmann::json& params) const
      -> MatchScoreInput;
  [[nodiscard]] auto buildEndSessionPayload(const SessionResult& result) const -> nlohmann::json;
  [[nodiscard]] auto parseVec3(const nlohmann::json& params) const -> Result<Vec3f>;
  [[nodiscard]] auto sessionStatePayload() const -> nlohmann::json;
  void processVenueOverlaps();
  void syncArenaFromModeRuntime();
  void emitHudTickFrame();
  [[nodiscard]] static auto sessionStateLabel(ArenaSessionPhase phase, bool paused)
      -> std::string_view;

  ThreadSafeFitnessData m_fitnessData;
  ThrowCatchPhysicsController m_throwCatch;
  VoxelCommandParser m_voxelParser;
  ArenaSessionManager m_arenaSession;
  GameplayManager m_gameplayManager;
  FelBridgeService m_felBridge;
  VenueVolumeRegistry m_venueVolumes;
  HudRelayService m_hudRelay;
  ModeRuntime m_modeRuntime;
  generative::GenerativePipeline* m_generativePipeline{nullptr};
  std::optional<ai::GameGenerationSpec> m_lastGameSpec;
  GameplayUpdateStats m_stats;
  std::vector<ai::AgentResponse> m_latestResponses;
};

} // namespace nexus::gameplay
