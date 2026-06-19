#import "NexusGameplayBridge.h"

#include "nexus/creative/voxel_world.h"
#include "nexus/creative/world_manipulator.h"
#include "nexus/gameplay/gameplay_application.h"
#include "nexus/physics/physics_world.h"

#include <nlohmann/json.hpp>

#include <algorithm>
#include <cstdlib>
#include <memory>
#include <string>

struct NexusGameplaySession {
  nexus::creative::VoxelWorld voxelWorld;
  nexus::creative::WorldManipulator manipulator;
  nexus::physics::PhysicsWorld physicsWorld;
  nexus::gameplay::GameplayApplication application;

  NexusGameplaySession()
      : manipulator(voxelWorld),
        application(manipulator, voxelWorld) {}
};

namespace {

auto copyJsonString(const nlohmann::json& value) -> char* {
  const auto serialized = value.dump();
  return ::strdup(serialized.c_str());
}

auto agentResponseJson(const nexus::ai::AgentResponse& response) -> nlohmann::json {
  return {
      {"id", response.id},
      {"status", response.status},
      {"payload", response.payload},
      {"error", response.error},
  };
}

} // namespace

bool nexus_gameplay_bridge_is_linked(void) {
  return true;
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

void nexus_gameplay_session_tick(NexusGameplayHandle handle, double deltaSeconds) {
  auto* session = static_cast<NexusGameplaySession*>(handle);
  if (session == nullptr) {
    return;
  }
  session->application.update(deltaSeconds, session->physicsWorld, {});
  session->physicsWorld.step(deltaSeconds);
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

char* nexus_gameplay_session_handle_command(NexusGameplayHandle handle, const char* commandJson) {
  auto* session = static_cast<NexusGameplaySession*>(handle);
  if (session == nullptr || commandJson == nullptr) {
    return nullptr;
  }

  try {
    const auto request = nlohmann::json::parse(commandJson);
    const auto command = request.value("command", std::string{});
    const auto id = request.value("id", std::string{"ios"});
    const auto params = request.contains("params") ? request.at("params") : nlohmann::json::object();

    if (command.rfind("fel.query.", 0) == 0) {
      const auto response = session->application.handleGameplayQuery(command, params, id);
      return copyJsonString(agentResponseJson(response));
    }

    const auto response = session->application.handleGameplayCommand(command, params, id);
    return copyJsonString(agentResponseJson(response));
  } catch (...) {
    return copyJsonString({{"status", "error"}, {"error", "invalid command json"}});
  }
}

void nexus_gameplay_session_free_string(char* value) {
  std::free(value);
}
