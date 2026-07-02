#include "nexus/generative/generative_types.h"

#include <algorithm>

namespace nexus::generative {

auto jobStatusToString(JobStatus status) -> std::string_view {
  switch (status) {
  case JobStatus::kPending:
    return "pending";
  case JobStatus::kRunning:
    return "running";
  case JobStatus::kComplete:
    return "complete";
  case JobStatus::kFailed:
    return "failed";
  }
  return "unknown";
}

auto parseJobStatus(std::string_view value) -> JobStatus {
  if (value == "running") {
    return JobStatus::kRunning;
  }
  if (value == "complete") {
    return JobStatus::kComplete;
  }
  if (value == "failed") {
    return JobStatus::kFailed;
  }
  return JobStatus::kPending;
}

auto jobToJson(const GenerativeJob& job) -> nlohmann::json {
  return {
      {"job_id", job.jobId},
      {"status", std::string(jobStatusToString(job.status))},
      {"prompt", job.prompt},
      {"asset_id", job.assetId},
      {"output_mesh", job.outputMeshPath},
      {"manifest_path", job.manifestPath},
      {"used_external_adapter", job.usedExternalAdapter},
      {"error", job.error},
  };
}

auto scanResultToJson(const ScanImportResult& result) -> nlohmann::json {
  return {
      {"asset_id", result.assetId},
      {"nexus_mesh_path", result.nexusMeshPath},
      {"manifest_path", result.manifestPath},
      {"source_kind", result.sourceKind},
      {"metadata", result.metadata},
  };
}

} // namespace nexus::generative
