#include "nexus/generative/manifest_registrar.h"

#include "nexus/core/log.h"

#include <fstream>

namespace nexus::generative {

ManifestRegistrar::ManifestRegistrar(std::string manifestPath)
    : m_manifestPath(std::move(manifestPath)) {}

auto ManifestRegistrar::loadManifest() -> Result<nlohmann::json> {
  std::ifstream input(m_manifestPath);
  if (!input.is_open()) {
    return Result<nlohmann::json>::err("Unable to open manifest for registration: " + m_manifestPath);
  }

  nlohmann::json manifest;
  try {
    input >> manifest;
  } catch (const std::exception& exception) {
    return Result<nlohmann::json>::err(std::string("Manifest parse error: ") + exception.what());
  }

  if (!manifest.contains("assets") || !manifest["assets"].is_array()) {
    return Result<nlohmann::json>::err("Manifest missing assets array: " + m_manifestPath);
  }
  if (!manifest.contains("environment_scans")) {
    manifest["environment_scans"] = nlohmann::json::array();
  }
  return Result<nlohmann::json>::ok(std::move(manifest));
}

auto ManifestRegistrar::writeManifest(const nlohmann::json& manifest) -> Result<void> {
  std::ofstream output(m_manifestPath);
  if (!output.is_open()) {
    return Result<void>::err("Unable to write manifest: " + m_manifestPath);
  }
  output << manifest.dump(2);
  if (!output.good()) {
    return Result<void>::err("Failed while writing manifest: " + m_manifestPath);
  }
  return Result<void>::ok();
}

auto ManifestRegistrar::chunkRecordToJson(const EnvironmentChunkRecord& chunk) -> nlohmann::json {
  return {
      {"coord", {chunk.coord.x, chunk.coord.y, chunk.coord.z}},
      {"mesh", chunk.meshPath},
      {"source_format", std::string(environmentChunkFormatToString(chunk.format))},
  };
}

auto ManifestRegistrar::environmentScanEntryToJson(const EnvironmentScanRegistration& registration)
    -> nlohmann::json {
  nlohmann::json chunksJson = nlohmann::json::array();
  for (const EnvironmentChunkRecord& chunk : registration.chunks) {
    chunksJson.push_back(chunkRecordToJson(chunk));
  }

  return {
      {"venue_id", registration.venueId},
      {"display_name", registration.displayName},
      {"source", std::string(environmentScanSourceToString(registration.source))},
      {"environment_asset_id", registration.environmentAssetId},
      {"chunk_edge", registration.chunkEdge},
      {"bounds",
       {
           {"min",
            {registration.bounds.min[0], registration.bounds.min[1], registration.bounds.min[2]}},
           {"max",
            {registration.bounds.max[0], registration.bounds.max[1], registration.bounds.max[2]}},
       }},
      {"chunks", std::move(chunksJson)},
  };
}

auto ManifestRegistrar::registerAsset(const ManifestRegistration& registration) -> Result<void> {
  auto manifestResult = loadManifest();
  if (manifestResult.isErr()) {
    return Result<void>::err(manifestResult.error());
  }
  nlohmann::json manifest = manifestResult.value();

  for (const auto& assetJson : manifest["assets"]) {
    if (assetJson.contains("id") && assetJson["id"].get<std::string>() == registration.assetId) {
      NEXUS_LOG_INFO(LogChannel::kGenerative,
                     "Manifest asset already registered: " + registration.assetId);
      return Result<void>::ok();
    }
  }

  nlohmann::json assetEntry{
      {"id", registration.assetId},
      {"name", registration.name.empty() ? registration.assetId : registration.name},
      {"imported_mesh", registration.importedMesh},
      {"fallback", "none"},
  };

  switch (registration.source) {
  case assets::AssetSource::kMeshy:
    assetEntry["source"] = "meshy";
    break;
  case assets::AssetSource::kLuma:
    assetEntry["source"] = "luma";
    break;
  case assets::AssetSource::kUnreal:
    assetEntry["source"] = "unreal";
    break;
  case assets::AssetSource::kSeele:
    assetEntry["source"] = "seele";
    break;
  case assets::AssetSource::kProcedural:
  default:
    assetEntry["source"] = "procedural";
    break;
  }

  switch (registration.kind) {
  case assets::AssetKind::kCharacter:
    assetEntry["kind"] = "character";
    break;
  case assets::AssetKind::kProp:
    assetEntry["kind"] = "prop";
    break;
  case assets::AssetKind::kMarker:
    assetEntry["kind"] = "marker";
    break;
  case assets::AssetKind::kEnvironment:
  default:
    assetEntry["kind"] = "environment";
    break;
  }

  if (!registration.generationMethod.empty()) {
    assetEntry["generation_method"] = registration.generationMethod;
  }
  if (!registration.sourceDescriptor.empty()) {
    assetEntry["source_descriptor"] = registration.sourceDescriptor;
  }

  manifest["assets"].push_back(std::move(assetEntry));

  auto writeResult = writeManifest(manifest);
  if (writeResult.isErr()) {
    return writeResult;
  }

  NEXUS_LOG_INFO(LogChannel::kGenerative,
                 "Registered generative asset in manifest: " + registration.assetId);
  return Result<void>::ok();
}

auto ManifestRegistrar::registerEnvironmentScan(const EnvironmentScanRegistration& registration)
    -> Result<void> {
  auto manifestResult = loadManifest();
  if (manifestResult.isErr()) {
    return Result<void>::err(manifestResult.error());
  }
  nlohmann::json manifest = manifestResult.value();

  for (auto& scanJson : manifest["environment_scans"]) {
    if (scanJson.contains("venue_id") &&
        scanJson["venue_id"].get<std::string>() == registration.venueId) {
      scanJson = environmentScanEntryToJson(registration);
      auto writeResult = writeManifest(manifest);
      if (writeResult.isErr()) {
        return writeResult;
      }
      NEXUS_LOG_INFO(LogChannel::kGenerative,
                     "Updated environment scan manifest entry: " + registration.venueId);
      return Result<void>::ok();
    }
  }

  manifest["environment_scans"].push_back(environmentScanEntryToJson(registration));

  auto writeResult = writeManifest(manifest);
  if (writeResult.isErr()) {
    return writeResult;
  }

  NEXUS_LOG_INFO(LogChannel::kGenerative,
                 "Registered environment scan in manifest: " + registration.venueId);
  return Result<void>::ok();
}

auto ManifestRegistrar::upsertEnvironmentChunk(std::string_view venueId,
                                               const EnvironmentChunkRecord& chunk) -> Result<void> {
  auto manifestResult = loadManifest();
  if (manifestResult.isErr()) {
    return Result<void>::err(manifestResult.error());
  }
  nlohmann::json manifest = manifestResult.value();

  for (auto& scanJson : manifest["environment_scans"]) {
    if (!scanJson.contains("venue_id") ||
        scanJson["venue_id"].get<std::string>() != venueId) {
      continue;
    }

    if (!scanJson.contains("chunks") || !scanJson["chunks"].is_array()) {
      scanJson["chunks"] = nlohmann::json::array();
    }

    bool updated = false;
    for (auto& chunkJson : scanJson["chunks"]) {
      if (!chunkJson.contains("coord") || !chunkJson["coord"].is_array() ||
          chunkJson["coord"].size() != 3) {
        continue;
      }
      if (chunkJson["coord"][0].get<int>() == chunk.coord.x &&
          chunkJson["coord"][1].get<int>() == chunk.coord.y &&
          chunkJson["coord"][2].get<int>() == chunk.coord.z) {
        chunkJson = chunkRecordToJson(chunk);
        updated = true;
        break;
      }
    }

    if (!updated) {
      scanJson["chunks"].push_back(chunkRecordToJson(chunk));
    }

    auto writeResult = writeManifest(manifest);
    if (writeResult.isErr()) {
      return writeResult;
    }

    NEXUS_LOG_INFO(LogChannel::kGenerative,
                   "Upserted environment chunk in manifest: " + std::string(venueId));
    return Result<void>::ok();
  }

  EnvironmentScanRegistration registration{
      .venueId = std::string(venueId),
      .displayName = std::string(venueId),
      .source = EnvironmentScanSource::kPhotogrammetry,
      .chunkEdge = 32,
      .chunks = {chunk},
      .environmentAssetId = std::string(venueId) + "_environment_scan",
  };
  return registerEnvironmentScan(registration);
}

} // namespace nexus::generative
