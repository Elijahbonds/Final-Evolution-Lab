#include "nexus/ai/agent_server.h"
#include "nexus/ai/command_router.h"
#include "nexus/creative/voxel_world.h"
#include "nexus/creative/world_manipulator.h"

#include <cstdio>
#include <cstdlib>
#include <string>

namespace {

void require(bool condition, const char* message) {
  if (!condition) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    std::exit(1);
  }
}

} // namespace

auto main() -> int {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::ai::CommandRouter router;
  nexus::ai::AgentServer server;

  require(router.init(&manipulator, &world).isOk(), "router init");
  require(server.init(&router).isOk(), "server init");

  const std::string command = R"json({
    "type": "command",
    "id": "cmd_001",
    "payload": {
      "command": "terrain.set_voxels",
      "params": {
        "voxels": [
          {"position": [1, 2, 3], "voxel": {"material": 7, "solid": true}}
        ]
      }
    }
  })json";

  require(server.receiveJson(command).isOk(), "receive json");
  auto responses = server.processQueuedCommands(8);
  require(responses.size() == 1, "one response");
  require(responses[0].status == "ok", "response ok");
  require(world.voxelAt({1, 2, 3}).material == 7, "voxel material applied");
  require(world.voxelAt({1, 2, 3}).solid, "voxel solidity applied");

  const std::string query = R"json({
    "type": "query",
    "id": "query_001",
    "payload": {"query": "world.dirty_chunks"}
  })json";
  require(server.receiveJson(query).isOk(), "receive query");
  responses = server.processQueuedCommands(8);
  require(responses.size() == 1, "one query response");
  require(responses[0].status == "ok", "query response ok");
  require(!responses[0].payload["chunks"].empty(), "dirty chunks returned");

  // Response channel: a ResponseSink must be invoked exactly once per processed
  // command, and the delivered payload must serialize to JSON that carries the
  // original request id and a status field.
  int sinkInvocations = 0;
  std::string serializedResponse;
  std::string deliveredId;
  std::string deliveredStatus;
  const auto sink = [&](const nexus::ai::AgentResponse& response) {
    ++sinkInvocations;
    const nlohmann::json json = response.serialize();
    serializedResponse = json.dump();
    deliveredId = json.value("id", std::string{});
    deliveredStatus = json.value("status", std::string{});
  };

  const std::string sinkAuth = R"json({
    "type": "auth",
    "id": "auth_042",
    "payload": {"token": "abc"}
  })json";
  require(server.receiveJson(sinkAuth, sink).isOk(), "receive auth with sink");
  responses = server.processQueuedCommands(8);
  require(responses.size() == 1, "one sink response");
  require(sinkInvocations == 1, "sink invoked exactly once");
  require(deliveredId == "auth_042", "serialized response carries request id");
  require(deliveredStatus == "ok", "serialized response carries status");
  require(serializedResponse.find("\"id\":\"auth_042\"") != std::string::npos,
          "serialized json string contains request id");
  require(serializedResponse.find("\"status\":\"ok\"") != std::string::npos,
          "serialized json string contains status field");

  // The legacy no-sink overload must still queue and process without a callback.
  require(server.receiveJson(sinkAuth).isOk(), "receive auth without sink");
  responses = server.processQueuedCommands(8);
  require(responses.size() == 1, "one no-sink response");
  require(sinkInvocations == 1, "no-sink command does not invoke prior sink");
  require(responses[0].status == "ok", "no-sink response ok");

  server.shutdown();
  router.shutdown();
  return 0;
}
