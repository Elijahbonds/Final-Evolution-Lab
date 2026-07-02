#include "nexus/renderer/scene.h"

#include "nexus/assets/asset_manifest.h"
#include "nexus/assets/mesh_importer.h"
#include "nexus/core/log.h"
#include "nexus/renderer/frustum.h"
#include "nexus/renderer/mesh_lod.h"

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <optional>

namespace nexus::renderer {

namespace {

constexpr int kArenaGridRadius = 2;
constexpr int kArenaFloorHalfExtent = 10;

auto arenaColumnHeight(int gridX, int gridZ) -> int {
  const int manhattan = std::abs(gridX) + std::abs(gridZ);
  return 1 + (manhattan % 3);
}

auto importEnvironmentMesh(const assets::AssetManifest& manifest,
                           const assets::AssetRecord& asset) -> std::optional<Mesh> {
  if (asset.importedMesh.empty()) {
    return std::nullopt;
  }
  const float cameraDistance = 0.0F;
  const std::string meshPath = manifest.resolveMeshPathAtDistance(asset, cameraDistance);
  assets::MeshImportOptions importOptions{};
  importOptions.cameraDistanceMeters = cameraDistance;
  importOptions.applyDecimation =
      !assets::meshProfilePrefersMobile() && !assets::distanceLodEnabled();

  const auto meshResult = assets::MeshImporter::importFile(meshPath, importOptions);
  if (meshResult.isErr()) {
    NEXUS_LOG_WARN(LogChannel::kRenderer,
                   "Environment mesh unavailable (" + meshResult.error() + "): " + meshPath);
    return std::nullopt;
  }

  Mesh importedMesh = Mesh::ensureValidGeometry(meshResult.value());
  if (assets::meshProfilePrefersMobile() &&
      importedMesh.vertexCount() > MeshLodPolicy{}.heroMaxVertices) {
    importedMesh.decimateToVertexBudget(MeshLodPolicy{}.heroMaxVertices);
  }
  return importedMesh;
}

enum class ViewpointCluster { kBasketball, kDojo, kStadium, kOutdoor, kIndoor };

struct ClusterViewpointTuning {
  float fovDegrees;
  float orbitRadiusScale;
  float eyeHeightBoost;
  float backdropScale;
  float backdropZExtra;
};

auto clusterForMode(std::string_view modeId) -> ViewpointCluster {
  if (modeId == "basketball_h2h" || modeId == "basketball_dunk" || modeId == "basketball_3v3" ||
      modeId == "court_carnival" || modeId == "surfing" || modeId == "tennis") {
    return ViewpointCluster::kBasketball;
  }
  if (modeId == "karate_h2h" || modeId == "karate_endless") {
    return ViewpointCluster::kDojo;
  }
  if (modeId == "baseball" || modeId == "football" || modeId == "soccer") {
    return ViewpointCluster::kStadium;
  }
  if (modeId == "golf" || modeId == "volleyball" || modeId == "skateboarding" ||
      modeId == "snowboarding") {
    return ViewpointCluster::kOutdoor;
  }
  return ViewpointCluster::kIndoor;
}

auto tuningForCluster(ViewpointCluster cluster) -> ClusterViewpointTuning {
  switch (cluster) {
  case ViewpointCluster::kBasketball:
    return {54.0F, 1.08F, 0.55F, 2.85F, 15.0F};
  case ViewpointCluster::kDojo:
    return {52.0F, 0.98F, 0.35F, 2.45F, 13.0F};
  case ViewpointCluster::kStadium:
    return {56.0F, 1.18F, 1.1F, 3.05F, 17.0F};
  case ViewpointCluster::kOutdoor:
    return {54.0F, 1.05F, 0.5F, 2.75F, 16.0F};
  case ViewpointCluster::kIndoor:
    return {52.0F, 1.0F, 0.3F, 2.35F, 12.0F};
  }
  return {54.0F, 1.05F, 0.5F, 2.75F, 14.0F};
}

auto attachVenueBackdrop(RenderScene& scene,
                         const assets::AssetManifest& manifest,
                         const assets::VenueRecord& venue,
                         const MeshBounds& courtBounds,
                         std::size_t courtTriCount,
                         std::string_view modeId) -> void {
  if (venue.backdropAssetId.empty()) {
    return;
  }

  const assets::AssetRecord* backdropAsset = manifest.findAsset(venue.backdropAssetId);
  if (backdropAsset == nullptr) {
    NEXUS_LOG_WARN(LogChannel::kRenderer,
                   "Backdrop asset missing for venue=" + venue.venueKey + " id=" +
                       venue.backdropAssetId);
    return;
  }

  auto backdropMeshOpt = importEnvironmentMesh(manifest, *backdropAsset);
  if (!backdropMeshOpt.has_value()) {
    return;
  }

  Mesh backdropMesh = std::move(*backdropMeshOpt);
  constexpr std::size_t kTriBudget = RenderScene::DrawStats::kSceneTriangleBudget();
  constexpr std::size_t kBudgetMargin = 2'000;
  const std::size_t triBudgetRemaining =
      courtTriCount >= kTriBudget ? 0 : kTriBudget - courtTriCount - kBudgetMargin;
  if (triBudgetRemaining < 4'000) {
    NEXUS_LOG_WARN(LogChannel::kRenderer,
                   "Skipping venue backdrop — triangle budget exhausted for venue=" +
                       venue.venueKey);
    return;
  }

  const std::size_t maxBackdropVerts = std::max<std::size_t>(triBudgetRemaining / 2, 4'000);
  if (backdropMesh.vertexCount() > maxBackdropVerts) {
    backdropMesh.decimateToVertexBudget(maxBackdropVerts);
    NEXUS_LOG_INFO(LogChannel::kRenderer,
                   "Backdrop decimated for budget verts=" +
                       std::to_string(backdropMesh.vertexCount()) + " venue=" + venue.venueKey);
  }

  const std::size_t backdropMeshIndex = scene.addMesh(std::move(backdropMesh));
  const ClusterViewpointTuning tuning = tuningForCluster(clusterForMode(modeId));

  SceneEntity backdropEntity;
  backdropEntity.transform.translation[0] = courtBounds.center[0];
  backdropEntity.transform.translation[1] = courtBounds.center[1];
  backdropEntity.transform.translation[2] =
      courtBounds.center[2] - courtBounds.extent[2] * 2.2F - tuning.backdropZExtra;
  backdropEntity.transform.scale[0] = tuning.backdropScale;
  backdropEntity.transform.scale[1] = tuning.backdropScale;
  backdropEntity.transform.scale[2] = tuning.backdropScale;

  MeshInstance backdropInstance;
  backdropInstance.meshIndex = backdropMeshIndex;
  backdropEntity.meshInstances.push_back(backdropInstance);
  scene.addRootEntity(std::move(backdropEntity));

  NEXUS_LOG_INFO(LogChannel::kRenderer,
                 "Attached venue backdrop id=" + venue.backdropAssetId +
                     " for venue=" + venue.venueKey);
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

auto RenderScene::collectAllDrawCommands() const -> std::vector<DrawCommand> {
  std::vector<DrawCommand> commands;
  commands.reserve(m_rootEntities.size() * 4);
  const auto identity = identityMatrix();
  for (const SceneEntity& entity : m_rootEntities) {
    collectFromEntity(entity, identity, commands);
  }
  return commands;
}

auto RenderScene::collectDrawCommandBatch(bool frustumCull) const -> DrawCommandBatch {
  DrawCommandBatch batch{};
  batch.commands = collectAllDrawCommands();
  batch.stats.totalDraws = batch.commands.size();

  if (frustumCull && !batch.commands.empty()) {
    const Frustum frustum = Frustum::fromViewProjection(m_camera.viewProjectionMatrix());
    std::vector<DrawCommand> visible;
    visible.reserve(batch.commands.size());

    for (const DrawCommand& command : batch.commands) {
      if (command.meshIndex >= m_meshes.size()) {
        continue;
      }
      const MeshBounds localBounds = m_meshes[command.meshIndex].computeBounds();
      if (frustum.intersectsBounds(command.modelMatrix, localBounds)) {
        visible.push_back(command);
      }
    }

    batch.stats.visibleDraws = visible.size();
    batch.stats.culledDraws = batch.stats.totalDraws - batch.stats.visibleDraws;
    batch.commands = std::move(visible);
  } else {
    batch.stats.visibleDraws = batch.stats.totalDraws;
    batch.stats.culledDraws = 0;
  }

  for (const DrawCommand& command : batch.commands) {
    if (command.meshIndex < m_meshes.size()) {
      batch.stats.triangleCount += m_meshes[command.meshIndex].triangleCount();
    }
  }
  return batch;
}

auto RenderScene::collectDrawCommands(bool frustumCull) const -> std::vector<DrawCommand> {
  return collectDrawCommandBatch(frustumCull).commands;
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

auto RenderScene::frameCameraToBounds(Camera& camera, const MeshBounds& bounds, std::string_view modeId)
    -> void {
  const ClusterViewpointTuning tuning = tuningForCluster(clusterForMode(modeId));
  const float horizontalExtent =
      std::max({bounds.extent[0], bounds.extent[2], 1.0F});
  const float verticalExtent = std::max(bounds.extent[1], 0.5F);
  const float radius = std::max(horizontalExtent * 1.75F * tuning.orbitRadiusScale, 6.0F);
  const float eyeHeight =
      bounds.center[1] + verticalExtent * 0.75F + 2.0F + tuning.eyeHeightBoost;

  camera.setOrbitTarget(bounds.center[0], bounds.center[1], bounds.center[2]);
  camera.setOrbit(radius, eyeHeight, 0.0F);
  camera.setPerspective(tuning.fovDegrees, 16.0F / 9.0F, 0.1F, std::max(radius * 4.0F, 100.0F));
}

auto RenderScene::createFromVenueKey(const std::string& manifestPath, std::string_view venueKey)
    -> RenderScene {
  const auto manifestResult = assets::AssetManifest::loadFromFile(manifestPath);
  if (manifestResult.isErr()) {
    NEXUS_LOG_WARN(LogChannel::kRenderer,
                   "Asset manifest unavailable (" + manifestResult.error() + "); using procedural arena");
    return createDefaultArena();
  }

  const assets::AssetManifest& manifest = manifestResult.value();
  const assets::VenueRecord* venue = manifest.findVenueByKey(venueKey);
  if (venue == nullptr || venue->modeIds.empty()) {
    NEXUS_LOG_WARN(LogChannel::kRenderer, "No venue key in manifest; using procedural arena");
    return createDefaultArena();
  }
  return createFromManifest(manifestPath, venue->modeIds.front());
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
    NEXUS_LOG_WARN(LogChannel::kRenderer,
                   "Environment asset missing for mode=" + std::string(resolvedMode) +
                       "; using procedural fallback");
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

  if (!environmentAsset->importedMesh.empty()) {
    const float cameraDistance = 0.0F;
    const std::string meshPath =
        manifest.resolveMeshPathAtDistance(*environmentAsset, cameraDistance);
    assets::MeshImportOptions importOptions{};
    importOptions.cameraDistanceMeters = cameraDistance;
    importOptions.applyDecimation =
        !assets::meshProfilePrefersMobile() && !assets::distanceLodEnabled();

    const auto meshResult = assets::MeshImporter::importFile(meshPath, importOptions);
    if (meshResult.isOk()) {
      RenderScene scene;
      renderer::Mesh importedMesh = Mesh::ensureValidGeometry(meshResult.value());
      if (importedMesh.vertices.size() != meshResult.value().vertices.size()) {
        NEXUS_LOG_WARN(LogChannel::kRenderer,
                       "Venue mesh empty after import; substituted fallback placeholder for " +
                           meshPath);
      }
      if (assets::meshProfilePrefersMobile() &&
          importedMesh.vertexCount() > MeshLodPolicy{}.heroMaxVertices) {
        importedMesh.decimateToVertexBudget(MeshLodPolicy{}.heroMaxVertices);
        NEXUS_LOG_INFO(LogChannel::kRenderer,
                       "Runtime mobile decimation applied verts=" +
                           std::to_string(importedMesh.vertexCount()));
      }
      const MeshBounds bounds = importedMesh.computeBounds();
      const std::size_t courtTriCount = importedMesh.triangleCount();
      const std::size_t venueMeshIndex = scene.addMesh(std::move(importedMesh));

      attachVenueBackdrop(scene, manifest, *venue, bounds, courtTriCount, resolvedMode);

      SceneEntity venueEntity;
      MeshInstance venueInstance;
      venueInstance.meshIndex = venueMeshIndex;
      venueEntity.meshInstances.push_back(venueInstance);
      scene.addRootEntity(std::move(venueEntity));

      frameCameraToBounds(scene.camera(), bounds, resolvedMode);
      NEXUS_LOG_INFO(LogChannel::kRenderer,
                     std::string("Loaded venue mesh (profile=") +
                         std::string(assets::activeMeshProfileName()) + ") for mode=" +
                         std::string(resolvedMode) + ": " + meshPath);
      return scene;
    }

    NEXUS_LOG_WARN(LogChannel::kRenderer,
                   "Imported mesh unavailable (" + meshResult.error() +
                       "); using fallback placeholder for mode=" + std::string(resolvedMode));

    RenderScene scene;
    const std::size_t fallbackMeshIndex = scene.addMesh(Mesh::createFallbackPlaceholder());
    SceneEntity venueEntity;
    MeshInstance venueInstance;
    venueInstance.meshIndex = fallbackMeshIndex;
    venueEntity.meshInstances.push_back(venueInstance);
    scene.addRootEntity(std::move(venueEntity));
    scene.camera().setOrbitTarget(0.0F, 1.5F, 0.0F);
    scene.camera().setOrbit(12.0F, 6.5F, 0.0F);
    scene.camera().setPerspective(50.0F, 16.0F / 9.0F, 0.1F, 100.0F);
    return scene;
  }

  return createProceduralArena(fallback);
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
