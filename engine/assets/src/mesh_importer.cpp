#include "nexus/assets/mesh_importer.h"

#include <nlohmann/json.hpp>

#include <algorithm>
#include <cctype>
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
  const auto dot = path.find_last_of('.');
  if (dot == std::string::npos) {
    return {};
  }
  std::string ext = path.substr(dot);
  std::transform(ext.begin(), ext.end(), ext.begin(), [](unsigned char c) {
    return static_cast<char>(std::tolower(c));
  });
  return ext;
}

auto vertexFromJson(const nlohmann::json& vertexJson) -> renderer::MeshVertex {
  renderer::MeshVertex vertex{};
  const auto& position = vertexJson.at("position");
  vertex.position[0] = position.at(0).get<float>();
  vertex.position[1] = position.at(1).get<float>();
  vertex.position[2] = position.at(2).get<float>();
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
  return vertex;
}

} // namespace

auto MeshImporter::importNexusMeshJson(const std::string& path) -> Result<renderer::Mesh> {
  const auto fileContents = readFileToString(path);
  if (!fileContents.has_value()) {
    return Result<renderer::Mesh>::err("Unable to open mesh file: " + path);
  }

  try {
    const auto json = nlohmann::json::parse(*fileContents);
    renderer::Mesh mesh;

    for (const auto& vertexJson : json.at("vertices")) {
      mesh.vertices.push_back(vertexFromJson(vertexJson));
    }
    for (const auto& index : json.at("indices")) {
      mesh.indices.push_back(index.get<std::uint32_t>());
    }

    if (mesh.vertices.empty() || mesh.indices.empty()) {
      return Result<renderer::Mesh>::err("NEXUS mesh JSON has no geometry: " + path);
    }
    return Result<renderer::Mesh>::ok(std::move(mesh));
  } catch (const std::exception& exception) {
    return Result<renderer::Mesh>::err(std::string("NEXUS mesh parse error: ") + exception.what());
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

auto MeshImporter::importFile(const std::string& path) -> Result<renderer::Mesh> {
  const std::string ext = extensionLower(path);
  if (ext == ".json" || ext == ".nexusmesh.json") {
    return importNexusMeshJson(path);
  }
  if (ext == ".gltf" || ext == ".glb") {
    return importGltf(path);
  }
  if (ext == ".fbx") {
    return importFbx(path);
  }
  return Result<renderer::Mesh>::err("Unsupported mesh extension for: " + path);
}

} // namespace nexus::assets
