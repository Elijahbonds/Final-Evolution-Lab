#include "nexus/generative/environment_chunk_merger.h"

#include "nexus/core/log.h"
#include "nexus/generative/procedural_mesh.h"

#include <fstream>
#include <sstream>

namespace nexus::generative {

EnvironmentChunkMerger::EnvironmentChunkMerger(EnvironmentChunkMergerConfig config)
    : m_config(std::move(config)) {}

auto EnvironmentChunkMerger::mergedMeshPath(std::string_view venueId) const -> std::string {
  return m_config.importRoot + "/" + std::string(venueId) + "_merged.nexusmesh.json";
}

auto EnvironmentChunkMerger::mergeVenueChunks(std::string_view venueId,
                                              const std::vector<EnvironmentChunkRecord>& chunks)
    -> Result<MergedMeshResult> {
  if (venueId.empty()) {
    return Result<MergedMeshResult>::err("chunk merger requires venue_id");
  }
  if (chunks.empty()) {
    return Result<MergedMeshResult>::err("chunk merger requires at least one chunk");
  }

  const std::string outputPath = mergedMeshPath(venueId);
  nlohmann::json chunkRefs = nlohmann::json::array();
  for (const EnvironmentChunkRecord& chunk : chunks) {
    chunkRefs.push_back({
        {"coord", {chunk.coord.x, chunk.coord.y, chunk.coord.z}},
        {"mesh", chunk.meshPath},
        {"source_format", std::string(environmentChunkFormatToString(chunk.format))},
    });
  }

  std::ostringstream prompt;
  prompt << "merged:" << venueId << ":chunks:" << chunks.size();
  const auto meshJson = buildProceduralMeshJson(std::string(venueId) + "_merged", prompt.str());
  nlohmann::json mergedJson = meshJson;
  mergedJson["environment_merge"] = {
      {"venue_id", std::string(venueId)},
      {"chunk_count", chunks.size()},
      {"chunks", std::move(chunkRefs)},
      {"note", "Stub merged venue mesh — references chunked tiles for streaming"},
  };

  auto writeResult = writeNexusMeshJson(mergedJson, outputPath);
  if (writeResult.isErr()) {
    return Result<MergedMeshResult>::err(writeResult.error());
  }

  NEXUS_LOG_INFO(LogChannel::kGenerative,
                 "Environment chunk merger wrote stub merged mesh: " + outputPath);
  return Result<MergedMeshResult>::ok(MergedMeshResult{.path = outputPath});
}

} // namespace nexus::generative
