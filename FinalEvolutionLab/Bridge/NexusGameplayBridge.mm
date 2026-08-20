#import "NexusGameplayBridge.h"

#include "nexus/creative/voxel_world.h"
#include "nexus/creative/world_manipulator.h"
#include "nexus/gameplay/gameplay_application.h"
#include "nexus/generative/generative_pipeline.h"
#include "nexus/physics/physics_world.h"
#include "nexus/core/perf_monitor.h"

#include <nlohmann/json.hpp>

#include <algorithm>
#include <cctype>
#include <cstdlib>
#include <memory>
#include <string>

/*
 iOS SessionService integration (Phase D / Agent 3 coordination)
 -------------------------------------------------------------
 GamePlayView / NexusGameplayEngine lifecycle should mirror:

   1. start:  fel.arena.start_session  { mode_id, user_id }
              fel.bridge.broadcast_map_loaded { map: venue_token, mode_id }

   2. tick:   nexus_gameplay_session_tick(handle, dt) each frame
              Poll HUD overlay via nexus_gameplay_session_hud_poll_json(handle)
              — response shape: { id, status, payload: { type: "fel.hud.frame", ... } }

   3. end:    nexus_gameplay_session_end_arena(handle, playerScore, opponentScore)
              — uses use_live_scores=true so mode runtime scores win over 0/0 passthrough
              — payload includes final_scores + arena.last_result for Agent 3 HUD flush

   4. flush:  nexus_gameplay_session_flush_receipts(handle)
              — persists receipts to ~/.fel/pending_receipts/*.json for offline queue
              — live-posts from C++ only when FEL/NEXUS receipt URL + auth env are present

 Swift SessionReceiptUploadService should read that directory and POST each file to
 /api/games/session when connectivity is available (Bearer Firebase JWT).
 The C++ layer otherwise stays offline-safe and only logs + writes queue files.

 Example Swift stop() sequence:
   let result = NexusGameplayBridge.endArena(session, playerScore: score, opponentScore: 0)
   _ = NexusGameplayBridge.flushReceipts(session)
   NexusGameplayBridge.destroySession(session)
*/

struct NexusGameplaySession {
  nexus::creative::VoxelWorld voxelWorld;
  nexus::creative::WorldManipulator manipulator;
  nexus::generative::GenerativePipeline generativePipeline;
  nexus::physics::PhysicsWorld physicsWorld;
  nexus::gameplay::GameplayApplication application;
  bool physicsReady{false};

  NexusGameplaySession()
      : manipulator(voxelWorld),
        application(manipulator, voxelWorld) {
    generativePipeline.setVoxelWorld(&voxelWorld);
    application.setGenerativePipeline(&generativePipeline);
    physicsReady = physicsWorld.init({}).isOk();
  }
};

namespace {

auto copyJsonString(const nlohmann::json& value) -> char* {
  const auto serialized = value.dump();
  char* copied = ::strdup(serialized.c_str());
  if (copied == nullptr) {
    return ::strdup(R"({"status":"error","error":"out of memory"})");
  }
  return copied;
}

auto agentResponseJson(const nexus::ai::AgentResponse& response) -> nlohmann::json {
  return {
      {"id", response.id},
      {"status", response.status},
      {"payload", response.payload},
      {"error", response.error},
  };
}

auto handleCommandJson(nexus::gameplay::GameplayApplication& application,
                       const nlohmann::json& request) -> nlohmann::json {
  const auto command = request.value("command", std::string{});
  const auto id = request.value("id", std::string{"ios"});
  const auto params = request.contains("params") ? request.at("params") : nlohmann::json::object();

  if (command.rfind("fel.query.", 0) == 0 || command == "fel.hud.poll" ||
      command == "fel.generate.parse_prompt" || command == "fel.generate.parse_game" ||
      command == "fel.generate.list_jobs" ||
      command == "fel.generate.job_status") {
    const auto response = application.handleGameplayQuery(command, params, id);
    return agentResponseJson(response);
  }

  const auto response = application.handleGameplayCommand(command, params, id);
  return agentResponseJson(response);
}

auto nonEmptyEnv(const char* key) -> std::string {
  if (const char* value = std::getenv(key)) {
    std::string trimmed(value);
    trimmed.erase(trimmed.begin(),
                  std::find_if(trimmed.begin(), trimmed.end(), [](unsigned char ch) {
                    return !std::isspace(ch);
                  }));
    trimmed.erase(std::find_if(trimmed.rbegin(), trimmed.rend(), [](unsigned char ch) {
                    return !std::isspace(ch);
                  }).base(),
                  trimmed.end());
    return trimmed;
  }
  return {};
}

auto configuredReceiptUrl() -> std::string {
  if (auto value = nonEmptyEnv("FEL_SESSION_RECEIPT_URL"); !value.empty()) {
    return value;
  }
  if (auto value = nonEmptyEnv("NEXUS_RECEIPT_URL"); !value.empty()) {
    return value;
  }
  return {};
}

auto configuredReceiptAuthToken() -> std::string {
  if (auto value = nonEmptyEnv("FEL_BACKEND_AUTH_TOKEN"); !value.empty()) {
    return value;
  }
  if (auto value = nonEmptyEnv("FEL_SESSION_TOKEN"); !value.empty()) {
    return value;
  }
  if (auto value = nonEmptyEnv("NEXUS_RECEIPT_AUTH_TOKEN"); !value.empty()) {
    return value;
  }
  return {};
}

} // namespace

