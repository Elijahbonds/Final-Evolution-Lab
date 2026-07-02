#pragma once

#include "nexus/core/result.h"
#include "nexus/generative/environment_scan_types.h"
#include "nexus/generative/manifest_registrar.h"

#include <string>
#include <string_view>

namespace nexus::creative {
class VoxelWorld;
}

namespace nexus::generative {

struct EnvironmentScanImporterConfig {
  std::string importRoot{"assets/nexus/imported/environments"};
  std::string manifestPath{"assets/nexus/manifests/nexus_asset_manifest.json"};
  int chunkEdge{32};
};

class EnvironmentScanImporter {
public:
  explicit EnvironmentScanImporter(EnvironmentScanImporterConfig config = {});

  void setVoxelWorld(creative::VoxelWorld* voxelWorld);

  [[nodiscard]] auto importEnvironment(std::string_view inputPath,
                                       std::string_view venueId,
                                       EnvironmentScanSource source,
                                       const EnvironmentBounds& bounds,
                                       std::string_view displayName = {},
                                       int chunkEdgeOverride = 0) -> Result<EnvironmentScanResult>;

  [[nodiscard]] auto importChunk(std::string_view venueId,
                                 const EnvironmentChunkCoord& coord,
                                 std::string_view meshPath,
                                 EnvironmentChunkFormat format = EnvironmentChunkFormat::kPhotogrammetryMesh)
      -> Result<EnvironmentChunkImportResult>;

private:
  [[nodiscard]] auto environmentAssetId(std::string_view venueId) const -> std::string;
  [[nodiscard]] auto chunkMeshFileName(std::string_view venueId,
                                       const EnvironmentChunkCoord& coord) const -> std::string;
  [[nodiscard]] auto writeChunkMesh(std::string_view venueId,
                                    const EnvironmentChunkCoord& coord,
                                    std::string_view inputHint) -> Result<WrittenMeshPath>;
  void wireChunkToVoxelWorld(const EnvironmentChunkCoord& coord, std::string_view meshPath);

  EnvironmentScanImporterConfig m_config;
  ManifestRegistrar m_manifestRegistrar;
  creative::VoxelWorld* m_voxelWorld{nullptr};
};

} // namespace nexus::generative
