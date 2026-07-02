#pragma once

#include "nexus/core/result.h"
#include "nexus/generative/generative_types.h"

#include <memory>
#include <string_view>

namespace nexus::generative {

/// External text-to-3D provider adapter (Meshy, Tripo, etc.). No API keys in repo.
class IGenerativeAdapter {
public:
  virtual ~IGenerativeAdapter() = default;

  [[nodiscard]] virtual auto submitGeneration(std::string_view prompt)
      -> Result<ExternalJobHandle> = 0;
  [[nodiscard]] virtual auto pollExternalJob(std::string_view externalJobId) -> Result<JobStatus> = 0;
  [[nodiscard]] virtual auto fetchMesh(std::string_view externalJobId,
                                       std::string_view outputPath) -> Result<void> = 0;
};

/// Stub adapter — always reports unavailable; ModelGenerator falls back to procedural mesh.
class StubGenerativeAdapter final : public IGenerativeAdapter {
public:
  [[nodiscard]] auto submitGeneration(std::string_view prompt) -> Result<ExternalJobHandle> override;
  [[nodiscard]] auto pollExternalJob(std::string_view externalJobId) -> Result<JobStatus> override;
  [[nodiscard]] auto fetchMesh(std::string_view externalJobId,
                               std::string_view outputPath) -> Result<void> override;
};

[[nodiscard]] auto defaultGenerativeAdapter() -> std::shared_ptr<IGenerativeAdapter>;

} // namespace nexus::generative
