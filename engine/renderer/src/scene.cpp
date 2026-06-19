#include "nexus/renderer/scene.h"

#include "nexus/assets/asset_manifest.h"
#include "nexus/assets/mesh_importer.h"
#include "nexus/core/log.h"

#include <cmath>
#include <cstdlib>

namespace nexus::renderer {

namespace {

constexpr int kArenaGridRadius = 2;
constexpr int kArenaFloorHalfExtent = 10;

auto arenaColumnHeight(int gridX, int gridZ) -> int {
  const int manhattan = std::abs(gridX) + std::abs(gridZ);
  return 1 + (manhattan % 3);
}

auto identityMatrix() -> std::array<float, 16> {
  return {1.0F, 0.0F, 0.0F, 0.0F, 0.0F, 1.0F, 0.0F, 0.0F, 0.0F, 0.0F, 1.0F, 0.0F, 0.0F, 0.0F, 0.0F, 1.0F};
}

} // namespace

auto RenderScene::multiplyMatrix(const std::array<float, 16>& a, const std::array<float, 16>& b)
    -> std::array<float, 16> {
  std::array<float, 16> out{};
  for (int column = 0; column < 4; ++column) {
    for (int row = 0; row < 4; ++row) {
      float sum = 0.0F;
      for (int k = 0; k < 4; ++k) {
        sum += a[k * 4 + row] * b[column * 4 + k];
      }
      out[column * 4 + row] = sum;
    }
  }
  return out;
}

auto RenderScene::modelMatrix(const Transform& transform) -> std::array<float, 16> {
  const float cosY = std::cos(transform.rotationYRadians);
  const float sinY = std::sin(transform.rotationYRadians);
  const float sx = transform.scale[0];
  const float sy = transform.scale[1];
  const float sz = transform.scale[2];

  const std::array<float, 16> rotationScale{
      cosY * sx, 0.0F, -sinY * sx, 0.0F, 0.0F, sy, 0.0F, 0.0F, sinY * sz, 0.0F, cosY * sz, 0.0F, 0.0F, 0.0F, 0.0F, 1.0F};

  std::array<float, 16> translation = identityMatrix();
  translation[12] = transform.translation[0];
  translation[13] = transform.translation[1];
  translation[14] = transform.translation[2];
  return multiplyMatrix(translation, rotationScale);
}

auto RenderScene::addMesh(Mesh mesh) -> std::size_t {
  m_meshes.push_back(std::move(mesh));
  return m_meshes.size() - 1;
}

auto RenderScene::mesh(std::size_t index) const -> const Mesh& {
  return m_meshes.at(index);
}

auto RenderScene::addRootEntity(SceneEntity entity) -> std::size_t {
  m_rootEntities.push_back(std::move(entity));
  return m_rootEntities.size() - 1;
}

void RenderScene::collectFromEntity(const SceneEntity& entity,
                                    const std::array<float, 16>& parentWorld,
                                    std::vector<DrawCommand>& out) const {
  const auto entityWorld = multiplyMatrix(parentWorld, modelMatrix(entity.transform));

  for (const MeshInstance& instance : entity.meshInstances) {
    DrawCommand command{};
    command.meshIndex = instance.meshIndex;
    command.modelMatrix =
        multiplyMatrix(entityWorld, modelMatrix(instance.localTransform));
    out.push_back(command);
  }

  for (const SceneEntity& child : entity.children) {
    collectFromEntity(child, entityWorld, out);
  }
}

auto RenderScene::collectDrawCommands() const -> std::vector<DrawCommand> {
  std::vector<DrawCommand> commands;
  commands.reserve(m_rootEntities.size() * 4);
  const auto identity = identityMatrix();
  for (const SceneEntity& entity : m_rootEntities) {
    collectFromEntity(entity, identity, commands);
  }
  return commands;
}

auto RenderScene::createProceduralArena(ProceduralFallback fallback) -> RenderScene {
  if (fallback == ProceduralFallback::kNone) {
    RenderScene scene;
    scene.camera().setOrbitTarget(0.0F, 1.5F, 0.0F);
    scene.camera().setOrbit(12.0F, 6.5F, 0.0F);
    scene.camera().setPerspective(50.0F, 16.0F / 9.0F, 0.1F, 100.0F);
    return scene;
  }

  RenderScene scene;

  const std::size_t planeMesh =
      scene.addMesh(Mesh::createPlane(static_cast<float>(kArenaFloorHalfExtent),
                                      0.0F,
                                      0.05F,
                                      0.12F,
                                      0.22F));

  SceneEntity arenaRoot;
  MeshInstance ground{};
  ground.meshIndex = planeMesh;
  arenaRoot.meshInstances.push_back(ground);

  if (fallback == ProceduralFallback::kFlatPlane) {
    scene.addRootEntity(std::move(arenaRoot));
    scene.camera().setOrbitTarget(0.0F, 1.5F, 0.0F);
    scene.camera().setOrbit(12.0F, 6.5F, 0.0F);
    scene.camera().setPerspective(50.0F, 16.0F / 9.0F, 0.1F, 100.0F);
    return scene;
  }

  const std::size_t cubeMesh =
      scene.addMesh(Mesh::createUnitCube(0.45F, 0.1F, 0.75F, 0.95F));

  SceneEntity columnsRoot;
  for (int gridX = -kArenaGridRadius; gridX <= kArenaGridRadius; ++gridX) {
    for (int gridZ = -kArenaGridRadius; gridZ <= kArenaGridRadius; ++gridZ) {
      const int height = arenaColumnHeight(gridX, gridZ);
      const float centerY = static_cast<float>(height) * 0.5F;

      SceneEntity columnEntity;
      columnEntity.transform.translation[0] = static_cast<float>(gridX);
      columnEntity.transform.translation[2] = static_cast<float>(gridZ);

      MeshInstance cubeInstance;
      cubeInstance.meshIndex = cubeMesh;
      cubeInstance.localTransform.translation[1] = centerY;
      columnEntity.meshInstances.push_back(cubeInstance);

      columnsRoot.children.push_back(std::move(columnEntity));
    }
  }

  arenaRoot.children.push_back(std::move(columnsRoot));
  scene.addRootEntity(std::move(arenaRoot));

  scene.camera().setOrbitTarget(0.0F, 1.5F, 0.0F);
  scene.camera().setOrbit(12.0F, 6.5F, 0.0F);
  scene.camera().setPerspective(50.0F, 16.0F / 9.0F, 0.1F, 100.0F);

  return scene;
}

auto RenderScene::createFromManifest(const std::string& manifestPath, std::string_view modeId)
    -> RenderScene {
  const auto manifestResult = assets::AssetManifest::loadFromFile(manifestPath);
  if (manifestResult.isErr()) {
    NEXUS_LOG_WARN(LogChannel::kRenderer,
                   "Asset manifest unavailable (" + manifestResult.error() + "); using procedural arena");
    return createDefaultArena();
  }

  const assets::AssetManifest& manifest = manifestResult.value();
  const std::string_view resolvedMode =
      modeId.empty() ? std::string_view{manifest.defaultMode()} : modeId;

  const assets::VenueRecord* venue = manifest.findVenueForMode(resolvedMode);
  if (venue == nullptr) {
    NEXUS_LOG_WARN(LogChannel::kRenderer,
                   "No venue for mode in manifest; using procedural arena");
    return createDefaultArena();
  }

  const assets::AssetRecord* environmentAsset = manifest.findAsset(venue->environmentAssetId);
  if (environmentAsset == nullptr) {
    return createDefaultArena();
  }

  ProceduralFallback fallback = ProceduralFallback::kArenaGrid;
  switch (environmentAsset->fallback) {
  case assets::ProceduralFallback::kFlatPlane:
    fallback = ProceduralFallback::kFlatPlane;
    break;
  case assets::ProceduralFallback::kNone:
    fallback = ProceduralFallback::kNone;
    break;
  default:
    fallback = ProceduralFallback::kArenaGrid;
    break;
  }

  RenderScene scene = createProceduralArena(fallback);

  if (!environmentAsset->importedMesh.empty()) {
    const std::string meshPath = manifest.resolveImportedPath(*environmentAsset);
    const auto meshResult = assets::MeshImporter::importFile(meshPath);
    if (meshResult.isOk()) {
      const std::size_t importedMeshIndex = scene.addMesh(meshResult.value());
      SceneEntity markerEntity;
      markerEntity.transform.translation[1] = 0.5F;
      MeshInstance markerInstance;
      markerInstance.meshIndex = importedMeshIndex;
      markerInstance.localTransform.scale[0] = 1.2F;
      markerInstance.localTransform.scale[1] = 1.2F;
      markerInstance.localTransform.scale[2] = 1.2F;
      markerEntity.meshInstances.push_back(markerInstance);
      scene.addRootEntity(std::move(markerEntity));
      NEXUS_LOG_INFO(LogChannel::kRenderer, "Loaded imported mesh: " + meshPath);
    } else {
      NEXUS_LOG_WARN(LogChannel::kRenderer,
                     "Imported mesh missing (" + meshResult.error() + "); procedural fallback only");
    }
  }

  return scene;
}

void RenderScene::attachEnvironmentChunks(RenderScene& scene,
                                          const nlohmann::json& environmentScanEntry) {
  if (!environmentScanEntry.contains("chunks") || !environmentScanEntry["chunks"].is_array()) {
    NEXUS_LOG_WARN(LogChannel::kRenderer, "Environment scan entry missing chunks array");
    return;
  }

  SceneEntity environmentRoot;
  environmentRoot.transform.translation[1] = 0.0F;

  for (const auto& chunkJson : environmentScanEntry["chunks"]) {
    if (!chunkJson.contains("mesh") || !chunkJson["mesh"].is_string()) {
      continue;
    }
    if (!chunkJson.contains("coord") || !chunkJson["coord"].is_array() ||
        chunkJson["coord"].size() != 3) {
      continue;
    }

    const auto meshResult = assets::MeshImporter::importFile(chunkJson["mesh"].get<std::string>());
    if (meshResult.isErr()) {
      NEXUS_LOG_WARN(LogChannel::kRenderer,
                     "Environment chunk mesh unavailable: " + meshResult.error());
      continue;
    }

    const int chunkEdge = environmentScanEntry.value("chunk_edge", 32);
    const int cx = chunkJson["coord"][0].get<int>();
    const int cy = chunkJson["coord"][1].get<int>();
    const int cz = chunkJson["coord"][2].get<int>();

    SceneEntity chunkEntity;
    chunkEntity.transform.translation[0] = static_cast<float>(cx * chunkEdge);
    chunkEntity.transform.translation[1] = static_cast<float>(cy * chunkEdge);
    chunkEntity.transform.translation[2] = static_cast<float>(cz * chunkEdge);

    MeshInstance instance;
    instance.meshIndex = scene.addMesh(meshResult.value());
    chunkEntity.meshInstances.push_back(instance);
    environmentRoot.children.push_back(std::move(chunkEntity));
  }

  if (!environmentRoot.children.empty()) {
    scene.addRootEntity(std::move(environmentRoot));
    NEXUS_LOG_INFO(LogChannel::kRenderer, "Attached environment scan chunks to render scene");
  }
}

auto RenderScene::createDefaultArena() -> RenderScene {
  return createProceduralArena(ProceduralFallback::kArenaGrid);
}

} // namespace nexus::renderer
