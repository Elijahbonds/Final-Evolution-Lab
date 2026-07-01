#pragma once

#include <nlohmann/json.hpp>

#include <string>

namespace nexus::generative {

enum class JobStatus {
  kPending,
  kRunning,
  kComplete,
  kFailed,
};

[[nodiscard]] auto jobStatusToString(JobStatus status) -> std::string_view;
[[nodiscard]] auto parseJobStatus(std::string_view value) -> JobStatus;

struct GenerativeJob {
  std::string jobId;
  JobStatus status{JobStatus::kPending};
  std::string prompt;
  std::string assetId;
  std::string outputMeshPath;
  std::string manifestPath;
  std::string error;
  bool usedExternalAdapter{false};
};

struct GenerativeJobHandle {
  std::string jobId;
};

struct ScanImportResult {
  std::string assetId;
  std::string nexusMeshPath;
  std::string manifestPath;
  std::string sourceKind;
  nlohmann::json metadata;
};

struct ExternalJobHandle {
  std::string externalJobId;
};

[[nodiscard]] auto jobToJson(const GenerativeJob& job) -> nlohmann::json;
[[nodiscard]] auto scanResultToJson(const ScanImportResult& result) -> nlohmann::json;

} // namespace nexus::generative