bool nexus_gameplay_bridge_is_linked(void) {
  static const bool linked = [] {
    try {
      auto probe = std::make_unique<NexusGameplaySession>();
      return probe != nullptr && probe->physicsReady;
    } catch (...) {
      return false;
    }
  }();
  return linked;
}

NexusGameplayHandle nexus_gameplay_session_create(void) {
  try {
    return new NexusGameplaySession();
  } catch (...) {
    return nullptr;
  }
}

void nexus_gameplay_session_destroy(NexusGameplayHandle handle) {
  delete static_cast<NexusGameplaySession*>(handle);
}

bool nexus_gameplay_session_physics_ready(NexusGameplayHandle handle) {
  auto* session = static_cast<NexusGameplaySession*>(handle);
  return session != nullptr && session->physicsReady;
}

void nexus_gameplay_session_tick(NexusGameplayHandle handle, double deltaSeconds) {
  auto* session = static_cast<NexusGameplaySession*>(handle);
  if (session == nullptr || !session->physicsReady) {
    return;
  }
  
  auto& perf = nexus::core::PerfMonitor::instance();
  perf.beginFrame();
  
  session->physicsWorld.step(deltaSeconds);
  session->application.update(deltaSeconds, session->physicsWorld, {});
  
  perf.endFrame();
}

void nexus_gameplay_session_sync_readiness(NexusGameplayHandle handle, float readiness0to100) {
  auto* session = static_cast<NexusGameplaySession*>(handle);
  if (session == nullptr) {
    return;
  }

  const float normalized = std::clamp(readiness0to100 / 100.0F, 0.0F, 1.0F);
  const nlohmann::json params = {
      {"frc_mobility", normalized},
      {"frc_active_range", normalized * 0.95F},
      {"frc_control", normalized * 0.9F},
      {"iap_engagement", normalized},
      {"iap_confidence", 0.85F},
      {"breath_phase", 0},
  };

  (void)session->application.handleGameplayCommand("fel.fitness.update", params, "ios_readiness");
}

char* nexus_gameplay_session_state_json(NexusGameplayHandle handle) {
  auto* session = static_cast<NexusGameplaySession*>(handle);
  if (session == nullptr) {
    return nullptr;
  }

  const auto response = session->application.handleGameplayQuery(
      "fel.query.get_session_state", nlohmann::json::object(), "ios_session_state");
  return copyJsonString(agentResponseJson(response));
}

char* nexus_gameplay_session_hud_poll_json(NexusGameplayHandle handle) {
  auto* session = static_cast<NexusGameplaySession*>(handle);
  if (session == nullptr) {
    return nullptr;
  }

  const auto response =
      session->application.handleGameplayQuery("fel.hud.poll", nlohmann::json::object(), "ios_hud_poll");
  return copyJsonString(agentResponseJson(response));
}

