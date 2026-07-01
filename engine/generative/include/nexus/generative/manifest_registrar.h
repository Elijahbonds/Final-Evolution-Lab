#pragma once

#include "nexus/assets/asset_manifest.h"
#include "nexus/core/result.h"
#include "nexus/generative/environment_scan_types.h"

#include <string>
#include <string_view>
#include <vector>

namespace nexus::generative {

struct ManifestRegistration {
  std::string assetId;
  std::string name;
  assets::AssetSource source{assets::AssetSource::kProcedural};
  assets::AssetKind kind{assets::AssetKind::kProp};
  std::string importedMesh;
  std::string generationMethod;
  std::string sourceDescriptor;
};

struct EnvironmentScanRegistration {
  std::string venueId;
  std::string displayName;
  EnvironmentScanSource source{EnvironmentScanSource::kPhotogrammetry};
  EnvironmentBounds bounds{};
  int chunkEdge{32};
  std::vector<EnvironmentChunkRecord> chunks;
  std::string environmentAssetId;
};

class ManifestRegistrar {
public:
  explicit ManifestRegistrar(std::string manifestPath);

  [[nodiscard]] auto manifestPath() const -> std::string_view { return m_manifestPath; }

  [[nodiscard]] auto registerAsset(const ManifestRegistration& registration) -> Result<void>;
  [[nodiscard]] auto registerEnvironmentScan(const EnvironmentScanRegistration& registration)
      -> Result<void>;
  [[nodiscard]] auto upsertEnvironmentChunk(std::string_view venueId,
                                              const EnvironmentChunkRecord& chunk) -> Result<void>;

private:
  [[nodiscard]] auto loadManifest() -> Result<nlohmann::json>;
  [[nodiscard]] auto writeManifest(const nlohmann::json& manifest) -> Result<void>;
  [[nodiscard]] static auto environmentScanEntryToJson(const EnvironmentScanRegistration& registration)
      -> nlohmann::json;
  [[nodiscard]] static auto chunkRecordToJson(const EnvironmentChunkRecord& chunk) -> nlohmann::json;

  std::string m_manifestPath;
};

} // namespace nexus::generative
