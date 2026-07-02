#include "nexus/generative/model_generator.h"

#include "nexus/core/log.h"
#include "nexus/generative/procedural_mesh.h"

#include <sstream>

namespace nexus::generative {

ModelGenerator::ModelGenerator(ModelGeneratorConfig config,
                               std::shared_ptr<IGenerativeAdapter> adapter)
    : m_config(std::move(config)),
      m_manifestRegistrar(m_config.manifestPath),
      m_adapter(std::move(adapter)) {
  if (m_adapter == nullptr) {
    m_adapter = defaultGenerativeAdapter();
  }
}

auto ModelGenerator::nextJobId() -> std::string {
  ++m_jobCounter;
  std::ostringstream stream;
  stream << "gen_" << m_jobCounter;
  return stream.str();
}

auto ModelGenerator::enqueueGeneration(std::string_view prompt,
                                       std::string_view assetId,
                                       std::string_view displayName,
                                       assets::AssetKind kind) -> Result<GenerativeJobHandle> {
  if (prompt.empty()) {
    return Result<GenerativeJobHandle>::err("model generation requires prompt");
  }
  if (assetId.empty()) {
    return Result<GenerativeJobHandle>::err("model generation requires asset_id");
  }

  const std::string jobId = nextJobId();
  GenerativeJob job{
      .jobId = jobId,
      .status = JobStatus::kPending,
      .prompt = std::string(prompt),
      .assetId = std::string(assetId),
      .manifestPath = m_config.manifestPath,
  };

  {
    std::scoped_lock lock(m_mutex);
    m_jobs.emplace(jobId, std::move(job));
  }

  NEXUS_LOG_INFO(LogChannel::kGenerative,
                 "Enqueued generative job " + jobId + " for asset " + std::string(assetId));

  tickJobs();

  (void)displayName;
  (void)kind;
  return Result<GenerativeJobHandle>::ok(GenerativeJobHandle{.jobId = jobId});
}

auto ModelGenerator::completeWithProceduralMesh(GenerativeJob& job) -> Result<void> {
  const std::string meshFileName = job.assetId + ".nexusmesh.json";
  const std::string outputPath = m_config.importRoot + "/" + meshFileName;
  const auto meshJson = buildProceduralMeshJson(job.assetId, job.prompt);

  auto writeResult = writeNexusMeshJson(meshJson, outputPath);
  if (writeResult.isErr()) {
    job.status = JobStatus::kFailed;
    job.error = writeResult.error();
    return writeResult;
  }

  ManifestRegistration registration{
      .assetId = job.assetId,
      .name = job.assetId,
      .source = assets::AssetSource::kProcedural,
      .kind = assets::AssetKind::kProp,
      .importedMesh = meshFileName,
      .generationMethod = "procedural_fallback",
      .sourceDescriptor = job.prompt,
  };

  auto manifestResult = m_manifestRegistrar.registerAsset(registration);
  if (manifestResult.isErr()) {
    job.status = JobStatus::kFailed;
    job.error = manifestResult.error();
    return manifestResult;
  }

  job.outputMeshPath = outputPath;
  job.status = JobStatus::kComplete;
  job.usedExternalAdapter = false;
  NEXUS_LOG_INFO(LogChannel::kGenerative,
                 "Generative job complete (procedural): " + job.jobId + " -> " + outputPath);
  return Result<void>::ok();
}

auto ModelGenerator::tickJobs() -> void {
  std::scoped_lock lock(m_mutex);

  for (auto& [jobId, job] : m_jobs) {
    (void)jobId;
    if (job.status != JobStatus::kPending && job.status != JobStatus::kRunning) {
      continue;
    }

    job.status = JobStatus::kRunning;

    const auto adapterResult = m_adapter->submitGeneration(job.prompt);
    if (adapterResult.isOk()) {
      job.usedExternalAdapter = true;
      const auto pollResult = m_adapter->pollExternalJob(adapterResult.value().externalJobId);
      if (pollResult.isOk() && pollResult.value() == JobStatus::kComplete) {
        const std::string meshFileName = job.assetId + ".nexusmesh.json";
        const std::string outputPath = m_config.importRoot + "/" + meshFileName;
        if (m_adapter->fetchMesh(adapterResult.value().externalJobId, outputPath).isOk()) {
          job.outputMeshPath = outputPath;
          job.status = JobStatus::kComplete;
          continue;
        }
      }
    }

    if (completeWithProceduralMesh(job).isErr()) {
      NEXUS_LOG_ERROR(LogChannel::kGenerative, "Generative job failed: " + job.error);
    }
  }
}

auto ModelGenerator::findJob(std::string_view jobId) const -> const GenerativeJob* {
  std::scoped_lock lock(m_mutex);
  const auto found = m_jobs.find(std::string(jobId));
  if (found == m_jobs.end()) {
    return nullptr;
  }
  return &found->second;
}

auto ModelGenerator::jobs() const -> std::vector<GenerativeJob> {
  std::scoped_lock lock(m_mutex);
  std::vector<GenerativeJob> snapshot;
  snapshot.reserve(m_jobs.size());
  for (const auto& [jobId, job] : m_jobs) {
    (void)jobId;
    snapshot.push_back(job);
  }
  return snapshot;
}

} // namespace nexus::generative