char* nexus_gameplay_session_final_scores_json(NexusGameplayHandle handle) {
  auto* session = static_cast<NexusGameplaySession*>(handle);
  if (session == nullptr) {
    return nullptr;
  }

  const auto response = session->application.handleGameplayQuery(
      "fel.query.get_arena_state", nlohmann::json::object(), "ios_final_scores");
  if (response.status != "ok") {
    return copyJsonString(agentResponseJson(response));
  }

  nlohmann::json payload = response.payload;
  if (payload.contains("last_result")) {
    payload["final_scores"] = payload["last_result"];
  } else {
    payload["final_scores"] = {
        {"player_score", payload.value("player_score", 0.0F)},
        {"opponent_score", payload.value("opponent_score", 0.0F)},
        {"mode_id", payload.value("mode_id", std::string())},
        {"phase", payload.value("phase", 0)},
    };
  }

  return copyJsonString({{"id", "ios_final_scores"},
                         {"status", "ok"},
                         {"payload", std::move(payload)},
                         {"error", ""}});
}

char* nexus_gameplay_session_handle_command(NexusGameplayHandle handle, const char* commandJson) {
  auto* session = static_cast<NexusGameplaySession*>(handle);
  if (session == nullptr || commandJson == nullptr) {
    return nullptr;
  }

  try {
    const auto request = nlohmann::json::parse(commandJson);
    return copyJsonString(handleCommandJson(session->application, request));
  } catch (...) {
    return copyJsonString({{"status", "error"}, {"error", "invalid command json"}});
  }
}

char* nexus_gameplay_session_end_arena(NexusGameplayHandle handle,
                                       float playerScore,
                                       float opponentScore) {
  auto* session = static_cast<NexusGameplaySession*>(handle);
  if (session == nullptr) {
    return nullptr;
  }

  const nlohmann::json request = {
      {"command", "fel.arena.end_session"},
      {"id", "ios_end_arena"},
      {"params",
       {
           {"use_live_scores", true},
           {"player_score", playerScore},
           {"opponent_score", opponentScore},
       }},
  };
  return copyJsonString(handleCommandJson(session->application, request));
}

char* nexus_gameplay_session_flush_receipts(NexusGameplayHandle handle) {
  auto* session = static_cast<NexusGameplaySession*>(handle);
  if (session == nullptr) {
    return nullptr;
  }

  nlohmann::json params = {{"persist_to_disk", true}};
  const auto receiptUrl = configuredReceiptUrl();
  const auto authToken = configuredReceiptAuthToken();
  if (!receiptUrl.empty()) {
    params["base_url"] = receiptUrl;
  }
  if (!authToken.empty()) {
    params["auth_token"] = authToken;
  }
  if (!receiptUrl.empty() && !authToken.empty()) {
    params["http_enabled"] = true;
    params["use_stub_http"] = false;
  }

  const nlohmann::json request = {
      {"command", "fel.arena.flush_receipts"},
      {"id", "ios_flush_receipts"},
      {"params", std::move(params)},
  };
  return copyJsonString(handleCommandJson(session->application, request));
}

void nexus_gameplay_session_free_string(char* value) {
  std::free(value);
}

void nexus_perf_set_tier(int32_t tier) {
  nexus::core::PerformanceTier cppTier;
  switch (tier) {
    case 0:
      cppTier = nexus::core::PerformanceTier::kHigh;
      break;
    case 1:
      cppTier = nexus::core::PerformanceTier::kBalanced;
      break;
    case 2:
    default:
      cppTier = nexus::core::PerformanceTier::kLowPower;
      break;
  }
  nexus::core::PerfMonitor::instance().setPlatformTier(cppTier);
}

void nexus_perf_clear_platform_tier(void) {
  nexus::core::PerfMonitor::instance().clearPlatformTier();
}

int32_t nexus_perf_get_tier(void) {
  return static_cast<int32_t>(nexus::core::PerfMonitor::instance().getTier());
}

int32_t nexus_perf_get_engine_suggested_tier(void) {
  return static_cast<int32_t>(nexus::core::PerfMonitor::instance().getEngineSuggestedTier());
}

float nexus_perf_get_fps(void) {
  return nexus::core::PerfMonitor::instance().fps();
}

float nexus_perf_get_frame_time_ms(void) {
  return nexus::core::PerfMonitor::instance().frameTimeMs();
}

bool nexus_perf_is_budget_exceeded(void) {
  return nexus::core::PerfMonitor::instance().isBudgetExceeded();
}

float nexus_perf_get_physics_substep_factor(void) {
  return nexus::core::PerfMonitor::instance().getPhysicsSubstepFactor();
}

float nexus_perf_get_collision_check_factor(void) {
  return nexus::core::PerfMonitor::instance().getCollisionCheckFactor();
}
