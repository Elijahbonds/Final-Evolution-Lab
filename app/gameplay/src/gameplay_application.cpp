// File: app/gameplay/src/gameplay_application.cpp
// Part of: Final Evolution Lab (FEL) Game Logic
// Spec: 01 Gameplay Loop Protocol, 06 NEXUS Integration Map, 10 Phase 0/4
#include "nexus/gameplay/gameplay_application.h"

#include "nexus/creative/voxel_world.h"
#include "nexus/core/log.h"
#include "nexus/generative/generative_pipeline.h"
#include "nexus/generative/generative_types.h"

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

auto boolParam(const nlohmann::json& params,
               std::string_view name,
               bool defaultValue) -> Result<bool> {
  const auto found = params.find(std::string(name));
  if (found == params.end()) {
    return Result<bool>::ok(defaultValue);
  }
  if (!found->is_boolean()) {
    return Result<bool>::err("dunk boolean parameter has invalid type");
  }
  return Result<bool>::ok(found->get<bool>());
}

auto stringParam(const nlohmann::json& params,
                 std::string_view name,
                 std::string& out) -> Result<void> {
  const auto found = params.find(std::string(name));
  if (found == params.end() || !found->is_string()) {
    return Result<void>::err("dunk string parameter '" + std::string(name) + "' is required");
  }
  out = found->get<std::string>();
  return Result<void>::ok();
}

} // namespace

GameplayApplication::GameplayApplication(creative::WorldManipulator& manipulator,
                                         const creative::VoxelWorld& voxelWorld)
    : m_voxelParser(manipulator, voxelWorld) {}

void GameplayApplication::setGenerativePipeline(
    generative::GenerativePipeline* generativePipeline) {
  m_generativePipeline = generativePipeline;
}

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

  if (command.rfind("fel.game.dunk.", 0) == 0) {
    return applyDunkCommand(command, params, id);
  }

  return response(id, "error", {}, "Unsupported gameplay command");
}

auto GameplayApplication::handleGameplayQuery(std::string_view query,
                                              const nlohmann::json& payload,
                                              std::string_view id) -> ai::AgentResponse {
  if (query == "fel.query.get_session_state") {
    return response(id, "ok", sessionStatePayload());
  }

  if (m_generativePipeline != nullptr && query.rfind("fel.generate.", 0) == 0) {
    auto result = m_generativePipeline->handleQuery(query, payload);
    if (result.isErr()) {
      return response(id, "error", {}, result.error());
    }
    return response(id, "ok", result.value());
  }

  return response(id, "error", {}, "Unsupported gameplay query");
}

auto GameplayApplication::fitness_data() -> ThreadSafeFitnessData& {
  return m_fitnessData;
}

auto GameplayApplication::throw_catch_state() const -> const ThrowCatchState& {
  return m_throwCatch.state();
}

auto GameplayApplication::dunk_contest() const -> const DunkContest* {
  return m_dunkContest.has_value() ? &m_dunkContest.value() : nullptr;
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

auto GameplayApplication::applyDunkCommand(std::string_view command,
                                           const nlohmann::json& params,
                                           std::string_view id) -> ai::AgentResponse {
  if (command == "fel.game.dunk.start") {
    DunkContestConfig config;
    const auto rounds = integerParam(params, "rounds", config.rounds);
    const auto attempts = integerParam(params, "attempts", config.attemptsPerRound);
    const auto judges = integerParam(params, "judges", config.judges);
    if (rounds.isErr()) {
      return response(id, "error", {}, rounds.error());
    }
    if (attempts.isErr()) {
      return response(id, "error", {}, attempts.error());
    }
    if (judges.isErr()) {
      return response(id, "error", {}, judges.error());
    }
    config.rounds = rounds.value();
    config.attemptsPerRound = attempts.value();
    config.judges = judges.value();

    const auto venue = params.find("venue");
    if (venue != params.end()) {
      if (!venue->is_string()) {
        return response(id, "error", {}, "dunk venue must be a string");
      }
      config.venueId = venue->get<std::string>();
    }

    DunkContest contest(config);
    const auto contestants = params.find("contestants");
    if (contestants != params.end()) {
      if (!contestants->is_array()) {
        return response(id, "error", {}, "dunk contestants must be an array");
      }
      for (const auto& entry : *contestants) {
        if (!entry.is_string()) {
          return response(id, "error", {}, "dunk contestant ids must be strings");
        }
        auto added = contest.addContestant(entry.get<std::string>());
        if (added.isErr()) {
          return response(id, "error", {}, added.error());
        }
      }
    }

    m_dunkContest.emplace(std::move(contest));
    NEXUS_LOG_INFO(LogChannel::kAI, "Basketball Dunk Contest started");
    return response(id, "ok", m_dunkContest->toJson());
  }

  if (command == "fel.game.dunk.score") {
    if (!m_dunkContest.has_value()) {
      return response(id, "error", {}, "no dunk contest in progress");
    }
    std::string contestant;
    std::string dunkType;
    const auto contestantParam = stringParam(params, "contestant", contestant);
    const auto dunkTypeParam = stringParam(params, "dunk_type", dunkType);
    const auto quality = floatParam(params, "quality", 0.0F);
    const auto completed = boolParam(params, "completed", true);
    if (contestantParam.isErr()) {
      return response(id, "error", {}, contestantParam.error());
    }
    if (dunkTypeParam.isErr()) {
      return response(id, "error", {}, dunkTypeParam.error());
    }
    if (quality.isErr()) {
      return response(id, "error", {}, quality.error());
    }
    if (completed.isErr()) {
      return response(id, "error", {}, completed.error());
    }

    auto attempt = m_dunkContest->scoreAttempt(
        contestant, dunkType, quality.value(), completed.value());
    if (attempt.isErr()) {
      return response(id, "error", {}, attempt.error());
    }
    const AttemptScore& scored = attempt.value();
    return response(id, "ok",
                    {
                        {"contestant", contestant},
                        {"dunk_type", scored.dunkTypeId},
                        {"completed", scored.completed},
                        {"judge_scores", scored.judgeScores},
                        {"total", scored.total},
                        {"contestant_total", m_dunkContest->contestantTotal(contestant)},
                    });
  }

  if (command == "fel.game.dunk.state") {
    if (!m_dunkContest.has_value()) {
      return response(id, "error", {}, "no dunk contest in progress");
    }
    return response(id, "ok", m_dunkContest->toJson());
  }

  return response(id, "error", {}, "Unsupported dunk command");
}

auto GameplayApplication::sessionStatePayload() const -> nlohmann::json {
  const auto fitness = m_fitnessData.snapshot();
  const auto& throwCatch = m_throwCatch.state();
  nlohmann::json generativeSummary = nlohmann::json::object();
  if (m_generativePipeline != nullptr) {
    nlohmann::json jobs = nlohmann::json::array();
    for (const generative::GenerativeJob& job : m_generativePipeline->modelGenerator().jobs()) {
      jobs.push_back(generative::jobToJson(job));
    }
    generativeSummary = {{"jobs", std::move(jobs)}};
  }

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
      {"generative", std::move(generativeSummary)},
      {"updates_completed", m_stats.updatesCompleted},
  };
}

} // namespace nexus::gameplay
