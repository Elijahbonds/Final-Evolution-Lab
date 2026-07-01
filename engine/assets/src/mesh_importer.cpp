#include "nexus/assets/mesh_importer.h"

#include "nexus/core/log.h"
#include "nexus/core/result.h"
#include "nexus/renderer/mesh_lod.h"

#include <nlohmann/json.hpp>

#include <algorithm>
#include <cctype>
#include <filesystem>
#include <fstream>
#include <optional>
#include <sstream>
#include <string>

namespace nexus::assets {

namespace {

auto readFileToString(const std::string& path) -> std::optional<std::string> {
  std::ifstream stream(path);
  if (!stream.is_open()) {
    return std::nullopt;
  }
  std::ostringstream buffer;
  buffer << stream.rdbuf();
  return buffer.str();
}

auto extensionLower(const std::string& path) -> std::string {
  std::string lower = path;
  std::transform(lower.begin(), lower.end(), lower.begin(), [](unsigned char c) {
    return static_cast<char>(std::tolower(c));
  });
  if (lower.size() >= 15 && lower.compare(lower.size() - 15, 15, ".nexusmesh.json") == 0) {
    return ".nexusmesh.json";
  }
  const auto dot = lower.find_last_of('.');
  if (dot == std::string::npos) {
    return {};
  }
  return lower.substr(dot);
}

auto vertexFromJson(const nlohmann::json& vertexJson) -> renderer::MeshVertex {
  renderer::MeshVertex vertex{};
  const auto& position = vertexJson.at("position");
  vertex.position[0] = position.at(0).get<float>();
  vertex.position[1] = position.at(1).get<float>();
  vertex.position[2] = position.at(2).get<float>();
  if (vertexJson.contains("normal")) {
    const auto& normal = vertexJson.at("normal");
    vertex.normal[0] = normal.at(0).get<float>();
    vertex.normal[1] = normal.at(1).get<float>();
    vertex.normal[2] = normal.at(2).get<float>();
  }
  if (vertexJson.contains("color")) {
    const auto& color = vertexJson.at("color");
    vertex.color[0] = color.at(0).get<float>();
    vertex.color[1] = color.at(1).get<float>();
    vertex.color[2] = color.at(2).get<float>();
  } else {
    vertex.color[0] = 0.8F;
    vertex.color[1] = 0.85F;
    vertex.color[2] = 0.9F;
  }
  if (vertexJson.contains("uv")) {
    const auto& uv = vertexJson.at("uv");
    vertex.uv[0] = uv.at(0).get<float>();
    vertex.uv[1] = uv.at(1).get<float>();
  }
  return vertex;
}

auto meshFromJson(const nlohmann::json& json) -> renderer::Mesh {
  renderer::Mesh mesh;
  bool hasNormals = false;
  bool hasUv = false;
  for (const auto& vertexJson : json.at("vertices")) {
    mesh.vertices.push_back(vertexFromJson(vertexJson));
    if (vertexJson.contains("normal")) {
      hasNormals = true;
    }
    if (vertexJson.contains("uv")) {
      hasUv = true;
    }
  }
  for (const auto& index : json.at("indices")) {
    mesh.indices.push_back(index.get<std::uint32_t>());
  }
  mesh.hasPbrChannels = hasNormals || hasUv;
  return mesh;
}

auto applyImportBudget(renderer::Mesh& mesh, const MeshImportOptions& options) -> void {
  if (!options.applyDecimation) {
    return;
  }

  const int lodIndex = renderer::selectLodIndex(options.cameraDistanceMeters, options.lodPolicy);
  const std::size_t budget =
      lodIndex >= 1 ? options.lodPolicy.lod1MaxVertices : options.lodPolicy.heroMaxVertices;
  const std::size_t before = mesh.vertexCount();
  mesh.decimateToVertexBudget(budget);
  if (mesh.vertexCount() < before) {
    NEXUS_LOG_INFO(nexus::LogChannel::kRenderer,
                   "Mesh decimated " + std::to_string(before) + " -> " +
                       std::to_string(mesh.vertexCount()) + " vertices (LOD" +
                       std::to_string(lodIndex) + ")");
  }
}

} // namespace

auto MeshImporter::importNexusMeshJson(const std::string& path, const MeshImportOptions& options)
    -> Result<renderer::Mesh> {
  const auto fileContents = readFileToString(path);
  if (!fileContents.has_value()) {
    return Result<renderer::Mesh>::err(
        formatEngineError("MeshImporter::importNexusMeshJson", "unable to open mesh file", path));
  }

  try {
    const auto json = nlohmann::json::parse(*fileContents);
    const std::string meshDirectory = std::filesystem::path(path).parent_path().string();
    const auto lodDescriptors = renderer::parseLodDescriptors(json, meshDirectory);

    const int lodIndex = renderer::selectLodIndex(options.cameraDistanceMeters, options.lodPolicy);
    if (lodIndex > 0 && lodIndex <= static_cast<int>(lodDescriptors.size())) {
      const auto& lodDescriptor = lodDescriptors[static_cast<std::size_t>(lodIndex - 1)];
      if (!lodDescriptor.meshPath.empty()) {
        const auto lodResult = importNexusMeshJson(lodDescriptor.meshPath, options);
        if (lodResult.isOk()) {
          NEXUS_LOG_INFO(nexus::LogChannel::kRenderer,
                         "Loaded LOD" + std::to_string(lodIndex) + " mesh: " + lodDescriptor.meshPath);
          return lodResult;
        }
        NEXUS_LOG_WARN(nexus::LogChannel::kRenderer,
                       "LOD mesh unavailable (" + lodResult.error() + "); using hero mesh");
      }
    }

    renderer::Mesh mesh = meshFromJson(json);
    if (mesh.vertices.empty() || mesh.indices.empty()) {
      return Result<renderer::Mesh>::err(formatEngineError("MeshImporter::importNexusMeshJson",
                                                             "mesh JSON contains no geometry",
                                                             path));
    }

    applyImportBudget(mesh, options);
    return Result<renderer::Mesh>::ok(std::move(mesh));
  } catch (const std::exception& exception) {
    return Result<renderer::Mesh>::err(formatEngineError("MeshImporter::importNexusMeshJson",
                                                           "JSON parse failed",
                                                           path,
                                                           exception.what()));
  }
}

auto MeshImporter::importGltf(const std::string& path) -> Result<renderer::Mesh> {
  (void)path;
  return Result<renderer::Mesh>::err(
      "glTF import stub — run scripts/nexus_import_assets.py --convert or export to .nexusmesh.json");
}

auto MeshImporter::importFbx(const std::string& path) -> Result<renderer::Mesh> {
  (void)path;
  return Result<renderer::Mesh>::err(
      "FBX import stub — run scripts/nexus_import_assets.py --convert (assimp/blender pipeline)");
}

auto MeshImporter::importFile(const std::string& path, const MeshImportOptions& options)
    -> Result<renderer::Mesh> {
  const std::string ext = extensionLower(path);
  if (ext == ".json" || ext == ".nexusmesh.json") {
    return importNexusMeshJson(path, options);
  }
  if (ext == ".gltf" || ext == ".glb") {
    return importGltf(path);
  }
  if (ext == ".fbx") {
    return importFbx(path);
  }
  return Result<renderer::Mesh>::err(formatEngineError("MeshImporter::importFile",
                                                       "unsupported mesh extension",
                                                       path));
}

} // namespace nexus::assets
