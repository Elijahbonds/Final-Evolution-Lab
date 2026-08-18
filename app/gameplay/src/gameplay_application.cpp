// File: app/gameplay/src/gameplay_application.cpp
// Part of: Final Evolution Lab (FEL) Game Logic
// Spec: 01 Gameplay Loop Protocol, 06 NEXUS Integration Map, 10 Phase 0/4
#include "nexus/gameplay/gameplay_application.h"

#include "nexus/creative/voxel_world.h"
#include "nexus/core/log.h"
#include "nexus/gameplay/arena_mode_registry.h"
#include "nexus/gameplay/scan_envelope_mapper.h"
#include "nexus/generative/generative_pipeline.h"
#include "nexus/generative/generative_types.h"

#include <algorithm>
#include <optional>
#include <span>
#include <string>
#include <utility>

namespace nexus::gameplay {

namespace {

auto floatParam(const nlohmann::json& params,
                std::string_view name,
                float defaultValue) -> Result<float> {
  if (!params.is_object()) {
    return Result<float>::err("fitness parameter object required");
  }
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
  if (!params.is_object()) {
    return Result<int>::err("fitness integer parameter object required");
  }
  const auto found = params.find(std::string(name));
  if (found == params.end()) {
    return Result<int>::ok(defaultValue);
  }
  if (!found->is_number_integer()) {
    return Result<int>::err("fitness integer parameter has invalid type");
  }
  return Result<int>::ok(found->get<int>());
}

auto stringParam(const nlohmann::json& params,
                 std::string_view name,
                 std::string defaultValue,
                 std::string& errorOut) -> std::optional<std::string> {
  if (!params.is_object()) {
    errorOut = "parameter object required";
    return std::nullopt;
  }
  const auto found = params.find(std::string(name));
  if (found == params.end()) {
    return defaultValue;
  }
  if (!found->is_string()) {
    errorOut = "parameter must be a string";
    return std::nullopt;
  }
  return found->get<std::string>();
}

auto response(std::string_view id,
              std::string status,
              nlohmann::json payload,
              std::string error = {}) -> ai::AgentResponse {
  return {std::string(id), std::move(status), std::move(payload), std::move(error)};
}

[[nodiscard]] auto applyValidatedScalar(float& field,
                                      float value,
                                      std::string_view fieldName) -> std::optional<std::string> {
  const auto validated = validateFitnessScalar(value, fieldName);
  if (validated.isErr()) {
    return validated.error();
  }
  field = validated.value();
  return std::nullopt;
}

auto gamePromptOptionsFromParams(const nlohmann::json& params) -> ai::GamePromptAdapterOptions {
  ai::GamePromptAdapterOptions options{};
  if (params.is_object()) {
    options.forceTemplate = params.value("force_template", false);
    if (params.contains("gemini_api_key") && params["gemini_api_key"].is_string()) {
      options.geminiApiKey = params["gemini_api_key"].get<std::string>();
    }
    if (params.contains("gemini_model") && params["gemini_model"].is_string()) {
      options.geminiModel = params["gemini_model"].get<std::string>();
    }
  }
  return options;
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

  const auto fitness = m_fitnessData.snapshot();
  if (m_arenaSession.state().phase == ArenaSessionPhase::kActive && !m_arenaSession.state().paused) {
    m_arenaSession.update(deltaSeconds, fitness);
    m_modeRuntime.update(deltaSeconds);
    syncArenaFromModeRuntime();
  }
  m_throwCatch.update(deltaSeconds, m_fitnessData.read_view(), physicsWorld);
  m_modeRuntime.onThrowCatchPulse(m_throwCatch.state());
  syncArenaFromModeRuntime();
  m_gameplayManager.tickReceiptClient(deltaSeconds);

  if (m_arenaSession.state().phase == ArenaSessionPhase::kActive &&
      m_modeRuntime.shouldAutoEndSession()) {
    const MatchScoreInput autoScore = m_modeRuntime.sessionScoreInput();
    const auto ended = m_arenaSession.endSession(
        autoScore, m_gameplayManager, fitness, m_modeRuntime.modeSpecificPayload());
    if (ended.isOk()) {
      m_felBridge.sendMatchScore(static_cast<int32_t>(ended.value().score),
                                 static_cast<int32_t>(ended.value().opponentScore));
      m_hudRelay.broadcastMessage("economy_update", sessionResultToJson(ended.value()));
    }
  }

  const float prqScore = fitness.frc.controlScore * 100.0F;
  if (m_arenaSession.state().phase == ArenaSessionPhase::kActive) {
    const auto& arenaState = m_arenaSession.state();
    m_felBridge.tickVaultTelemetry(
        arenaState.modeId,
        prqScore,
        static_cast<float>(arenaState.comboCount),
        static_cast<float>(arenaState.playerScore),
        deltaSeconds);
  }
  m_felBridge.tickFocusKeepalive(deltaSeconds);
  processVenueOverlaps();
  emitHudTickFrame();

  ++m_stats.updatesCompleted;
}

auto GameplayApplication::handleGameplayCommand(std::string_view command,
                                                const nlohmann::json& params,
                                                std::string_view id) -> ai::AgentResponse {
  const nlohmann::json& safeParams = params.is_object() ? params : nlohmann::json::object();
  if (command.rfind("fel.fitness.", 0) == 0 || command.rfind("fitness.", 0) == 0) {
    return applyFitnessCommand(command, safeParams, id);
  }

  if (command.rfind("fel.creative.", 0) == 0) {
    if (command == "fel.creative.from_text") {
      return applyTextGenerationCommand(command, safeParams, id);
    }
    auto result = m_voxelParser.apply_command(command, safeParams);
    if (result.isErr()) {
      return response(id, "error", {}, result.error());
    }
    return response(id, "ok", result.value());
  }

  if (command.rfind("fel.arena.", 0) == 0) {
    return applyArenaCommand(command, safeParams, id);
  }

  if (command.rfind("fel.bridge.", 0) == 0) {
    return applyBridgeCommand(command, safeParams, id);
  }

  if (command.rfind("fel.venue.", 0) == 0) {
    return applyVenueCommand(command, safeParams, id);
  }

  if (command.rfind("fel.hud.", 0) == 0) {
    return applyHudCommand(command, safeParams, id);
  }

  if (command == "fel.generate.arena_from_scan") {
    return applyScanGenerateCommand(command, safeParams, id);
  }

  if (command == "fel.generate.from_text") {
    return applyTextGenerationCommand(command, safeParams, id);
  }

  if (command == "fel.generate.game" || command == "fel.generate.refine_game") {
    return applyGameGenerationCommand(command, safeParams, id);
  }

  if (command.rfind("fel.dunk.", 0) == 0 || command.rfind("fel.karate.", 0) == 0 ||
      command.rfind("fel.pickup.", 0) == 0 || command.rfind("fel.carnival.", 0) == 0 || command.rfind("fel.gymnastics.", 0) == 0 ||
      command.rfind("fel.brain.", 0) == 0 || command.rfind("fel.skate.", 0) == 0 ||
      command.rfind("fel.snow.", 0) == 0 || command.rfind("fel.surf.", 0) == 0 ||
      command.rfind("fel.scene.", 0) == 0 ||
      command.rfind("fel.sport.", 0) == 0 ||
      command.rfind("fel.mode.", 0) == 0) {
    const auto modeResult = m_modeRuntime.handleCommand(command, safeParams);
    if (modeResult.isErr()) {
      return response(id, "error", {}, modeResult.error());
    }
    if (m_arenaSession.state().phase == ArenaSessionPhase::kActive) {
      const auto& modeState = modeResult.value();
      if (modeState.is_object()) {
        if (modeState.contains("player_score")) {
          m_arenaSession.updateScores(modeState.value("player_score", 0.0F),
                                      modeState.value("opponent_score", 0.0F));
        } else if (modeState.contains("dunk") && modeState["dunk"].is_object()) {
          m_arenaSession.updateScores(modeState["dunk"].value("player_score", 0.0F),
                                      modeState["dunk"].value("opponent_score", 0.0F));
        } else if (modeState.contains("karate") && modeState["karate"].is_object()) {
          m_arenaSession.updateScores(modeState["karate"].value("score", 0.0F), 0.0F);
        } else if (modeState.contains("pickup") && modeState["pickup"].is_object()) {
          m_arenaSession.updateScores(modeState["pickup"].value("player_score", 0.0F),
                                      modeState["pickup"].value("opponent_score", 0.0F));
        } else if (modeState.contains("carnival") && modeState["carnival"].is_object()) {
          m_arenaSession.updateScores(modeState["carnival"].value("player_score", 0.0F),
                                      modeState["carnival"].value("opponent_score", 0.0F));
        } else if (modeState.contains("gymnastics") && modeState["gymnastics"].is_object()) {
          m_arenaSession.updateScores(modeState["gymnastics"].value("judge_score", 0.0F), 0.0F);
        } else if (modeState.contains("brain_brawl") && modeState["brain_brawl"].is_object()) {
          m_arenaSession.updateScores(
              static_cast<float>(modeState["brain_brawl"].value("player_correct", 0)),
              static_cast<float>(modeState["brain_brawl"].value("opponent_correct", 0)));
        } else if (modeState.contains("skateboarding") && modeState["skateboarding"].is_object()) {
          m_arenaSession.updateScores(
              static_cast<float>(modeState["skateboarding"].value("trick_score", 0)), 0.0F);
        } else if (modeState.contains("snowboarding") && modeState["snowboarding"].is_object()) {
          m_arenaSession.updateScores(
              static_cast<float>(modeState["snowboarding"].value("line_score", 0)), 0.0F);
        } else if (modeState.contains("surfing") && modeState["surfing"].is_object()) {
          m_arenaSession.updateScores(
              static_cast<float>(modeState["surfing"].value("wave_score", 0)), 0.0F);
        } else if (modeState.contains("who_scene_it") && modeState["who_scene_it"].is_object()) {
          m_arenaSession.updateScores(
              static_cast<float>(modeState["who_scene_it"].value("correct_count", 0)),
              static_cast<float>(modeState["who_scene_it"].value("opponent_correct", 0)));
        } else if (modeState.contains("outcome_sport") &&
                   modeState["outcome_sport"].is_object()) {
          m_arenaSession.updateScores(
              modeState["outcome_sport"].value("player_score", 0.0F),
              modeState["outcome_sport"].value("opponent_score", 0.0F));
        } else if (modeState.contains("player_correct") &&
                   modeState.contains("opponent_correct")) {
          m_arenaSession.updateScores(
              static_cast<float>(modeState.value("player_correct", 0)),
              static_cast<float>(modeState.value("opponent_correct", 0)));
        } else if (modeState.contains("line_score")) {
          m_arenaSession.updateScores(
              static_cast<float>(modeState.value("line_score", 0)), 0.0F);
        } else if (modeState.contains("trick_score")) {
          m_arenaSession.updateScores(
              static_cast<float>(modeState.value("trick_score", 0)), 0.0F);
        } else if (modeState.contains("wave_score")) {
          m_arenaSession.updateScores(
              static_cast<float>(modeState.value("wave_score", 0)), 0.0F);
        } else if (modeState.contains("score")) {
          m_arenaSession.updateScores(modeState.value("score", 0.0F), 0.0F);
        }
      }
      syncArenaFromModeRuntime();
      emitHudTickFrame();
    }
    return response(id, "ok", modeResult.value());
  }

  return response(id, "error", {}, "Unsupported gameplay command");
}

auto GameplayApplication::handleGameplayQuery(std::string_view query,
                                              const nlohmann::json& payload,
                                              std::string_view id) -> ai::AgentResponse {
  if (query == "fel.query.get_session_state") {
    return response(id, "ok", sessionStatePayload());
  }

  if (query == "fel.query.get_arena_state") {
    return response(id, "ok", m_arenaSession.stateJson());
  }

  if (query == "fel.query.list_arena_modes") {
    nlohmann::json modes = nlohmann::json::array();
    for (const ArenaModeConfig& config : ArenaModeRegistry::allModes()) {
      modes.push_back(ArenaModeRegistry::modeToJson(config));
    }
    return response(id, "ok", {{"modes", std::move(modes)}});
  }

  if (query == "fel.query.get_exercise_demo") {
    std::string paramError;
    const auto modeId = stringParam(payload, "mode_id", "basketball_dunk", paramError);
    if (!modeId.has_value()) {
      return response(id, "error", {}, paramError);
    }
    return response(id, "ok", ExerciseDemoPipeline::mappingJson(*modeId));
  }

  if (query == "fel.query.get_bridge_outbound") {
    nlohmann::json messages = nlohmann::json::array();
    for (const nlohmann::json& message : m_felBridge.outboundMessages()) {
      messages.push_back(message);
    }
    return response(id, "ok", {{"messages", std::move(messages)}});
  }

  if (query == "fel.query.get_pending_session_receipts") {
    nlohmann::json receipts = nlohmann::json::array();
    for (const nlohmann::json& receipt : m_gameplayManager.pendingReceipts()) {
      receipts.push_back(receipt);
    }
    return response(id, "ok", {{"receipts", std::move(receipts)}});
  }

  if (query == "fel.query.get_hud_pending_frames") {
    nlohmann::json frames = nlohmann::json::array();
    for (const nlohmann::json& frame : m_hudRelay.pendingFrames()) {
      frames.push_back(frame);
    }
    return response(id, "ok", {{"frames", std::move(frames)}});
  }

  if (query == "fel.hud.poll" || query == "fel.query.hud_poll") {
    return response(id, "ok", m_hudRelay.pollFrame());
  }

  if (query == "fel.query.get_mode_state") {
    return response(id, "ok", m_modeRuntime.stateJson());
  }

  if (query == "fel.query.get_fitness_state") {
    return response(id, "ok", fitnessSnapshotToJson(m_fitnessData.snapshot()));
  }

  if (query == "fel.query.get_throw_catch_state") {
    return response(id, "ok", ThrowCatchPhysicsController::stateToJson(m_throwCatch.state()));
  }

  if (query == "fel.generate.parse_prompt") {
    return applyTextGenerationQuery(query, payload, id);
  }

  if (query == "fel.generate.parse_game") {
    return applyGameGenerationQuery(query, payload, id);
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

auto GameplayApplication::stats() const -> const GameplayUpdateStats& {
  return m_stats;
}

auto GameplayApplication::arena_session() const -> const ArenaSessionManager& {
  return m_arenaSession;
}

auto GameplayApplication::gameplay_manager() const -> const GameplayManager& {
  return m_gameplayManager;
}

auto GameplayApplication::fel_bridge() const -> const FelBridgeService& {
  return m_felBridge;
}

auto GameplayApplication::hud_relay() const -> const HudRelayService& {
  return m_hudRelay;
}

auto GameplayApplication::mode_runtime() const -> const ModeRuntime& {
  return m_modeRuntime;
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

  if (!isFullUpdate) {
    bool hasRecognizedParam = false;
    for (const auto& [key, _] : params.items()) {
      if (key.rfind("frc_", 0) == 0 || key.rfind("iap_", 0) == 0 || key == "breath_phase") {
        hasRecognizedParam = true;
        break;
      }
    }
    if (!hasRecognizedParam) {
      return response(id, "error", {}, "fitness partial update requires at least one metric param");
    }
  }

  const auto current = m_fitnessData.snapshot();
  FRCMetrics frc = current.frc;
  IAPMetrics iap = current.iap;

  if (isFullUpdate || isFrcUpdate) {
    if (params.contains("frc_mobility")) {
      const auto frcMobility = floatParam(params, "frc_mobility", frc.mobilityScore);
      if (frcMobility.isErr()) {
        return response(id, "error", {}, frcMobility.error());
      }
      const auto validated = validateFitnessScalar(frcMobility.value(), "frc_mobility");
      if (validated.isErr()) {
        return response(id, "error", {}, validated.error());
      }
      frc.mobilityScore = validated.value();
    }
    if (params.contains("frc_active_range")) {
      const auto frcRange = floatParam(params, "frc_active_range", frc.activeRangeScore);
      if (frcRange.isErr()) {
        return response(id, "error", {}, frcRange.error());
      }
      const auto validated = validateFitnessScalar(frcRange.value(), "frc_active_range");
      if (validated.isErr()) {
        return response(id, "error", {}, validated.error());
      }
      frc.activeRangeScore = validated.value();
    }
    if (params.contains("frc_control")) {
      const auto frcControl = floatParam(params, "frc_control", frc.controlScore);
      if (frcControl.isErr()) {
        return response(id, "error", {}, frcControl.error());
      }
      const auto validated = validateFitnessScalar(frcControl.value(), "frc_control");
      if (validated.isErr()) {
        return response(id, "error", {}, validated.error());
      }
      frc.controlScore = validated.value();
    }
    if (isFullUpdate) {
      if (!params.contains("frc_mobility")) {
        if (const auto error = applyValidatedScalar(frc.mobilityScore, frc.mobilityScore,
                                                    "frc_mobility")) {
          return response(id, "error", {}, *error);
        }
      }
      if (!params.contains("frc_active_range")) {
        if (const auto error = applyValidatedScalar(frc.activeRangeScore, frc.activeRangeScore,
                                                    "frc_active_range")) {
          return response(id, "error", {}, *error);
        }
      }
      if (!params.contains("frc_control")) {
        if (const auto error =
                applyValidatedScalar(frc.controlScore, frc.controlScore, "frc_control")) {
          return response(id, "error", {}, *error);
        }
      }
    }
  }

  if (isFullUpdate || isIapUpdate) {
    if (params.contains("iap_engagement")) {
      const auto iapEngagement = floatParam(params, "iap_engagement", iap.engagementScore);
      if (iapEngagement.isErr()) {
        return response(id, "error", {}, iapEngagement.error());
      }
      const auto validated = validateFitnessScalar(iapEngagement.value(), "iap_engagement");
      if (validated.isErr()) {
        return response(id, "error", {}, validated.error());
      }
      iap.engagementScore = validated.value();
    }
    if (params.contains("iap_confidence")) {
      const auto iapConfidence = floatParam(params, "iap_confidence", iap.confidence);
      if (iapConfidence.isErr()) {
        return response(id, "error", {}, iapConfidence.error());
      }
      const auto validated = validateFitnessScalar(iapConfidence.value(), "iap_confidence");
      if (validated.isErr()) {
        return response(id, "error", {}, validated.error());
      }
      iap.confidence = validated.value();
    }
    if (params.contains("breath_phase")) {
      const auto breathPhase = integerParam(params, "breath_phase", iap.breathPhase);
      if (breathPhase.isErr()) {
        return response(id, "error", {}, breathPhase.error());
      }
      const auto validated = validateBreathPhase(breathPhase.value());
      if (validated.isErr() && isIapUpdate) {
        return response(id, "error", {}, validated.error());
      }
      iap.breathPhase = validated.isOk()
                            ? validated.value()
                            : static_cast<std::int8_t>(std::clamp(breathPhase.value(), -1, 1));
    }
    if (isFullUpdate) {
      if (!params.contains("iap_engagement")) {
        if (const auto error = applyValidatedScalar(iap.engagementScore, iap.engagementScore,
                                                    "iap_engagement")) {
          return response(id, "error", {}, *error);
        }
      }
      if (!params.contains("iap_confidence")) {
        if (const auto error =
                applyValidatedScalar(iap.confidence, iap.confidence, "iap_confidence")) {
          return response(id, "error", {}, *error);
        }
      }
    }
  }

  if (isFrcUpdate) {
    m_fitnessData.update_frc(frc);
  } else if (isIapUpdate) {
    m_fitnessData.update_iap(iap);
  } else {
    m_fitnessData.update(frc, iap);
  }

  const auto snapshot = m_fitnessData.snapshot();
  NEXUS_LOG_INFO(LogChannel::kAI, "Fitness metrics updated from agent command");
  nlohmann::json payload = fitnessSnapshotToJson(snapshot);
  payload["hud"] = {
      {"frc_composite", snapshot.frcComposite},
      {"iap_composite", snapshot.iapComposite},
      {"power_readiness", snapshot.powerReadiness},
      {"breath_phase", snapshot.iap.breathPhase},
      {"catch_radius_hint", snapshot.frc.controlScore},
  };
  return response(id, "ok", std::move(payload));
}

auto GameplayApplication::applyScanGenerateCommand(std::string_view command,
                                                   const nlohmann::json& params,
                                                   std::string_view id) -> ai::AgentResponse {
  if (command != "fel.generate.arena_from_scan") {
    return response(id, "error", {}, "Unsupported scan generate command");
  }

  const nlohmann::json envelope =
      params.contains("envelope") && params["envelope"].is_object() ? params["envelope"] : params;

  const auto mapped = mapScanEnvelope(envelope);
  if (mapped.isErr()) {
    return response(id, "error", {}, mapped.error());
  }

  const auto& result = mapped.value();
  m_fitnessData.update(result.frc, result.iap);

  const int radius = result.generative.paintRadius;
  const int material = result.generative.voxelMaterial;
  const auto origin = result.generative.paintOrigin;
  const nlohmann::json fillParams = {
      {"min", {origin[0] - radius, origin[1], origin[2] - radius}},
      {"max", {origin[0] + radius, origin[1], origin[2] + radius}},
      {"voxel", {{"material", material}, {"solid", true}}},
  };

  auto fillResult = m_voxelParser.apply_command("fel.creative.fill_region", fillParams);
  if (fillResult.isErr()) {
    return response(id, "error", {}, fillResult.error());
  }

  const auto fitnessSnapshot = m_fitnessData.snapshot();
  nlohmann::json commandsApplied = nlohmann::json::array({
      "fel.fitness.update",
      "fel.creative.fill_region",
      "fel.generate.arena_from_scan",
  });

  NEXUS_LOG_INFO(LogChannel::kGenerative,
                 "Scan envelope applied: arena_scale=" +
                     std::to_string(result.generative.arenaScale) + " mode=" +
                     result.generative.recommendedModeId);

  return response(
      id,
      "ok",
      {
          {"fitness", fitnessSnapshotToJson(fitnessSnapshot)},
          {"generative",
           {
               {"arena_scale", result.generative.arenaScale},
               {"difficulty_tier", result.generative.difficultyTier},
               {"recommended_mode_id", result.generative.recommendedModeId},
               {"voxel_material", material},
               {"paint_radius", radius},
           }},
          {"creative", fillResult.value()},
          {"commands_applied", std::move(commandsApplied)},
          {"preview_label", "GENERATED FROM SCAN · NOT METAHUMAN MESH"},
      });
}

auto GameplayApplication::executeTextPlan(const ai::TextGenerationPlan& plan, bool creativeOnly)
    -> Result<nlohmann::json> {
  nlohmann::json stepResults = nlohmann::json::array();
  nlohmann::json jobs = nlohmann::json::array();
  std::size_t appliedSteps = 0;
  std::size_t skippedSteps = 0;

  for (const ai::ParsedAgentStep& step : plan.steps) {
    const bool isCreative = step.command.rfind("fel.creative.", 0) == 0;
    const bool isGenerative =
        step.command.rfind("fel.generate.", 0) == 0 || step.command.rfind("fel.scan.", 0) == 0;

    if (creativeOnly && !isCreative) {
      ++skippedSteps;
      continue;
    }

    if (isCreative) {
      auto creativeResult = m_voxelParser.apply_command(step.command, step.params);
      if (creativeResult.isErr()) {
        return Result<nlohmann::json>::err(creativeResult.error());
      }
      stepResults.push_back({{"command", step.command},
                             {"status", "ok"},
                             {"result", creativeResult.value()},
                             {"rationale", step.rationale}});
      ++appliedSteps;
      continue;
    }

    if (!isGenerative) {
      return Result<nlohmann::json>::err("Unsupported planned command: " + step.command);
    }

    if (m_generativePipeline == nullptr) {
      return Result<nlohmann::json>::err("Generative pipeline required for: " + step.command);
    }

    auto generativeResult = m_generativePipeline->handleCommand(step.command, step.params);
    if (generativeResult.isErr()) {
      return Result<nlohmann::json>::err(generativeResult.error());
    }

    stepResults.push_back({{"command", step.command},
                           {"status", "ok"},
                           {"result", generativeResult.value()},
                           {"rationale", step.rationale}});
    if (step.command == "fel.generate.create_model") {
      jobs.push_back(generativeResult.value());
    }
    ++appliedSteps;
  }

  return Result<nlohmann::json>::ok({
      {"plan", plan.toJson()},
      {"steps_applied", appliedSteps},
      {"steps_skipped", skippedSteps},
      {"step_results", std::move(stepResults)},
      {"jobs", std::move(jobs)},
      {"import_pipeline", "scripts/nexus_import_assets.py"},
  });
}

auto GameplayApplication::applyTextGenerationQuery(std::string_view query,
                                                   const nlohmann::json& payload,
                                                   std::string_view id) -> ai::AgentResponse {
  if (query != "fel.generate.parse_prompt") {
    return response(id, "error", {}, "Unsupported text generation query");
  }

  std::string paramError;
  const auto text = stringParam(payload, "text", {}, paramError);
  if (!text.has_value() || text->empty()) {
    return response(id, "error", {}, paramError.empty() ? "text required" : paramError);
  }

  ai::TextPromptAdapterOptions options{};
  if (payload.contains("default_position") && payload["default_position"].is_array() &&
      payload["default_position"].size() == 3) {
    options.defaultPosition = {payload["default_position"][0].get<int>(),
                               payload["default_position"][1].get<int>(),
                               payload["default_position"][2].get<int>()};
  }

  const auto planResult = ai::parseTextPrompt(*text, options);
  if (planResult.isErr()) {
    return response(id, "error", {}, planResult.error());
  }

  return response(id, "ok", planResult.value().toJson());
}

auto GameplayApplication::applyTextGenerationCommand(std::string_view command,
                                                     const nlohmann::json& params,
                                                     std::string_view id) -> ai::AgentResponse {
  if (command != "fel.generate.from_text" && command != "fel.creative.from_text") {
    return response(id, "error", {}, "Unsupported text generation command");
  }

  std::string paramError;
  const auto text = stringParam(params, "text", {}, paramError);
  if (!text.has_value() || text->empty()) {
    if (params.contains("prompt") && params["prompt"].is_string()) {
      paramError.clear();
    } else {
      return response(id, "error", {}, paramError.empty() ? "text or prompt required" : paramError);
    }
  }

  const std::string promptText =
      text.has_value() && !text->empty() ? *text : params["prompt"].get<std::string>();

  ai::TextPromptAdapterOptions options{};
  if (params.contains("default_position") && params["default_position"].is_array() &&
      params["default_position"].size() == 3) {
    options.defaultPosition = {params["default_position"][0].get<int>(),
                               params["default_position"][1].get<int>(),
                               params["default_position"][2].get<int>()};
  }

  const auto planResult = ai::parseTextPrompt(promptText, options);
  if (planResult.isErr()) {
    return response(id, "error", {}, planResult.error());
  }

  const bool creativeOnly = command == "fel.creative.from_text";
  if (!creativeOnly && m_generativePipeline == nullptr) {
    return response(id, "error", {}, "Generative pipeline not configured");
  }

  m_hudRelay.broadcastMessage(
      "generative_progress",
      {{"phase", "executing"},
       {"prompt", promptText},
       {"intent", planResult.value().intent},
       {"step_count", planResult.value().steps.size()}});

  const auto executed = executeTextPlan(planResult.value(), creativeOnly);
  if (executed.isErr()) {
    m_hudRelay.broadcastMessage("generative_progress",
                                {{"phase", "failed"},
                                 {"prompt", promptText},
                                 {"error", executed.error()}});
    return response(id, "error", {}, executed.error());
  }

  nlohmann::json payload = executed.value();
  payload["intent"] = planResult.value().intent;
  payload["agent_summary"] = creativeOnly
                                 ? "Creative terrain plan applied from text prompt"
                                 : "Generative arena plan executed from text prompt";
  payload["preview_label"] = "GENERATED FROM PROMPT · NOT METAHUMAN MESH";

  m_hudRelay.broadcastMessage("generative_progress",
                              {{"phase", "complete"},
                               {"prompt", promptText},
                               {"intent", planResult.value().intent},
                               {"steps_applied", payload["steps_applied"]},
                               {"jobs", payload["jobs"]}});

  NEXUS_LOG_INFO(LogChannel::kGenerative,
                 "Text prompt plan executed: intent=" + planResult.value().intent +
                     " steps=" + std::to_string(payload["steps_applied"].get<std::size_t>()));

  return response(id, "ok", std::move(payload));
}

auto GameplayApplication::applyGameGenerationQuery(std::string_view query,
                                                   const nlohmann::json& payload,
                                                   std::string_view id) -> ai::AgentResponse {
  if (query != "fel.generate.parse_game") {
    return response(id, "error", {}, "Unsupported game generation query");
  }

  std::string paramError;
  const auto text = stringParam(payload, "text", {}, paramError);
  if (!text.has_value() || text->empty()) {
    if (payload.contains("prompt") && payload["prompt"].is_string()) {
      const auto planResult = ai::parseGamePrompt(payload["prompt"].get<std::string>(),
                                                  gamePromptOptionsFromParams(payload));
      if (planResult.isErr()) {
        return response(id, "error", {}, planResult.error());
      }
      return response(id, "ok", planResult.value().toJson());
    }
    return response(id, "error", {}, paramError.empty() ? "text required" : paramError);
  }

  const auto planResult = ai::parseGamePrompt(*text, gamePromptOptionsFromParams(payload));
  if (planResult.isErr()) {
    return response(id, "error", {}, planResult.error());
  }

  return response(id, "ok", planResult.value().toJson());
}

auto GameplayApplication::applyGameGenerationCommand(std::string_view command,
                                                     const nlohmann::json& params,
                                                     std::string_view id) -> ai::AgentResponse {
  if (command != "fel.generate.game" && command != "fel.generate.refine_game") {
    return response(id, "error", {}, "Unsupported game generation command");
  }

  ai::GameGenerationSpec spec{};
  bool specResolved = false;

  if (command == "fel.generate.refine_game") {
    std::string paramError;
    const auto refinement = stringParam(params, "text", {}, paramError);
    const std::string refinementText =
        refinement.has_value() && !refinement->empty()
            ? *refinement
            : params.value("refinement", std::string{});

    if (refinementText.empty()) {
      return response(id, "error", {}, "text or refinement required");
    }

    ai::GameGenerationSpec baseSpec{};
    if (params.contains("spec") && params["spec"].is_object()) {
      const auto parsed = ai::gameSpecFromJson(params["spec"]);
      if (parsed.isErr()) {
        return response(id, "error", {}, parsed.error());
      }
      baseSpec = parsed.value();
    } else if (m_lastGameSpec.has_value()) {
      baseSpec = *m_lastGameSpec;
    } else {
      return response(id, "error", {}, "No base game spec — run fel.generate.game first or pass spec");
    }

    const auto refined = ai::refineGameSpec(baseSpec, refinementText);
    if (refined.isErr()) {
      return response(id, "error", {}, refined.error());
    }
    spec = refined.value();
    specResolved = true;
  } else {
    std::string paramError;
    const auto text = stringParam(params, "text", {}, paramError);
    if (!text.has_value() || text->empty()) {
      if (params.contains("prompt") && params["prompt"].is_string()) {
        const auto parsed = ai::parseGamePrompt(params["prompt"].get<std::string>(),
                                                gamePromptOptionsFromParams(params));
        if (parsed.isErr()) {
          return response(id, "error", {}, parsed.error());
        }
        spec = parsed.value();
        specResolved = true;
      } else {
        return response(id, "error", {}, paramError.empty() ? "text or prompt required" : paramError);
      }
    } else {
      const auto parsed = ai::parseGamePrompt(*text, gamePromptOptionsFromParams(params));
      if (parsed.isErr()) {
        return response(id, "error", {}, parsed.error());
      }
      spec = parsed.value();
      specResolved = true;
    }
  }

  if (!specResolved) {
    return response(id, "error", {}, "game spec not resolved");
  }
  m_lastGameSpec = spec;

  const bool includeArena = params.value("include_arena", false);
  const bool startSession = params.value("start_session", true);
  const std::string userId = params.value("user_id", "generator_user");

  nlohmann::json arenaResult = nlohmann::json::object();
  if (includeArena && !spec.arenaPrompt.empty()) {
    if (m_generativePipeline == nullptr) {
      return response(id, "error", {}, "Generative pipeline not configured for arena steps");
    }
    const auto planResult = ai::parseTextPrompt(spec.arenaPrompt);
    if (planResult.isErr()) {
      return response(id, "error", {}, planResult.error());
    }
    const auto executed = executeTextPlan(planResult.value(), false);
    if (executed.isErr()) {
      return response(id, "error", {}, executed.error());
    }
    arenaResult = executed.value();
  }

  nlohmann::json sessionState = nlohmann::json::object();
  if (startSession) {
    const auto started = m_arenaSession.startSession(spec.modeId, userId);
    if (started.isErr()) {
      return response(id, "error", {}, started.error());
    }
    const auto modeSet = m_modeRuntime.setMode(spec.modeId);
    if (modeSet.isErr()) {
      return response(id, "error", {}, modeSet.error());
    }
    m_felBridge.notifyVenueTravel(spec.venueToken, spec.modeId);
    m_felBridge.emitVaultSessionSnapshot(spec.modeId, 0.0F, 0.0F, 0.0F);
    sessionState = m_arenaSession.stateJson();
  }

  m_hudRelay.broadcastMessage(
      "generative_progress",
      {{"phase", command == "fel.generate.refine_game" ? "refined" : "game_generated"},
       {"mode_id", spec.modeId},
       {"spec_id", spec.specId},
       {"preview_label", spec.hudTheme.value("preview_label", "PREVIEW · GENERATED GAME SPEC")}});

  nlohmann::json payload = spec.toJson();
  payload["game_spec"] = spec.toJson();
  payload["agent_summary"] = command == "fel.generate.refine_game"
                                 ? "Game spec refined from follow-up prompt"
                                 : "Playable game spec generated from natural language";
  payload["preview_label"] = "PREVIEW · GENERATED GAME SPEC · NOT SEELE FULL SYNTHESIS";
  payload["session_started"] = startSession;
  if (!arenaResult.empty()) {
    payload["arena_steps"] = std::move(arenaResult);
  }
  if (!sessionState.empty()) {
    payload["session_state"] = std::move(sessionState);
  }

  return response(id, "ok", std::move(payload));
}

auto GameplayApplication::applyArenaCommand(std::string_view command,
                                            const nlohmann::json& params,
                                            std::string_view id) -> ai::AgentResponse {
  std::string paramError;
  if (command == "fel.arena.start_session") {
    const auto modeId = stringParam(params, "mode_id", {}, paramError);
    const auto userId = stringParam(params, "user_id", "anonymous", paramError);
    if (!modeId.has_value() || modeId->empty() || !userId.has_value()) {
      return response(id, "error", {}, paramError.empty() ? "mode_id required" : paramError);
    }
    const auto started = m_arenaSession.startSession(*modeId, *userId);
    if (started.isErr()) {
      return response(id, "error", {}, started.error());
    }
    const auto modeSet = m_modeRuntime.setMode(*modeId);
    if (modeSet.isErr()) {
      return response(id, "error", {}, modeSet.error());
    }
    m_felBridge.notifyVenueTravel(ArenaModeRegistry::venueTokenForMode(*modeId), *modeId);
    m_felBridge.emitVaultSessionSnapshot(*modeId, 0.0F, 0.0F, 0.0F);
    return response(id, "ok", m_arenaSession.stateJson());
  }

  if (command == "fel.arena.set_mode") {
    const auto modeId = stringParam(params, "mode_id", {}, paramError);
    if (!modeId.has_value()) {
      return response(id, "error", {}, paramError.empty() ? "mode_id required" : paramError);
    }
    const auto result = m_arenaSession.setMode(*modeId);
    if (result.isErr()) {
      return response(id, "error", {}, result.error());
    }
    const auto modeSet = m_modeRuntime.setMode(*modeId);
    if (modeSet.isErr()) {
      return response(id, "error", {}, modeSet.error());
    }
    return response(id, "ok", m_arenaSession.stateJson());
  }

  if (command == "fel.arena.update_score") {
    const auto playerScore = floatParam(params, "player_score", 0.0F);
    const auto opponentScore = floatParam(params, "opponent_score", 0.0F);
    if (playerScore.isErr()) {
      return response(id, "error", {}, playerScore.error());
    }
    if (opponentScore.isErr()) {
      return response(id, "error", {}, opponentScore.error());
    }
    m_arenaSession.updateScores(playerScore.value(), opponentScore.value());
    return response(id, "ok", m_arenaSession.stateJson());
  }

  if (command == "fel.arena.pause_session") {
    m_arenaSession.pauseSession();
    return response(id, "ok", m_arenaSession.stateJson());
  }

  if (command == "fel.arena.resume_session") {
    m_arenaSession.resumeSession();
    return response(id, "ok", m_arenaSession.stateJson());
  }

  if (command == "fel.arena.mode_input") {
    const std::string action = params.value("action", "");
    if (action == "charge_begin") {
      return handleGameplayCommand("fel.dunk.charge_begin", params, id);
    }
    if (action == "charge_release") {
      return handleGameplayCommand("fel.dunk.charge_release", params, id);
    }
    if (action == "apex_tap") {
      return handleGameplayCommand("fel.dunk.apex_tap", params, id);
    }
    if (action == "strike" || action == "light_strike") {
      return handleGameplayCommand("fel.karate.action", {{"action", "light_strike"}}, id);
    }
    if (action == "heavy_strike") {
      return handleGameplayCommand("fel.karate.action", {{"action", "heavy_strike"}}, id);
    }
    if (action == "block") {
      return handleGameplayCommand("fel.karate.action", {{"action", "block"}}, id);
    }
    if (action == "dodge") {
      return handleGameplayCommand("fel.karate.action", {{"action", "dodge"}}, id);
    }
    if (action == "counter") {
      return handleGameplayCommand("fel.karate.action", {{"action", "counter"}}, id);
    }
    if (action == "carnival_pad") {
      return handleGameplayCommand(
          "fel.carnival.trigger_pad",
          {{"pad", params.value("pad", "trick_shot")},
           {"timing", params.value("timing", 0.85F)}},
          id);
    }
    if (action == "roll_dice") {
      return handleGameplayCommand("fel.carnival.roll_dice", {}, id);
    }
    return response(id, "error", {}, "unsupported mode_input action");
  }

  if (command == "fel.arena.flush_receipts") {
    nexus::gameplay::SessionReceiptClientConfig config = m_gameplayManager.receiptClientConfig();
    if (params.contains("queue_directory")) {
      config.queueDirectory = params.value("queue_directory", config.queueDirectory);
    }
    if (params.contains("base_url")) {
      config.baseUrl = params.value("base_url", config.baseUrl);
    }
    if (params.contains("auth_token")) {
      config.authToken = params.value("auth_token", config.authToken);
    }
    if (params.contains("persist_to_disk")) {
      config.persistToDisk = params.value("persist_to_disk", config.persistToDisk);
    }
    if (params.contains("http_enabled")) {
      config.httpEnabled = params.value("http_enabled", config.httpEnabled);
    }
    if (params.contains("use_stub_http_transport")) {
      config.useStubHttpTransport =
          params.value("use_stub_http_transport", config.useStubHttpTransport);
    }
    if (params.contains("use_stub_transport")) {
      config.useStubHttpTransport = params.value("use_stub_transport", config.useStubHttpTransport);
    }
    if (params.contains("flush_interval_seconds")) {
      config.flushIntervalSeconds =
          params.value("flush_interval_seconds", config.flushIntervalSeconds);
    }
    if (params.contains("max_retries")) {
      config.maxRetries = params.value("max_retries", config.maxRetries);
    }
    m_gameplayManager.setReceiptClientConfig(std::move(config));
    const auto flushResult = m_gameplayManager.flushPendingReceipts();
    return response(id, "ok",
                    {
                        {"attempted", flushResult.attempted},
                        {"delivered", flushResult.delivered},
                        {"requeued", flushResult.requeued},
                        {"queued_on_disk", flushResult.queued_on_disk},
                        {"queue_directory", m_gameplayManager.receiptQueueDirectory()},
                        {"http_enabled", m_gameplayManager.receiptClientConfig().httpEnabled},
                        {"use_stub_http_transport",
                         m_gameplayManager.receiptClientConfig().useStubHttpTransport},
                    });
  }

  if (command == "fel.arena.end_session") {
    MatchScoreInput scoreInput = resolveEndSessionScores(params);
    const auto ended = m_arenaSession.endSession(
        scoreInput,
        m_gameplayManager,
        m_fitnessData.snapshot(),
        m_modeRuntime.modeSpecificPayload());
    if (ended.isErr()) {
      return response(id, "error", {}, ended.error());
    }
    m_felBridge.sendMatchScore(static_cast<int32_t>(ended.value().score),
                               static_cast<int32_t>(ended.value().opponentScore));
    m_hudRelay.broadcastMessage("economy_update", sessionResultToJson(ended.value()));
    return response(id, "ok", buildEndSessionPayload(ended.value()));
  }

  return response(id, "error", {}, "Unsupported arena command");
}

auto GameplayApplication::applyBridgeCommand(std::string_view command,
                                             const nlohmann::json& params,
                                             std::string_view id) -> ai::AgentResponse {
  std::string paramError;
  if (command == "fel.bridge.notify_venue_travel") {
    const auto venueToken = stringParam(params, "venue_token", {}, paramError);
    const auto modeId = stringParam(params, "mode_id", {}, paramError);
    if (!venueToken.has_value() || !modeId.has_value()) {
      return response(id, "error", {}, "venue_token and mode_id required");
    }
    m_felBridge.notifyVenueTravel(*venueToken, *modeId);
    return response(id, "ok", {{"venue_token", *venueToken}, {"mode_id", *modeId}});
  }

  if (command == "fel.bridge.broadcast_map_loaded") {
    const auto mapToken = stringParam(params, "map", "nexus_arena", paramError);
    const auto modeId = stringParam(params, "mode_id", "basketball_dunk", paramError);
    if (!mapToken.has_value() || !modeId.has_value()) {
      return response(id, "error", {}, paramError.empty() ? "map and mode_id required" : paramError);
    }
    const float prq = m_fitnessData.snapshot().frc.controlScore * 100.0F;
    m_felBridge.broadcastMapLoaded(*mapToken, *modeId, prq);
    return response(id, "ok", {{"queued", true}});
  }

  if (command == "fel.bridge.set_focus_keepalive") {
    const bool enabled = params.value("enabled", false);
    const float interval = params.value("interval_seconds", 0.5F);
    m_felBridge.setFocusKeepaliveEnabled(enabled, interval);
    return response(id, "ok", {{"enabled", enabled}, {"interval_seconds", interval}});
  }

  return response(id, "error", {}, "Unsupported bridge command");
}

auto GameplayApplication::applyVenueCommand(std::string_view command,
                                            const nlohmann::json& params,
                                            std::string_view id) -> ai::AgentResponse {
  std::string paramError;
  if (command == "fel.venue.register_volume") {
    const auto venueToken = stringParam(params, "venue_token", {}, paramError);
    const auto modeId = stringParam(params, "mode_id", {}, paramError);
    if (!venueToken.has_value() || !modeId.has_value()) {
      return response(id, "error", {}, "venue_token and mode_id required");
    }
    if (!params.contains("min") || !params.contains("max")) {
      return response(id, "error", {}, "min/max bounds required");
    }
    const auto min = parseVec3(params.at("min"));
    const auto max = parseVec3(params.at("max"));
    if (min.isErr() || max.isErr()) {
      return response(id, "error", {}, "min/max bounds require numeric x,y,z");
    }
    m_venueVolumes.registerVolume({
        .venueToken = *venueToken,
        .defaultModeId = *modeId,
        .minBounds = min.value(),
        .maxBounds = max.value(),
    });
    return response(id, "ok", {{"registered", true}});
  }

  if (command == "fel.venue.set_player_position") {
    const auto position = parseVec3(params);
    if (position.isErr()) {
      return response(id, "error", {}, position.error());
    }
    m_venueVolumes.setPlayerPosition(position.value());
    processVenueOverlaps();
    return response(id, "ok", {{"x", position.value().x},
                                 {"y", position.value().y},
                                 {"z", position.value().z}});
  }

  return response(id, "error", {}, "Unsupported venue command");
}

auto GameplayApplication::applyHudCommand(std::string_view command,
                                          const nlohmann::json& params,
                                          std::string_view id) -> ai::AgentResponse {
  std::string paramError;
  if (command == "fel.hud.broadcast") {
    const auto messageType = stringParam(params, "type", "hud_update", paramError);
    if (!messageType.has_value()) {
      return response(id, "error", {}, paramError);
    }
    const nlohmann::json payload =
        params.contains("payload") ? params.at("payload") : nlohmann::json::object();
    m_hudRelay.broadcastMessage(*messageType, payload);
    return response(id, "ok", {{"queued", true}});
  }

  if (command == "fel.hud.poll") {
    return response(id, "ok", m_hudRelay.pollFrame());
  }

  return response(id, "error", {}, "Unsupported HUD command");
}

auto GameplayApplication::parseMatchScoreInput(const nlohmann::json& params) const
    -> MatchScoreInput {
  MatchScoreInput input;
  if (!params.is_object()) {
    return input;
  }
  input.playerScore = params.value("player_score", 0.0F);
  input.opponentScore = params.value("opponent_score", 0.0F);
  input.playerRuns = params.value("player_runs", 0);
  input.opponentRuns = params.value("opponent_runs", 0);
  input.inning = params.value("inning", 9);
  input.playerTouchdowns = params.value("player_touchdowns", 0);
  input.opponentTouchdowns = params.value("opponent_touchdowns", 0);
  input.playerGoals = params.value("player_goals", 0);
  input.opponentGoals = params.value("opponent_goals", 0);
  input.playerStrokes = params.value("player_strokes", 0);
  input.parStrokes = params.value("par_strokes", 0);
  input.playerSets = params.value("player_sets", 0);
  input.opponentSets = params.value("opponent_sets", 0);
  input.playerPoints = params.value("player_points", 0);
  input.opponentPoints = params.value("opponent_points", 0);
  input.playerHp = params.value("player_hp", 100.0F);
  input.opponentHp = params.value("opponent_hp", 100.0F);
  input.timeExpired = params.value("time_expired", false);
  input.surfingScore = params.value("surfing_score", input.playerScore);
  input.surfingThreshold = params.value("surfing_threshold", 75.0F);
  input.judgeScore = params.value("judge_score", input.playerScore);
  input.goldThreshold = params.value("gold_threshold", 85.0F);
  input.playerCorrect = params.value("player_correct", 0);
  input.opponentCorrect = params.value("opponent_correct", 0);
  input.stagingScore = params.value("staging_score", static_cast<int32_t>(input.playerScore));
  input.stagingOpponentScore =
      params.value("staging_opponent_score", static_cast<int32_t>(input.opponentScore));
  return input;
}

auto GameplayApplication::resolveEndSessionScores(const nlohmann::json& params) const
    -> MatchScoreInput {
  if (!params.is_object()) {
    return parseMatchScoreInput(nlohmann::json::object());
  }
  if (params.value("use_live_scores", false)) {
    const_cast<GameplayApplication*>(this)->syncArenaFromModeRuntime();
    return m_modeRuntime.sessionScoreInput();
  }
  return parseMatchScoreInput(params);
}

auto GameplayApplication::buildEndSessionPayload(const SessionResult& result) const
    -> nlohmann::json {
  nlohmann::json payload = sessionResultToJson(result);
  payload["final_scores"] = m_arenaSession.finalScoresJson();
  payload["arena"] = m_arenaSession.stateJson();
  return payload;
}

auto GameplayApplication::parseVec3(const nlohmann::json& params) const -> Result<Vec3f> {
  if (!params.is_object()) {
    return Result<Vec3f>::err("position must be an object");
  }
  if (!params.contains("x") || !params.contains("y") || !params.contains("z")) {
    return Result<Vec3f>::err("position requires x, y, z");
  }
  if (!params.at("x").is_number() || !params.at("y").is_number() || !params.at("z").is_number()) {
    return Result<Vec3f>::err("position coordinates must be numeric");
  }
  return Result<Vec3f>::ok({params.at("x").get<float>(),
                            params.at("y").get<float>(),
                            params.at("z").get<float>()});
}

void GameplayApplication::syncArenaFromModeRuntime() {
  if (m_arenaSession.state().phase != ArenaSessionPhase::kActive) {
    return;
  }
  const MatchScoreInput scoreInput = m_modeRuntime.sessionScoreInput();
  m_arenaSession.syncLiveState(scoreInput.playerScore,
                               scoreInput.opponentScore,
                               m_modeRuntime.comboCount(),
                               m_modeRuntime.criticalCount(),
                               m_modeRuntime.stateJson());
}

auto GameplayApplication::sessionStateLabel(ArenaSessionPhase phase, bool paused)
    -> std::string_view {
  if (paused) {
    return "paused";
  }
  switch (phase) {
  case ArenaSessionPhase::kIdle:
    return "idle";
  case ArenaSessionPhase::kActive:
    return "active";
  case ArenaSessionPhase::kEnded:
    return "ended";
  }
  return "idle";
}

void GameplayApplication::emitHudTickFrame() {
  const auto& arena = m_arenaSession.state();
  const auto& throwCatch = m_throwCatch.state();
  const auto fitness = m_fitnessData.snapshot();
  nlohmann::json framePayload{
      {"mode_id", arena.modeId.empty() ? m_modeRuntime.activeModeId() : arena.modeId},
      {"score", arena.playerScore},
      {"opponent_score", arena.opponentScore},
      {"combo", arena.comboCount},
      {"session_state", std::string(sessionStateLabel(arena.phase, arena.paused))},
      {"fitness",
       {
           {"revision", fitness.revision},
           {"frc_composite", fitness.frcComposite},
           {"iap_composite", fitness.iapComposite},
           {"power_readiness", fitness.powerReadiness},
           {"breath_phase", fitness.iap.breathPhase},
       }},
      {"throw_catch", ThrowCatchPhysicsController::stateToJson(throwCatch)},
      {"arena_phase", static_cast<int>(arena.phase)},
      {"elapsed_seconds", arena.elapsedSeconds},
      {"mode_state", m_modeRuntime.stateJson()},
  };
  m_hudRelay.emitTickFrame(std::move(framePayload));
}

void GameplayApplication::processVenueOverlaps() {
  if (const auto travel = m_venueVolumes.checkPlayerOverlap(m_venueVolumes.playerPosition())) {
    m_felBridge.notifyVenueTravel(travel->venueToken, travel->modeId);
    (void)m_arenaSession.setMode(travel->modeId);
  }
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

  nlohmann::json bridgeMessages = nlohmann::json::array();
  for (const nlohmann::json& message : m_felBridge.outboundMessages()) {
    bridgeMessages.push_back(message);
  }

  return {
      {"fitness",
       {
           {"revision", fitness.revision},
           {"frc_composite", fitness.frcComposite},
           {"iap_composite", fitness.iapComposite},
           {"power_readiness", fitness.powerReadiness},
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
      {"throw_catch", ThrowCatchPhysicsController::stateToJson(throwCatch)},
      {"arena", m_arenaSession.stateJson()},
      {"receipt_queue",
       {
           {"pending", m_gameplayManager.pendingReceipts().size()},
       }},
      {"mode_runtime", m_modeRuntime.stateJson()},
      {"fel_bridge",
       {
           {"active_venue_token", std::string(m_felBridge.activeVenueToken())},
           {"active_mode_id", std::string(m_felBridge.activeArenaGameModeId())},
           {"outbound_count", m_felBridge.outboundMessages().size()},
           {"recent_outbound", std::move(bridgeMessages)},
       }},
      {"exercise_demo",
       ExerciseDemoPipeline::mappingJson(m_arenaSession.state().modeId.empty()
                                             ? "basketball_dunk"
                                             : m_arenaSession.state().modeId)},
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
