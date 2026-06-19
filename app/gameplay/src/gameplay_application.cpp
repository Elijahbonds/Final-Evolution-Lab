// File: app/gameplay/src/gameplay_application.cpp
// Part of: Final Evolution Lab (FEL) Game Logic
// Spec: 01 Gameplay Loop Protocol, 06 NEXUS Integration Map, 10 Phase 0/4
#include "nexus/gameplay/gameplay_application.h"

#include "nexus/creative/voxel_world.h"
#include "nexus/core/log.h"

#include <algorithm>
#include <span>
#include <string>
#include <utility>

namespace nexus::gameplay {

namespace {

auto floatParam(const nlohmann::json& params,
                std::string_view name,
                float defaultValue) -> Result<float> {
  const auto found = params.find(std::string(name));
  if (found == params.end()) {
    return Result<float>::ok(defaultValue);
  }
  if (!found->is_number()) {
    return Result<float>::err("fitness parameter must be numeric");
  }
  return Result<float>::ok(found->get<float>());
}

auto integerParam(const nlohmann::json& params,
                  std::string_view name,
                  int defaultValue) -> Result<int> {
  const auto found = params.find(std::string(name));
  if (found == params.end()) {
    return Result<int>::ok(defaultValue);
  }
  if (!found->is_number_integer()) {
    return Result<int>::err("fitness integer parameter has invalid type");
  }
  return Result<int>::ok(found->get<int>());
}

auto response(std::string_view id,
              std::string status,
              nlohmann::json payload,
              std::string error = {}) -> ai::AgentResponse {
  return {std::string(id), std::move(status), std::move(payload), std::move(error)};
}

} // namespace

GameplayApplication::GameplayApplication(creative::WorldManipulator& manipulator,
                                         const creative::VoxelWorld& voxelWorld)
    : m_voxelParser(manipulator, voxelWorld) {}

void GameplayApplication::update(double deltaSeconds,
                                 physics::PhysicsWorld& physicsWorld,
                                 std::span<const ai::AgentResponse> agentResponses) {
  m_latestResponses.assign(agentResponses.begin(), agentResponses.end());
  m_stats.processedAgentMessages = m_latestResponses.size();
  m_stats.latestAgentErrors = static_cast<std::size_t>(std::count_if(
      m_latestResponses.begin(),
      m_latestResponses.end(),
      [](const ai::AgentResponse& agentResponse) { return agentResponse.status == "error"; }));

  m_throwCatch.update(deltaSeconds, m_fitnessData.read_view(), physicsWorld);
  ++m_stats.updatesCompleted;
}

auto GameplayApplication::handleGameplayCommand(std::string_view command,
                                                const nlohmann::json& params,
                                                std::string_view id) -> ai::AgentResponse {
  if (command.rfind("fel.fitness.", 0) == 0 || command.rfind("fitness.", 0) == 0) {
    return applyFitnessCommand(command, params, id);
  }

  if (command.rfind("fel.creative.", 0) == 0) {
    auto result = m_voxelParser.apply_command(command, params);
    if (result.isErr()) {
      return response(id, "error", {}, result.error());
    }
    return response(id, "ok", result.value());
  }

  return response(id, "error", {}, "Unsupported gameplay command");
}

auto GameplayApplication::handleGameplayQuery(std::string_view query,
                                              const nlohmann::json& payload,
                                              std::string_view id) -> ai::AgentResponse {
  (void)payload;
  if (query == "fel.query.get_session_state") {
    return response(id, "ok", sessionStatePayload());
  }

  return response(id, "error", {}, "Unsupported gameplay query");
}

auto GameplayApplication::fitness_data() -> ThreadSafeFitnessData& {
  return m_fitnessData;
}

auto GameplayApplication::throw_catch_state() const -> const ThrowCatchState& {
  return m_throwCatch.state();
}

auto GameplayApplication::stats() const -> const GameplayUpdateStats& {
  return m_stats;
}

auto GameplayApplication::applyFitnessCommand(std::string_view command,
                                              const nlohmann::json& params,
                                              std::string_view id) -> ai::AgentResponse {
  const bool isFullUpdate =
      command == "fel.fitness.update" || command == "fitness.update";
  const bool isFrcUpdate =
      command == "fel.fitness.update_frc" || command == "fitness.update_frc";
  const bool isIapUpdate =
      command == "fel.fitness.update_iap" || command == "fitness.update_iap";
  if (!isFullUpdate && !isFrcUpdate && !isIapUpdate) {
    return response(id, "error", {}, "Unsupported fitness command");
  }

  const auto current = m_fitnessData.snapshot();
  FRCMetrics frc = current.frc;
  IAPMetrics iap = current.iap;

  if (isFullUpdate || isFrcUpdate) {
    const auto frcMobility = floatParam(params, "frc_mobility", frc.mobilityScore);
    const auto frcRange = floatParam(params, "frc_active_range", frc.activeRangeScore);
    const auto frcControl = floatParam(params, "frc_control", frc.controlScore);
    if (frcMobility.isErr()) {
      return response(id, "error", {}, frcMobility.error());
    }
    if (frcRange.isErr()) {
      return response(id, "error", {}, frcRange.error());
    }
    if (frcControl.isErr()) {
      return response(id, "error", {}, frcControl.error());
    }
    frc = {
        std::clamp(frcMobility.value(), 0.0F, 1.0F),
        std::clamp(frcRange.value(), 0.0F, 1.0F),
        std::clamp(frcControl.value(), 0.0F, 1.0F),
    };
  }

  if (isFullUpdate || isIapUpdate) {
    const auto iapEngagement = floatParam(params, "iap_engagement", iap.engagementScore);
    const auto iapConfidence = floatParam(params, "iap_confidence", iap.confidence);
    const auto breathPhase = integerParam(params, "breath_phase", iap.breathPhase);
    if (iapEngagement.isErr()) {
      return response(id, "error", {}, iapEngagement.error());
    }
    if (iapConfidence.isErr()) {
      return response(id, "error", {}, iapConfidence.error());
    }
    if (breathPhase.isErr()) {
      return response(id, "error", {}, breathPhase.error());
    }
    iap = {
        std::clamp(iapEngagement.value(), 0.0F, 1.0F),
        std::clamp(iapConfidence.value(), 0.0F, 1.0F),
        static_cast<std::int8_t>(std::clamp(breathPhase.value(), -1, 1)),
    };
  }

  if (isFrcUpdate) {
    m_fitnessData.update_frc(frc);
  } else if (isIapUpdate) {
    m_fitnessData.update_iap(iap);
  } else {
    m_fitnessData.update(frc, iap);
  }

  NEXUS_LOG_INFO(LogChannel::kAI, "Fitness metrics updated from agent command");
  return response(id, "ok", {{"fitness_revision", m_fitnessData.snapshot().revision}});
}

auto GameplayApplication::sessionStatePayload() const -> nlohmann::json {
  const auto fitness = m_fitnessData.snapshot();
  const auto& throwCatch = m_throwCatch.state();
  return {
      {"fitness",
       {
           {"revision", fitness.revision},
           {"frc",
            {
                {"mobility_score", fitness.frc.mobilityScore},
                {"active_range_score", fitness.frc.activeRangeScore},
                {"control_score", fitness.frc.controlScore},
            }},
           {"iap",
            {
                {"engagement_score", fitness.iap.engagementScore},
                {"confidence", fitness.iap.confidence},
                {"breath_phase", fitness.iap.breathPhase},
            }},
       }},
      {"throw_catch",
       {
           {"phase", static_cast<int>(throwCatch.phase)},
           {"power_multiplier", throwCatch.powerMultiplier},
           {"throws_triggered", throwCatch.throwsTriggered},
       }},
      {"agent",
       {
           {"processed_messages", m_stats.processedAgentMessages},
           {"latest_errors", m_stats.latestAgentErrors},
       }},
      {"updates_completed", m_stats.updatesCompleted},
  };
}

} // namespace nexus::gameplay
