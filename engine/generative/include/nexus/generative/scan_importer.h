#pragma once

#include "nexus/core/result.h"
#include "nexus/generative/generative_types.h"
#include "nexus/generative/manifest_registrar.h"

#include <string>
#include <string_view>

namespace nexus::generative {

struct ScanImporterConfig {
  std::string importRoot{"assets/nexus/imported"};
  std::string manifestPath{"assets/nexus/manifests/nexus_asset_manifest.json"};
};

class ScanImporter {
public:
  explicit ScanImporter(ScanImporterConfig config = {});

  [[nodiscard]] auto importMeshPath(std::string_view meshPath,
                                    std::string_view assetId,
                                    std::string_view displayName = {}) -> Result<ScanImportResult>;

  [[nodiscard]] auto importPointCloudStub(std::string_view pointCloudPath,
                                          std::string_view assetId,
                                          std::string_view displayName = {}) -> Result<ScanImportResult>;

private:
  [[nodiscard]] auto finalizeImport(std::string_view assetId,
                                    std::string_view displayName,
                                    std::string_view sourceKind,
                                    const nlohmann::json& meshJson,
                                    nlohmann::json metadata) -> Result<ScanImportResult>;

  ScanImporterConfig m_config;
  ManifestRegistrar m_manifestRegistrar;
};

} // namespace nexus::generative
