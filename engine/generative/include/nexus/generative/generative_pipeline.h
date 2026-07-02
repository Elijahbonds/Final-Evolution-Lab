#pragma once

#include "nexus/core/result.h"
#include "nexus/generative/model_generator.h"
#include "nexus/generative/environment_scan_importer.h"
#include "nexus/generative/scan_importer.h"

#include <nlohmann/json.hpp>

#include <string_view>

namespace nexus::creative {
class VoxelWorld;
}

namespace nexus::generative {

struct GenerativePipelineConfig {
  ScanImporterConfig scan;
  ModelGeneratorConfig generate;
  EnvironmentScanImporterConfig environmentScan;
};

class GenerativePipeline {
public:
  explicit GenerativePipeline(GenerativePipelineConfig config = {});

  [[nodiscard]] auto handleCommand(std::string_view command,
                                     const nlohmann::json& params) -> Result<nlohmann::json>;

  [[nodiscard]] auto handleQuery(std::string_view query,
                                 const nlohmann::json& payload) -> Result<nlohmann::json>;

  [[nodiscard]] auto modelGenerator() -> ModelGenerator& { return m_modelGenerator; }
  [[nodiscard]] auto scanImporter() -> ScanImporter& { return m_scanImporter; }
  [[nodiscard]] auto environmentScanImporter() -> EnvironmentScanImporter& {
    return m_environmentScanImporter;
  }

  void setVoxelWorld(creative::VoxelWorld* voxelWorld);

private:
  ScanImporter m_scanImporter;
  EnvironmentScanImporter m_environmentScanImporter;
  ModelGenerator m_modelGenerator;
};

} // namespace nexus::generative
