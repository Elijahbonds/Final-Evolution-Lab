#include "nexus/ai/agent_server.h"
#include "nexus/ai/command_router.h"
#include "nexus/ai/text_prompt_adapter.h"
#include "nexus/creative/voxel_world.h"
#include "nexus/creative/world_manipulator.h"
#include "nexus/generative/generative_pipeline.h"
#include "nexus/generative/generative_types.h"

#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <string>

#include <chrono>
#include <thread>
#include <unistd.h>

#include <nlohmann/json.hpp>

namespace {

void require(bool condition, const char* message) {
  if (!condition) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    std::exit(1);
  }
}


void removeTreeBestEffort(const std::filesystem::path& root) {
  for (int attempt = 0; attempt < 5; ++attempt) {
    std::error_code ec;
    std::filesystem::remove_all(root, ec);
    if (!ec || !std::filesystem::exists(root)) {
      return;
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(10 * (attempt + 1)));
  }
}

struct TempWorkspace {
  std::filesystem::path root;
  std::string manifestPath;
  std::string importRoot;

  explicit TempWorkspace(const std::string& name) {
    root = std::filesystem::temp_directory_path() / (name + "_" + std::to_string(getpid()));
    removeTreeBestEffort(root);
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

  ~TempWorkspace() { removeTreeBestEffort(root); }
};

void model_generator_completes_procedural_job() {
  TempWorkspace workspace("nexus_generative_test_jobs");
  nexus::generative::GenerativePipelineConfig config{};
  config.scan.importRoot = workspace.importRoot;
  config.scan.manifestPath = workspace.manifestPath;
  config.generate.importRoot = workspace.importRoot;
  config.generate.manifestPath = workspace.manifestPath;

  nexus::generative::GenerativePipeline pipeline(config);
  auto enqueue = pipeline.modelGenerator().enqueueGeneration(
      "orange basketball hoop prop", "test_generated_hoop", "Test Hoop");
  require(enqueue.isOk(), "enqueue generation");

  const nexus::generative::GenerativeJob* job =
      pipeline.modelGenerator().findJob(enqueue.value().jobId);
  require(job != nullptr, "job exists");
  require(job->status == nexus::generative::JobStatus::kComplete, "job completes synchronously");
  require(!job->outputMeshPath.empty(), "output mesh path set");
  require(std::filesystem::exists(job->outputMeshPath), "output mesh file exists");
}

void writeDemoMeshFixture(const std::string& path) {
  std::ofstream mesh(path);
  mesh << R"json({
    "format": "nexusmesh",
    "version": "1",
    "name": "demo_fixture",
    "vertices": [
      { "position": [0.0, 0.0, 0.6], "color": [1.0, 0.45, 0.1] },
      { "position": [-0.5, 0.0, -0.4], "color": [1.0, 0.55, 0.15] },
      { "position": [0.5, 0.0, -0.4], "color": [1.0, 0.55, 0.15] },
      { "position": [0.0, 1.0, 0.0], "color": [1.0, 0.7, 0.2] }
    ],
    "indices": [0, 1, 3, 1, 2, 3, 2, 0, 3, 0, 2, 1]
  })json";
}

void scan_importer_writes_nexusmesh_from_existing_json() {
  TempWorkspace workspace("nexus_generative_test_scan");

  const std::string sourceMesh = workspace.importRoot + "/source_demo.nexusmesh.json";
  writeDemoMeshFixture(sourceMesh);
  require(std::filesystem::exists(sourceMesh), "demo mesh fixture exists");

  nexus::generative::GenerativePipelineConfig config{};
  config.scan.importRoot = workspace.importRoot;
  config.scan.manifestPath = workspace.manifestPath;
  config.generate.importRoot = workspace.importRoot;
  config.generate.manifestPath = workspace.manifestPath;

  nexus::generative::GenerativePipeline pipeline(config);
  auto importResult = pipeline.scanImporter().importMeshPath(
      sourceMesh, "test_scanned_marker", "Scanned Marker");
  require(importResult.isOk(), "scan import ok");

  const auto& result = importResult.value();
  require(std::filesystem::exists(result.nexusMeshPath), "scanned mesh written");
  require(result.sourceKind == "mesh_file", "mesh file import mode");
}

