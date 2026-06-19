#include "nexus/generative/generative_pipeline.h"

#include "nexus/core/log.h"
#include "nexus/generative/environment_chunk_merger.h"
#include "nexus/generative/generative_types.h"

namespace nexus::generative {

namespace {

auto parseBoundsParam(const nlohmann::json& params, EnvironmentBounds defaultBounds) -> EnvironmentBounds {
  EnvironmentBounds bounds = defaultBounds;
  if (!params.contains("bounds") || !params["bounds"].is_object()) {
    return bounds;
  }
  const auto& boundsJson = params["bounds"];
  if (boundsJson.contains("min") && boundsJson["min"].is_array() && boundsJson["min"].size() == 3) {
    bounds.min[0] = boundsJson["min"][0].get<float>();
    bounds.min[1] = boundsJson["min"][1].get<float>();
    bounds.min[2] = boundsJson["min"][2].get<float>();
  }
  if (boundsJson.contains("max") && boundsJson["max"].is_array() && boundsJson["max"].size() == 3) {
    bounds.max[0] = boundsJson["max"][0].get<float>();
    bounds.max[1] = boundsJson["max"][1].get<float>();
    bounds.max[2] = boundsJson["max"][2].get<float>();
  }
  return bounds;
}

auto parseChunkCoord(const nlohmann::json& params) -> Result<EnvironmentChunkCoord> {
  const auto coordIt = params.find("coord");
  if (coordIt == params.end() || !coordIt->is_array() || coordIt->size() != 3) {
    return Result<EnvironmentChunkCoord>::err("environment chunk requires params.coord [x,y,z]");
  }
  return Result<EnvironmentChunkCoord>::ok(EnvironmentChunkCoord{
      coordIt->at(0).get<int>(),
      coordIt->at(1).get<int>(),
      coordIt->at(2).get<int>(),
  });
}

} // namespace

GenerativePipeline::GenerativePipeline(GenerativePipelineConfig config)
    : m_scanImporter(config.scan),
      m_environmentScanImporter(config.environmentScan),
      m_modelGenerator(config.generate) {}

void GenerativePipeline::setVoxelWorld(creative::VoxelWorld* voxelWorld) {
  m_environmentScanImporter.setVoxelWorld(voxelWorld);
}

auto GenerativePipeline::handleCommand(std::string_view command,
                                       const nlohmann::json& params) -> Result<nlohmann::json> {
  if (command == "fel.generate.create_model") {
    const auto promptIt = params.find("prompt");
    const auto assetIt = params.find("asset_id");
    if (promptIt == params.end() || !promptIt->is_string()) {
      return Result<nlohmann::json>::err("fel.generate.create_model requires params.prompt");
    }
    if (assetIt == params.end() || !assetIt->is_string()) {
      return Result<nlohmann::json>::err("fel.generate.create_model requires params.asset_id");
    }

    std::string displayName;
    if (params.contains("name") && params["name"].is_string()) {
      displayName = params["name"].get<std::string>();
    }

    assets::AssetKind kind = assets::AssetKind::kProp;
    if (params.contains("kind") && params["kind"].is_string()) {
      kind = assets::parseAssetKind(params["kind"].get<std::string>());
    }

    auto enqueueResult = m_modelGenerator.enqueueGeneration(promptIt->get<std::string>(),
                                                            assetIt->get<std::string>(),
                                                            displayName,
                                                            kind);
    if (enqueueResult.isErr()) {
      return Result<nlohmann::json>::err(enqueueResult.error());
    }

    const GenerativeJob* job = m_modelGenerator.findJob(enqueueResult.value().jobId);
    if (job == nullptr) {
      return Result<nlohmann::json>::err("generative job not found after enqueue");
    }

    NEXUS_LOG_INFO(LogChannel::kGenerative,
                   "Agent command fel.generate.create_model accepted: " + job->jobId);
    return Result<nlohmann::json>::ok(jobToJson(*job));
  }

  if (command == "fel.scan.import_mesh") {
    const auto meshIt = params.find("mesh_path");
    const auto assetIt = params.find("asset_id");
    if (meshIt == params.end() || !meshIt->is_string()) {
      return Result<nlohmann::json>::err("fel.scan.import_mesh requires params.mesh_path");
    }
    if (assetIt == params.end() || !assetIt->is_string()) {
      return Result<nlohmann::json>::err("fel.scan.import_mesh requires params.asset_id");
    }

    std::string displayName;
    if (params.contains("name") && params["name"].is_string()) {
      displayName = params["name"].get<std::string>();
    }

    auto importResult = m_scanImporter.importMeshPath(meshIt->get<std::string>(),
                                                      assetIt->get<std::string>(),
                                                      displayName);
    if (importResult.isErr()) {
      return Result<nlohmann::json>::err(importResult.error());
    }

    NEXUS_LOG_INFO(LogChannel::kGenerative,
                   "Agent command fel.scan.import_mesh complete: " + importResult.value().assetId);
    return Result<nlohmann::json>::ok(scanResultToJson(importResult.value()));
  }

  if (command == "fel.scan.import_point_cloud") {
    const auto cloudIt = params.find("point_cloud_path");
    const auto assetIt = params.find("asset_id");
    if (cloudIt == params.end() || !cloudIt->is_string()) {
      return Result<nlohmann::json>::err("fel.scan.import_point_cloud requires params.point_cloud_path");
    }
    if (assetIt == params.end() || !assetIt->is_string()) {
      return Result<nlohmann::json>::err("fel.scan.import_point_cloud requires params.asset_id");
    }

    std::string displayName;
    if (params.contains("name") && params["name"].is_string()) {
      displayName = params["name"].get<std::string>();
    }

    auto importResult = m_scanImporter.importPointCloudStub(cloudIt->get<std::string>(),
                                                            assetIt->get<std::string>(),
                                                            displayName);
    if (importResult.isErr()) {
      return Result<nlohmann::json>::err(importResult.error());
    }

    return Result<nlohmann::json>::ok(scanResultToJson(importResult.value()));
  }

  if (command == "fel.scan.import_environment") {
    const auto inputIt = params.find("input_path");
    const auto venueIt = params.find("venue_id");
    const auto sourceIt = params.find("source");
    if (inputIt == params.end() || !inputIt->is_string()) {
      return Result<nlohmann::json>::err("fel.scan.import_environment requires params.input_path");
    }
    if (venueIt == params.end() || !venueIt->is_string()) {
      return Result<nlohmann::json>::err("fel.scan.import_environment requires params.venue_id");
    }
    if (sourceIt == params.end() || !sourceIt->is_string()) {
      return Result<nlohmann::json>::err("fel.scan.import_environment requires params.source");
    }

    std::string displayName;
    if (params.contains("name") && params["name"].is_string()) {
      displayName = params["name"].get<std::string>();
    }

    EnvironmentBounds bounds = parseBoundsParam(params, {});

    int chunkEdgeOverride = 0;
    if (params.contains("chunk_edge") && params["chunk_edge"].is_number_integer()) {
      chunkEdgeOverride = params["chunk_edge"].get<int>();
    }

    const EnvironmentScanSource source = parseEnvironmentScanSource(sourceIt->get<std::string>());
    auto importResult = m_environmentScanImporter.importEnvironment(inputIt->get<std::string>(),
                                                                    venueIt->get<std::string>(),
                                                                    source,
                                                                    bounds,
                                                                    displayName,
                                                                    chunkEdgeOverride);
    if (importResult.isErr()) {
      return Result<nlohmann::json>::err(importResult.error());
    }

    EnvironmentScanResult scanResult = importResult.value();
    EnvironmentChunkMerger merger;
    if (const auto mergeResult =
            merger.mergeVenueChunks(scanResult.venueId, scanResult.chunks);
        mergeResult.isOk()) {
      scanResult.metadata["merged_mesh"] = mergeResult.value().path;
    }

    return Result<nlohmann::json>::ok(environmentScanResultToJson(scanResult));
  }

  if (command == "fel.scan.import_chunk") {
    const auto venueIt = params.find("venue_id");
    if (venueIt == params.end() || !venueIt->is_string()) {
      return Result<nlohmann::json>::err("fel.scan.import_chunk requires params.venue_id");
    }

    auto coordResult = parseChunkCoord(params);
    if (coordResult.isErr()) {
      return Result<nlohmann::json>::err(coordResult.error());
    }

    std::string meshPath;
    if (params.contains("mesh_path") && params["mesh_path"].is_string()) {
      meshPath = params["mesh_path"].get<std::string>();
    }

    EnvironmentChunkFormat format = EnvironmentChunkFormat::kPhotogrammetryMesh;
    if (params.contains("source_format") && params["source_format"].is_string()) {
      format = parseEnvironmentChunkFormat(params["source_format"].get<std::string>());
    }

    auto importResult = m_environmentScanImporter.importChunk(venueIt->get<std::string>(),
                                                              coordResult.value(),
                                                              meshPath,
                                                              format);
    if (importResult.isErr()) {
      return Result<nlohmann::json>::err(importResult.error());
    }

    return Result<nlohmann::json>::ok(environmentChunkImportResultToJson(importResult.value()));
  }

  return Result<nlohmann::json>::err("Unsupported generative command");
}

auto GenerativePipeline::handleQuery(std::string_view query,
                                     const nlohmann::json& payload) -> Result<nlohmann::json> {
  if (query == "fel.generate.job_status") {
    const auto jobIt = payload.find("job_id");
    if (jobIt == payload.end() || !jobIt->is_string()) {
      return Result<nlohmann::json>::err("fel.generate.job_status requires payload.job_id");
    }

    m_modelGenerator.tickJobs();

    const GenerativeJob* job = m_modelGenerator.findJob(jobIt->get<std::string>());
    if (job == nullptr) {
      return Result<nlohmann::json>::err("generative job not found");
    }
    return Result<nlohmann::json>::ok(jobToJson(*job));
  }

  if (query == "fel.generate.list_jobs") {
    m_modelGenerator.tickJobs();
    nlohmann::json jobsJson = nlohmann::json::array();
    for (const GenerativeJob& job : m_modelGenerator.jobs()) {
      jobsJson.push_back(jobToJson(job));
    }
    return Result<nlohmann::json>::ok({{"jobs", std::move(jobsJson)}});
  }

  if (query == "fel.scan.list_environment_chunks") {
    const auto venueIt = payload.find("venue_id");
    if (venueIt == payload.end() || !venueIt->is_string()) {
      return Result<nlohmann::json>::err("fel.scan.list_environment_chunks requires payload.venue_id");
    }
    return Result<nlohmann::json>::err("environment chunk listing requires manifest reader (not yet wired)");
  }

  return Result<nlohmann::json>::err("Unsupported generative query");
}

} // namespace nexus::generative
