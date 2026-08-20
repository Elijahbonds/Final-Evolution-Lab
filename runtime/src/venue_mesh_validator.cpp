#include "nexus/runtime/venue_mesh_validator.h"

#include "nexus/assets/asset_manifest.h"
#include "nexus/assets/mesh_importer.h"
#include "nexus/core/dev_stats.h"
#include "nexus/core/log.h"
#include "nexus/renderer/scene.h"

#include <iostream>
#include <string>

namespace nexus::runtime {

auto validateVenueMesh(std::string_view modeId, std::string_view venueHint) -> int {
  constexpr const char* kManifestPath = "assets/nexus/manifests/nexus_asset_manifest.json";
  const auto manifestResult = nexus::assets::AssetManifest::loadFromFile(kManifestPath);
  if (manifestResult.isErr()) {
    NEXUS_LOG_ERROR(nexus::LogChannel::kRenderer, manifestResult.error());
    return 1;
  }

  const nexus::assets::AssetManifest& manifest = manifestResult.value();
  const nexus::assets::VenueRecord* venue = manifest.findVenueForMode(modeId);
  if (venue == nullptr && !venueHint.empty()) {
    venue = manifest.findVenueByKey(venueHint);
  }
  if (venue == nullptr) {
    NEXUS_LOG_ERROR(nexus::LogChannel::kRenderer,
                    "No venue registered for mode: " + std::string(modeId));
    return 1;
  }

  const nexus::assets::AssetRecord* environmentAsset = manifest.findAsset(venue->environmentAssetId);
  if (environmentAsset == nullptr || environmentAsset->importedMesh.empty()) {
    NEXUS_LOG_ERROR(nexus::LogChannel::kRenderer, "Venue environment asset missing imported mesh");
    return 1;
  }

  const std::string meshPath = manifest.resolveMeshPathAtDistance(*environmentAsset, 0.0F);
  nexus::assets::MeshImportOptions importOptions{};
  importOptions.applyDecimation =
      !nexus::assets::meshProfilePrefersMobile() && !nexus::assets::distanceLodEnabled();

  const auto meshResult = nexus::assets::MeshImporter::importFile(meshPath, importOptions);
  if (meshResult.isErr()) {
    NEXUS_LOG_ERROR(nexus::LogChannel::kRenderer, meshResult.error());
    return 1;
  }

  const auto scene = nexus::renderer::RenderScene::createFromManifest(kManifestPath, modeId);
  if (scene.meshCount() == 0 || scene.rootEntityCount() == 0) {
    NEXUS_LOG_ERROR(nexus::LogChannel::kRenderer, "RenderScene failed to build venue from manifest");
    return 1;
  }

  const auto drawBatch = scene.collectDrawCommandBatch(false);
  if (!drawBatch.stats.withinBudget()) {
    NEXUS_LOG_ERROR(nexus::LogChannel::kRenderer,
                    "Scene triangle budget exceeded: tris=" +
                        std::to_string(drawBatch.stats.triangleCount) + " budget=" +
                        std::to_string(nexus::renderer::RenderScene::DrawStats::kSceneTriangleBudget()));
    return 1;
  }

  nexus::core::logFrameDevStats({
      .fps = 0.0F,
      .frameTimeMs = 0.0F,
      .visibleDraws = drawBatch.stats.visibleDraws,
      .culledDraws = drawBatch.stats.culledDraws,
      .triangleCount = drawBatch.stats.triangleCount,
      .withinDrawBudget = drawBatch.stats.withinBudget(),
  });

  const auto& mesh = meshResult.value();
  std::cerr << "[NEXUS] validate-only OK mode=" << modeId << " venue=" << venue->venueKey
            << " mesh=" << meshPath << " verts=" << mesh.vertices.size()
            << " tris=" << (mesh.indices.size() / 3)
            << " profile=" << nexus::assets::activeMeshProfileName() << "\n";
  return 0;
}

} // namespace nexus::runtime
