#include "nexus/generative/environment_scan_importer.h"

#include "nexus/core/log.h"
#include "nexus/creative/voxel_world.h"
#include "nexus/generative/environment_chunk_index.h"
#include "nexus/generative/procedural_mesh.h"

#include <fstream>
#include <sstream>

namespace nexus::generative {

namespace {

auto parseBounds(const nlohmann::json& json, EnvironmentBounds defaultBounds) -> EnvironmentBounds {
  EnvironmentBounds bounds = defaultBounds;
  if (!json.contains("bounds") || !json["bounds"].is_object()) {
    return bounds;
  }
  const auto& boundsJson = json["bounds"];
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

auto assetSourceForScan(EnvironmentScanSource source) -> assets::AssetSource {
  switch (source) {
  case EnvironmentScanSource::kLuma:
    return assets::AssetSource::kLuma;
  case EnvironmentScanSource::kArkit:
  case EnvironmentScanSource::kPhotogrammetry:
  default:
    return assets::AssetSource::kProcedural;
  }
}

} // namespace

EnvironmentScanImporter::EnvironmentScanImporter(EnvironmentScanImporterConfig config)
    : m_config(std::move(config)),
      m_manifestRegistrar(m_config.manifestPath) {}

void EnvironmentScanImporter::setVoxelWorld(creative::VoxelWorld* voxelWorld) {
  m_voxelWorld = voxelWorld;
}

auto EnvironmentScanImporter::environmentAssetId(std::string_view venueId) const -> std::string {
  return std::string(venueId) + "_environment_scan";
}

auto EnvironmentScanImporter::chunkMeshFileName(std::string_view venueId,
                                              const EnvironmentChunkCoord& coord) const -> std::string {
  std::ostringstream stream;
  stream << venueId << "_chunk_" << coord.x << '_' << coord.y << '_' << coord.z << ".nexusmesh.json";
  return stream.str();
}

auto EnvironmentScanImporter::writeChunkMesh(std::string_view venueId,
                                             const EnvironmentChunkCoord& coord,
                                             std::string_view inputHint) -> Result<WrittenMeshPath> {
  const std::string fileName = chunkMeshFileName(venueId, coord);
  const std::string outputPath = m_config.importRoot + "/" + fileName;

  std::ostringstream prompt;
  prompt << "env:" << venueId << ":chunk:" << coord.x << ',' << coord.y << ',' << coord.z
         << ":from:" << inputHint;

  const auto meshJson = buildProceduralMeshJson(fileName, prompt.str());
  auto writeResult = writeNexusMeshJson(meshJson, outputPath);
  if (writeResult.isErr()) {
    return Result<WrittenMeshPath>::err(writeResult.error());
  }
  return Result<WrittenMeshPath>::ok(WrittenMeshPath{.path = outputPath});
}

void EnvironmentScanImporter::wireChunkToVoxelWorld(const EnvironmentChunkCoord& coord,
                                                    std::string_view meshPath) {
  if (m_voxelWorld == nullptr) {
    return;
  }
  m_voxelWorld->registerEnvironmentChunk({coord.x, coord.y, coord.z}, meshPath);
}

auto EnvironmentScanImporter::importEnvironment(std::string_view inputPath,
                                              std::string_view venueId,
                                              EnvironmentScanSource source,
                                              const EnvironmentBounds& bounds,
                                              std::string_view displayName,
                                              int chunkEdgeOverride) -> Result<EnvironmentScanResult> {
  if (venueId.empty()) {
    return Result<EnvironmentScanResult>::err("environment scan requires venue_id");
  }
  if (inputPath.empty()) {
    return Result<EnvironmentScanResult>::err("environment scan requires input_path");
  }

  const int chunkEdge = chunkEdgeOverride > 0 ? chunkEdgeOverride : m_config.chunkEdge;
  EnvironmentChunkIndex index(chunkEdge);
  const auto chunkCoords = index.enumerateChunksInBounds(bounds);
  if (chunkCoords.empty()) {
    return Result<EnvironmentScanResult>::err("environment bounds produced zero chunks");
  }

  std::vector<EnvironmentChunkRecord> chunks;
  chunks.reserve(chunkCoords.size());

  for (const EnvironmentChunkCoord& coord : chunkCoords) {
    auto meshResult = writeChunkMesh(venueId, coord, inputPath);
    if (meshResult.isErr()) {
      return Result<EnvironmentScanResult>::err(meshResult.error());
    }

    EnvironmentChunkRecord record{
        .coord = coord,
        .meshPath = meshResult.value().path,
        .format = EnvironmentChunkFormat::kPhotogrammetryMesh,
    };
    chunks.push_back(record);
    wireChunkToVoxelWorld(coord, record.meshPath);
  }

  const std::string assetId = environmentAssetId(venueId);
  const std::string assetName =
      displayName.empty() ? assetId : std::string(displayName);

  EnvironmentScanRegistration registration{
      .venueId = std::string(venueId),
      .displayName = assetName,
      .source = source,
      .bounds = bounds,
      .chunkEdge = chunkEdge,
      .chunks = chunks,
      .environmentAssetId = assetId,
  };

  auto manifestResult = m_manifestRegistrar.registerEnvironmentScan(registration);
  if (manifestResult.isErr()) {
    return Result<EnvironmentScanResult>::err(manifestResult.error());
  }

  ManifestRegistration assetRegistration{
      .assetId = assetId,
      .name = assetName,
      .source = assetSourceForScan(source),
      .kind = assets::AssetKind::kEnvironment,
      .importedMesh = "environments/" + chunkMeshFileName(venueId, chunks.front().coord),
      .generationMethod = "environment_scan",
      .sourceDescriptor = std::string(inputPath),
  };
  auto assetResult = m_manifestRegistrar.registerAsset(assetRegistration);
  if (assetResult.isErr()) {
    return Result<EnvironmentScanResult>::err(assetResult.error());
  }

  nlohmann::json metadata{
      {"input_path", std::string(inputPath)},
      {"import_mode", "environment_chunked"},
      {"chunk_count", chunks.size()},
      {"note", "Gaussian splat / photogrammetry mesh chunked into venue tiles"},
  };

  NEXUS_LOG_INFO(LogChannel::kGenerative,
                 "Environment scan imported: " + std::string(venueId) + " (" +
                     std::to_string(chunks.size()) + " chunks)");

  return Result<EnvironmentScanResult>::ok(EnvironmentScanResult{
      .venueId = std::string(venueId),
      .environmentAssetId = assetId,
      .source = source,
      .bounds = bounds,
      .chunkEdge = chunkEdge,
      .chunks = std::move(chunks),
      .manifestPath = m_config.manifestPath,
      .metadata = std::move(metadata),
  });
}

auto EnvironmentScanImporter::importChunk(std::string_view venueId,
                                          const EnvironmentChunkCoord& coord,
                                          std::string_view meshPath,
                                          EnvironmentChunkFormat format)
    -> Result<EnvironmentChunkImportResult> {
  if (venueId.empty()) {
    return Result<EnvironmentChunkImportResult>::err("chunk import requires venue_id");
  }

  std::string resolvedMeshPath;
  if (meshPath.empty()) {
    auto meshResult = writeChunkMesh(venueId, coord, "chunk_stub");
    if (meshResult.isErr()) {
      return Result<EnvironmentChunkImportResult>::err(meshResult.error());
    }
    resolvedMeshPath = meshResult.value().path;
  } else {
    resolvedMeshPath = std::string(meshPath);
  }

  EnvironmentChunkRecord chunk{
      .coord = coord,
      .meshPath = resolvedMeshPath,
      .format = format,
  };

  auto manifestResult = m_manifestRegistrar.upsertEnvironmentChunk(venueId, chunk);
  if (manifestResult.isErr()) {
    return Result<EnvironmentChunkImportResult>::err(manifestResult.error());
  }

  wireChunkToVoxelWorld(coord, resolvedMeshPath);

  nlohmann::json metadata{
      {"import_mode", "environment_chunk"},
      {"source_format", std::string(environmentChunkFormatToString(format))},
  };

  NEXUS_LOG_INFO(LogChannel::kGenerative,
                 "Environment chunk imported: " + std::string(venueId) + " [" +
                     std::to_string(coord.x) + ',' + std::to_string(coord.y) + ',' +
                     std::to_string(coord.z) + ']');

  return Result<EnvironmentChunkImportResult>::ok(EnvironmentChunkImportResult{
      .venueId = std::string(venueId),
      .chunk = std::move(chunk),
      .manifestPath = m_config.manifestPath,
      .metadata = std::move(metadata),
  });
}

} // namespace nexus::generative
