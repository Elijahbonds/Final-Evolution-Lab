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

void terrain_set_voxels_round_trip(nexus::ai::AgentServer& server,
                                   nexus::creative::VoxelWorld& world) {
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
  require(responses[0].id == "cmd_001", "response echoes id");
  require(world.voxelAt({1, 2, 3}).material == 7, "voxel material applied");
  require(world.voxelAt({1, 2, 3}).solid, "voxel solidity applied");
}

void terrain_fill_region_round_trip(nexus::ai::AgentServer& server,
                                    nexus::creative::VoxelWorld& world) {
  const std::string command = R"json({
    "type": "command",
    "id": "cmd_fill",
    "payload": {
      "command": "terrain.fill_region",
      "params": {
        "min": [0, 0, 0],
        "max": [1, 0, 1],
        "voxel": {"material": 5, "solid": true}
      }
    }
  })json";

  require(server.receiveJson(command).isOk(), "receive fill_region");
  const auto responses = server.processQueuedCommands(8);
  require(responses.size() == 1, "one fill response");
  require(responses[0].status == "ok", "fill response ok");
  require(responses[0].payload["edited_voxels"].get<std::size_t>() == 4,
          "fill_region edited four voxels");
  require(world.voxelAt({0, 0, 0}).material == 5, "fill min corner");
  require(world.voxelAt({1, 0, 1}).material == 5, "fill max corner");
}

void world_dirty_chunks_query(nexus::ai::AgentServer& server) {
  const std::string query = R"json({
    "type": "query",
    "id": "query_001",
    "payload": {"query": "world.dirty_chunks"}
  })json";
  require(server.receiveJson(query).isOk(), "receive query");
  const auto responses = server.processQueuedCommands(8);
  require(responses.size() == 1, "one query response");
  require(responses[0].status == "ok", "query response ok");
  require(!responses[0].payload["chunks"].empty(), "dirty chunks returned");
}

void queue_budget_limits_processed_commands(nexus::ai::AgentServer& server) {
  for (int index = 0; index < 5; ++index) {
    char commandBuffer[512];
    std::snprintf(
        commandBuffer,
        sizeof(commandBuffer),
        R"({"type":"command","id":"budget_%d","payload":{"command":"terrain.set_voxels","params":{"voxels":[{"position":[%d,0,0],"voxel":{"material":1,"solid":true}}]}}})",
        index,
        index);
    require(server.receiveJson(commandBuffer).isOk(), "enqueue budget command");
  }

  const auto firstBatch = server.processQueuedCommands(3);
  require(firstBatch.size() == 3, "budget drains three commands");
  require(server.pendingCommandCount() == 2, "budget leaves two pending");

  const auto secondBatch = server.processQueuedCommands(8);
  require(secondBatch.size() == 2, "budget drains remaining commands");
  require(server.pendingCommandCount() == 0, "queue empty after drain");
}

void error_envelopes_for_parse_and_routing(nexus::ai::AgentServer& server) {
  const auto invalidJson = server.receiveJson("{not json");
  require(invalidJson.isErr(), "invalid json rejected");
  require(invalidJson.error() == "Invalid JSON", "invalid json message");

  const auto missingType = server.receiveJson(R"({"payload": {}})");
  require(missingType.isErr(), "missing type rejected");

  require(server.receiveJson(R"json({
    "type": "command",
    "id": "bad_cmd",
    "payload": {"params": {}}
  })json").isOk(),
          "command without name queued");

  const auto missingCommand = server.processQueuedCommands(1);
  require(missingCommand.size() == 1, "missing command produces response");
  require(missingCommand[0].status == "error", "missing command error status");
  require(!missingCommand[0].error.empty(), "missing command error field");
  require(missingCommand[0].error.find("command") != std::string::npos,
          "missing command error mentions command");

  require(server.receiveJson(R"json({
    "type": "command",
    "id": "unsupported",
    "payload": {"command": "entity.create", "params": {}}
  })json").isOk(),
          "unsupported command queued");

  const auto unsupported = server.processQueuedCommands(1);
  require(unsupported.size() == 1, "unsupported command produces response");
  require(unsupported[0].status == "error", "unsupported command error status");
  require(unsupported[0].error == "Unsupported command", "unsupported command message");

  require(server.receiveJson(R"json({
    "type": "query",
    "id": "bad_query",
    "payload": {"query": "unknown.query"}
  })json").isOk(),
          "unsupported query queued");

  const auto badQuery = server.processQueuedCommands(1);
  require(badQuery.size() == 1, "unsupported query produces response");
  require(badQuery[0].status == "error", "unsupported query error status");
  require(badQuery[0].error == "Unsupported query", "unsupported query message");
}

void domain_error_for_oversized_fill_region(nexus::ai::AgentServer& server) {
  const std::string oversized = R"json({
    "type": "command",
    "id": "oversized_fill",
    "payload": {
      "command": "terrain.fill_region",
      "params": {
        "min": [0, 0, 0],
        "max": [32, 32, 32],
        "voxel": {"material": 1, "solid": true}
      }
    }
  })json";

  require(server.receiveJson(oversized).isOk(), "oversized fill queued");
  const auto responses = server.processQueuedCommands(1);
  require(responses.size() == 1, "oversized fill produces response");
  require(responses[0].status == "error", "oversized fill error status");
  require(responses[0].error.find("maximum edit volume") != std::string::npos,
          "oversized fill domain error");
}

} // namespace

auto main() -> int {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::ai::CommandRouter router;
  nexus::ai::AgentServer server;

  require(router.init(&manipulator, &world).isOk(), "router init");
  require(server.init(&router).isOk(), "server init");

  terrain_set_voxels_round_trip(server, world);
  terrain_fill_region_round_trip(server, world);
  world_dirty_chunks_query(server);
  queue_budget_limits_processed_commands(server);
  error_envelopes_for_parse_and_routing(server);
  domain_error_for_oversized_fill_region(server);

  server.shutdown();
  router.shutdown();
  std::fprintf(stderr, "PASS: nexus_protocol_test\n");
  return 0;
}