void agent_router_handles_generate_and_scan_commands() {
  TempWorkspace workspace("nexus_generative_test_agent");

  nexus::generative::GenerativePipelineConfig config{};
  config.scan.importRoot = workspace.importRoot;
  config.scan.manifestPath = workspace.manifestPath;
  config.generate.importRoot = workspace.importRoot;
  config.generate.manifestPath = workspace.manifestPath;

  nexus::generative::GenerativePipeline pipeline(config);
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::ai::CommandRouter router;
  nexus::ai::AgentServer server;

  require(router.init(&manipulator, &world, &pipeline).isOk(), "router init");
  require(server.init(&router).isOk(), "server init");

  const std::string sourceMesh = workspace.importRoot + "/source_demo.nexusmesh.json";
  writeDemoMeshFixture(sourceMesh);

  const std::string generateCommand = R"json({
    "type": "command",
    "id": "gen_001",
    "payload": {
      "command": "fel.generate.create_model",
      "params": {
        "prompt": "stylized training cone",
        "asset_id": "agent_test_cone",
        "kind": "prop"
      }
    }
  })json";

  require(server.receiveJson(generateCommand).isOk(), "receive generate command");
  auto responses = server.processQueuedCommands(8);
  require(responses.size() == 1, "one generate response");
  require(responses[0].status == "ok", "generate response ok");
  require(responses[0].payload["status"] == "complete", "generate job complete");

  const std::string scanCommand =
      std::string(R"json({
    "type": "command",
    "id": "scan_001",
    "payload": {
      "command": "fel.scan.import_mesh",
      "params": {
        "mesh_path": ")json") +
      sourceMesh + R"json(",
        "asset_id": "agent_test_scan"
      }
    }
  })json";

  require(server.receiveJson(scanCommand).isOk(), "receive scan command");
  responses = server.processQueuedCommands(8);
  require(responses.size() == 1, "one scan response");
  require(responses[0].status == "ok", "scan response ok");
  require(responses[0].payload["asset_id"] == "agent_test_scan", "scan asset id echoed");

  const std::string jobQuery = R"json({
    "type": "query",
    "id": "query_jobs",
    "payload": {"query": "fel.generate.list_jobs"}
  })json";

  require(server.receiveJson(jobQuery).isOk(), "receive job list query");
  responses = server.processQueuedCommands(8);
  require(responses.size() == 1, "one job list response");
  require(responses[0].status == "ok", "job list ok");
  require(responses[0].payload["jobs"].is_array(), "jobs array returned");
  require(!responses[0].payload["jobs"].empty(), "jobs not empty");

  server.shutdown();
  router.shutdown();
}

void environment_scan_import_registers_manifest_and_voxel_chunks() {
  TempWorkspace workspace("nexus_generative_test_env_scan");
  std::filesystem::create_directories(workspace.root / "imported" / "environments");

  nexus::generative::GenerativePipelineConfig config{};
  config.environmentScan.importRoot = (workspace.root / "imported" / "environments").string();
  config.environmentScan.manifestPath = workspace.manifestPath;
  config.environmentScan.chunkEdge = 32;

  nexus::generative::GenerativePipeline pipeline(config);
  nexus::creative::VoxelWorld world;
  pipeline.setVoxelWorld(&world);

  auto importResult = pipeline.handleCommand(
      "fel.scan.import_environment",
      {{"input_path", "fixtures/luma_venue_stub.ply"},
       {"venue_id", "test_venice_scan"},
       {"source", "luma"},
       {"name", "Test Venice Scan"},
       {"bounds", {{"min", {-32, 0, -32}}, {"max", {32, 8, 32}}}}});
  require(importResult.isOk(), "environment scan import ok");

  const auto& payload = importResult.value();
  require(payload["venue_id"] == "test_venice_scan", "venue id echoed");
  require(payload["chunks"].is_array(), "chunk list returned");
  require(!payload["chunks"].empty(), "at least one chunk generated");
  require(world.environmentChunkCount() > 0, "voxel world registered environment chunks");

  std::ifstream manifestStream(workspace.manifestPath);
  nlohmann::json manifest;
  manifestStream >> manifest;
  require(manifest.contains("environment_scans"), "manifest has environment_scans");
  require(!manifest["environment_scans"].empty(), "environment scan entry written");

  const auto& scanEntry = manifest["environment_scans"].front();
  require(scanEntry["venue_id"] == "test_venice_scan", "manifest venue id");
  require(scanEntry["source"] == "luma", "manifest source tag");
  require(scanEntry["chunks"].is_array(), "manifest chunk list");
}

