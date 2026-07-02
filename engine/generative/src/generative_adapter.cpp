#include "nexus/generative/generative_adapter.h"

#include "nexus/core/log.h"

namespace nexus::generative {

auto StubGenerativeAdapter::submitGeneration(std::string_view prompt) -> Result<ExternalJobHandle> {
  (void)prompt;
  NEXUS_LOG_INFO(LogChannel::kGenerative,
                 "StubGenerativeAdapter: external API not configured — procedural fallback");
  return Result<ExternalJobHandle>::err("external generative adapter not configured");
}

auto StubGenerativeAdapter::pollExternalJob(std::string_view externalJobId) -> Result<JobStatus> {
  (void)externalJobId;
  return Result<JobStatus>::err("external generative adapter not configured");
}

auto StubGenerativeAdapter::fetchMesh(std::string_view externalJobId,
                                      std::string_view outputPath) -> Result<void> {
  (void)externalJobId;
  (void)outputPath;
  return Result<void>::err("external generative adapter not configured");
}

auto defaultGenerativeAdapter() -> std::shared_ptr<IGenerativeAdapter> {
  return std::make_shared<StubGenerativeAdapter>();
}

} // namespace nexus::generative
