#include "nexus/generative/scan_importer.h"

#include "nexus/core/log.h"
#include "nexus/generative/procedural_mesh.h"

#include <algorithm>
#include <cctype>
#include <fstream>
#include <optional>
#include <sstream>

namespace nexus::generative {

namespace {

auto extensionLower(std::string_view path) -> std::string {
  const auto dot = path.find_last_of('.');
  if (dot == std::string_view::npos) {
    return {};
  }
  std::string ext(path.substr(dot));
  std::transform(ext.begin(), ext.end(), ext.begin(), [](unsigned char c) {
    return static_cast<char>(std::tolower(c));
  });
  return ext;
}

auto readFileToString(const std::string& path) -> std::optional<std::string> {
  std::ifstream stream(path);
  if (!stream.is_open()) {
    return std::nullopt;
  }
  std::ostringstream buffer;
  buffer << stream.rdbuf();
  return buffer.str();
}

auto parseAssetKind(std::string_view value) -> assets::AssetKind {
  if (value == "character") {
    return assets::AssetKind::kCharacter;
  }
  if (value == "environment") {
    return assets::AssetKind::kEnvironment;
  }
  if (value == "marker") {
    return assets::AssetKind::kMarker;
  }
  return assets::AssetKind::kProp;
}

} // namespace

ScanImporter::ScanImporter(ScanImporterConfig config)
    : m_config(std::move(config)),
      m_manifestRegistrar(m_config.manifestPath) {}

auto ScanImporter::finalizeImport(std::string_view assetId,
                                  std::string_view displayName,
                                  std::string_view sourceKind,
                                  const nlohmann::json& meshJson,
                                  nlohmann::json metadata) -> Result<ScanImportResult> {
  const std::string meshFileName = std::string(assetId) + ".nexusmesh.json";
  const std::string outputPath = m_config.importRoot + "/" + meshFileName;

  auto writeResult = writeNexusMeshJson(meshJson, outputPath);
  if (writeResult.isErr()) {
    return Result<ScanImportResult>::err(writeResult.error());
  }

  ManifestRegistration registration{
      .assetId = std::string(assetId),
      .name = displayName.empty() ? std::string(assetId) : std::string(displayName),
      .source = assets::AssetSource::kProcedural,
      .kind = assets::AssetKind::kProp,
      .importedMesh = meshFileName,
      .generationMethod = "scan_import",
      .sourceDescriptor = std::string(sourceKind),
  };

  if (metadata.contains("kind") && metadata["kind"].is_string()) {
    registration.kind = parseAssetKind(metadata["kind"].get<std::string>());
  }
  if (metadata.contains("source") && metadata["source"].is_string()) {
    registration.source = assets::parseAssetSource(metadata["source"].get<std::string>());
  }

  auto manifestResult = m_manifestRegistrar.registerAsset(registration);
  if (manifestResult.isErr()) {
    return Result<ScanImportResult>::err(manifestResult.error());
  }

  metadata["asset_id"] = assetId;
  metadata["source_kind"] = sourceKind;

  NEXUS_LOG_INFO(LogChannel::kGenerative,
                 "Scan import complete: " + std::string(assetId) + " -> " + outputPath);

  return Result<ScanImportResult>::ok(ScanImportResult{
      .assetId = std::string(assetId),
      .nexusMeshPath = outputPath,
      .manifestPath = m_config.manifestPath,
      .sourceKind = std::string(sourceKind),
      .metadata = std::move(metadata),
  });
}

auto ScanImporter::importMeshPath(std::string_view meshPath,
                                  std::string_view assetId,
                                  std::string_view displayName) -> Result<ScanImportResult> {
  if (assetId.empty()) {
    return Result<ScanImportResult>::err("scan import requires asset_id");
  }
  if (meshPath.empty()) {
    return Result<ScanImportResult>::err("scan import requires mesh_path");
  }

  const std::string ext = extensionLower(meshPath);
  nlohmann::json metadata{
      {"input_path", std::string(meshPath)},
      {"input_extension", ext},
  };

  if (ext == ".json" || meshPath.find("nexusmesh") != std::string_view::npos) {
    const auto fileContents = readFileToString(std::string(meshPath));
    if (!fileContents.has_value()) {
      return Result<ScanImportResult>::err("Unable to open mesh file: " + std::string(meshPath));
    }

    try {
      const auto meshJson = nlohmann::json::parse(*fileContents);
      metadata["import_mode"] = "nexusmesh_copy";
      return finalizeImport(assetId, displayName, "mesh_file", meshJson, std::move(metadata));
    } catch (const std::exception& exception) {
      return Result<ScanImportResult>::err(std::string("Mesh parse error: ") + exception.what());
    }
  }

  if (ext == ".ply" || ext == ".pcd" || ext == ".las") {
    return importPointCloudStub(meshPath, assetId, displayName);
  }

  metadata["import_mode"] = "mesh_stub";
  metadata["note"] =
      "Binary mesh formats (glTF/FBX/OBJ) require offline conversion — procedural placeholder emitted";
  const auto meshJson = buildProceduralMeshJson(assetId, "scan:" + std::string(meshPath));
  return finalizeImport(assetId, displayName, "mesh_stub", meshJson, std::move(metadata));
}

auto ScanImporter::importPointCloudStub(std::string_view pointCloudPath,
                                        std::string_view assetId,
                                        std::string_view displayName) -> Result<ScanImportResult> {
  if (assetId.empty()) {
    return Result<ScanImportResult>::err("point cloud import requires asset_id");
  }
  if (pointCloudPath.empty()) {
    return Result<ScanImportResult>::err("point cloud import requires point_cloud_path");
  }

  nlohmann::json metadata{
      {"input_path", std::string(pointCloudPath)},
      {"import_mode", "point_cloud_stub"},
      {"note", "Point cloud reconstruction stub — replace with Poisson/meshing pipeline"},
  };

  const auto meshJson =
      buildProceduralMeshJson(assetId, "pointcloud:" + std::string(pointCloudPath));
  return finalizeImport(assetId, displayName, "point_cloud_stub", meshJson, std::move(metadata));
}

} // namespace nexus::generative