void environment_chunk_import_upserts_manifest_entry() {
  TempWorkspace workspace("nexus_generative_test_env_chunk");
  std::filesystem::create_directories(workspace.root / "imported" / "environments");

  nexus::generative::GenerativePipelineConfig config{};
  config.environmentScan.importRoot = (workspace.root / "imported" / "environments").string();
  config.environmentScan.manifestPath = workspace.manifestPath;

  nexus::generative::GenerativePipeline pipeline(config);

  auto chunkResult = pipeline.handleCommand(
      "fel.scan.import_chunk",
      {{"venue_id", "test_chunk_venue"},
       {"coord", {1, 0, -1}},
       {"source_format", "gaussian_splat"}});
  require(chunkResult.isOk(), "chunk import ok");
  require(chunkResult.value()["chunk"]["coord"][0] == 1, "chunk coord echoed");

  std::ifstream manifestStream(workspace.manifestPath);
  nlohmann::json manifest;
  manifestStream >> manifest;
  require(!manifest["environment_scans"].empty(), "chunk import created scan entry");
  require(!manifest["environment_scans"].front()["chunks"].empty(), "chunk listed in manifest");
}

void agent_router_handles_environment_scan_command() {
  TempWorkspace workspace("nexus_generative_test_env_agent");
  std::filesystem::create_directories(workspace.root / "imported" / "environments");

  nexus::generative::GenerativePipelineConfig config{};
  config.environmentScan.importRoot = (workspace.root / "imported" / "environments").string();
  config.environmentScan.manifestPath = workspace.manifestPath;

  nexus::generative::GenerativePipeline pipeline(config);
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  pipeline.setVoxelWorld(&world);
  nexus::ai::CommandRouter router;
  nexus::ai::AgentServer server;

  require(router.init(&manipulator, &world, &pipeline).isOk(), "router init");
  require(server.init(&router).isOk(), "server init");

  const std::string envCommand = R"json({
    "type": "command",
    "id": "env_001",
    "payload": {
      "command": "fel.scan.import_environment",
      "params": {
        "input_path": "fixtures/arkit_room_export.usdz",
        "venue_id": "agent_test_room",
        "source": "arkit",
        "bounds": {"min": [0, 0, 0], "max": [32, 4, 32]}
      }
    }
  })json";

  require(server.receiveJson(envCommand).isOk(), "receive environment scan command");
  auto responses = server.processQueuedCommands(8);
  require(responses.size() == 1, "one environment response");
  require(responses[0].status == "ok", "environment scan response ok");
  require(responses[0].payload["source"] == "arkit", "environment source echoed");

  server.shutdown();
  router.shutdown();
}

void text_prompt_adapter_builds_template_plan_without_llm() {
  const auto plan = nexus::ai::parseTextPrompt("Raise a large grass hill at north with a bench prop");
  require(plan.isOk(), "parse prompt ok");
  require(plan.value().intent == "mixed" || plan.value().intent == "terrain",
          "hill prompt classified");
  require(plan.value().metadata["adapter"] == "template_mvp", "template adapter tag");
  require(plan.value().metadata["import_pipeline"] == "scripts/nexus_import_assets.py",
          "import pipeline referenced");

  bool sawRaise = false;
  for (const nexus::ai::ParsedAgentStep& step : plan.value().steps) {
    if (step.command == "fel.creative.raise_terrain") {
      sawRaise = true;
      require(step.params["position"][2].get<int>() == -6, "north offset applied");
    }
  }
  require(sawRaise, "raise terrain planned");
}

} // namespace

auto main() -> int {
  model_generator_completes_procedural_job();
  scan_importer_writes_nexusmesh_from_existing_json();
  agent_router_handles_generate_and_scan_commands();
  environment_scan_import_registers_manifest_and_voxel_chunks();
  environment_chunk_import_upserts_manifest_entry();
  agent_router_handles_environment_scan_command();
  text_prompt_adapter_builds_template_plan_without_llm();
  return 0;
}
