#include "agent_cli_session.h"

#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <string>

namespace {

void require(bool condition, const char* message) {
  if (!condition) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    std::exit(1);
  }
}

struct TempWorkspace {
  std::filesystem::path root;
  std::string manifestPath;
  std::string importRoot;

  explicit TempWorkspace(const std::string& name) {
    root = std::filesystem::temp_directory_path() / name;
    std::filesystem::remove_all(root);
    std::filesystem::create_directories(root / "imported");
    std::filesystem::create_directories(root / "manifests");

    manifestPath = (root / "manifests" / "test_manifest.json").string();
    importRoot = (root / "imported").string();

    std::ofstream manifest(manifestPath);
    manifest << R"json({
      "schema": "nexus-asset-manifest",
      "version": "1.0",
      "import_root": ")json"
               << importRoot << R"json(",
      "source_root": "assets/nexus/source",
      "assets": [],
      "venues": [],
      "environment_scans": []
    })json";
  }

  ~TempWorkspace() {
    std::error_code ec;
    std::filesystem::remove_all(root, ec);
  }
};

void auth_round_trip(nexus::tools::AgentCliSession& session) {
  const std::string command = R"json({
    "type": "auth",
    "id": "auth_001",
    "payload": {}
  })json";

  const auto responses = session.dispatchLine(command);
  require(responses.size() == 1, "auth produces one response");
  require(responses[0].status == "ok", "auth ok");
  require(responses[0].payload["authenticated"].get<bool>(), "auth authenticated flag");
}

void creative_raise_terrain(nexus::tools::AgentCliSession& session) {
  const std::string command = R"json({
    "type": "command",
    "id": "creative_raise",
    "payload": {
      "command": "fel.creative.raise_terrain",
      "params": {
        "position": [0, 0, 0],
        "radius": 1,
        "height": 2,
        "material": 3
      }
    }
  })json";

  const auto responses = session.dispatchLine(command);
  require(responses.size() == 1, "creative command one response");
  require(responses[0].status == "ok", "creative command ok");
  require(responses[0].payload.contains("edited_voxels"), "creative payload edited_voxels");
}

void generate_parse_prompt_query(nexus::tools::AgentCliSession& session) {
  const std::string query = R"json({
    "type": "query",
    "id": "parse_prompt",
    "payload": {
      "query": "fel.generate.parse_prompt",
      "text": "Raise sand mound and add orange hoop prop"
    }
  })json";

  const auto responses = session.dispatchLine(query);
  require(responses.size() == 1, "parse prompt one response");
  require(responses[0].status == "ok", "parse prompt ok");
  require(responses[0].payload["steps"].is_array(), "parse prompt steps");
  require(!responses[0].payload["steps"].empty(), "parse prompt non-empty steps");
}

void generate_from_text_command(nexus::tools::AgentCliSession& session) {
  const std::string command = R"json({
    "type": "command",
    "id": "from_text",
    "payload": {
      "command": "fel.generate.from_text",
      "params": {
        "text": "Small sand mound with training cone prop"
      }
    }
  })json";

  const auto responses = session.dispatchLine(command);
  require(responses.size() == 1, "from_text one response");
  require(responses[0].status == "ok", "from_text ok");
  require(responses[0].payload["steps_applied"].get<std::size_t>() >= 1, "from_text applied steps");
}

void error_envelopes(nexus::tools::AgentCliSession& session) {
  const auto invalid = session.dispatchLine("{not json");
  require(invalid.size() == 1, "invalid json one envelope");
  require(invalid[0].status == "error", "invalid json error status");
  require(invalid[0].error == "Invalid JSON", "invalid json message");

  const auto unsupported = session.dispatchLine(R"json({
    "type": "command",
    "id": "bad_cmd",
    "payload": {"command": "entity.create", "params": {}}
  })json");
  require(unsupported.size() == 1, "unsupported one response");
  require(unsupported[0].status == "error", "unsupported error status");
  require(unsupported[0].error == "Unsupported command", "unsupported message");
}

void queue_budget_drains_backlog(nexus::tools::AgentCliSession& session) {
  for (int index = 0; index < 4; ++index) {
    char buffer[512];
    std::snprintf(
        buffer,
        sizeof(buffer),
        R"({"type":"auth","id":"budget_%d","payload":{}})",
        index);
    require(session.dispatchLine(buffer).size() == 1, "auth queued");
  }

  require(session.agentServer().pendingCommandCount() == 0, "dispatch drains queue immediately");
}

} // namespace

auto main() -> int {
  TempWorkspace workspace("nexus_agent_cli_test");

  nexus::tools::AgentCliSession session({
      .queueBudget = 3,
      .importRoot = workspace.importRoot,
      .manifestPath = workspace.manifestPath,
  });

  require(session.init().isOk(), "session init");

  auth_round_trip(session);
  creative_raise_terrain(session);
  generate_parse_prompt_query(session);
  generate_from_text_command(session);
  error_envelopes(session);
  queue_budget_drains_backlog(session);

  session.shutdown();
  std::fprintf(stderr, "PASS: nexus_agent_cli_test\n");
  return 0;
}
