#pragma once

#include "nexus/core/result.h"
#include "nexus/generative/generative_adapter.h"
#include "nexus/generative/generative_types.h"
#include "nexus/generative/manifest_registrar.h"

#include <memory>
#include <mutex>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

namespace nexus::generative {

struct ModelGeneratorConfig {
  std::string importRoot{"assets/nexus/imported"};
  std::string manifestPath{"assets/nexus/manifests/nexus_asset_manifest.json"};
};

class ModelGenerator {
public:
  explicit ModelGenerator(ModelGeneratorConfig config = {},
                          std::shared_ptr<IGenerativeAdapter> adapter = defaultGenerativeAdapter());

  [[nodiscard]] auto enqueueGeneration(std::string_view prompt,
                                       std::string_view assetId,
                                       std::string_view displayName = {},
                                       assets::AssetKind kind = assets::AssetKind::kProp)
      -> Result<GenerativeJobHandle>;

  /// Advances pending/running jobs (procedural fallback when adapter unavailable).
  auto tickJobs() -> void;

  [[nodiscard]] auto findJob(std::string_view jobId) const -> const GenerativeJob*;
  [[nodiscard]] auto jobs() const -> std::vector<GenerativeJob>;

private:
  [[nodiscard]] auto nextJobId() -> std::string;
  [[nodiscard]] auto completeWithProceduralMesh(GenerativeJob& job) -> Result<void>;

  ModelGeneratorConfig m_config;
  ManifestRegistrar m_manifestRegistrar;
  std::shared_ptr<IGenerativeAdapter> m_adapter;
  mutable std::mutex m_mutex;
  std::unordered_map<std::string, GenerativeJob> m_jobs;
  std::uint64_t m_jobCounter{0};
};

} // namespace nexus::generative
