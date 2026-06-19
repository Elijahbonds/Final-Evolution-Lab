#include "nexus/generative/environment_scan_types.h"

namespace nexus::generative {

auto parseEnvironmentScanSource(std::string_view value) -> EnvironmentScanSource {
  if (value == "luma") {
    return EnvironmentScanSource::kLuma;
  }
  if (value == "arkit") {
    return EnvironmentScanSource::kArkit;
  }
  return EnvironmentScanSource::kPhotogrammetry;
}

auto environmentScanSourceToString(EnvironmentScanSource source) -> std::string_view {
  switch (source) {
  case EnvironmentScanSource::kLuma:
    return "luma";
  case EnvironmentScanSource::kArkit:
    return "arkit";
  case EnvironmentScanSource::kPhotogrammetry:
  default:
    return "photogrammetry";
  }
}

auto parseEnvironmentChunkFormat(std::string_view value) -> EnvironmentChunkFormat {
  if (value == "gaussian_splat") {
    return EnvironmentChunkFormat::kGaussianSplat;
  }
  if (value == "point_cloud") {
    return EnvironmentChunkFormat::kPointCloud;
  }
  return EnvironmentChunkFormat::kPhotogrammetryMesh;
}

auto environmentChunkFormatToString(EnvironmentChunkFormat format) -> std::string_view {
  switch (format) {
  case EnvironmentChunkFormat::kGaussianSplat:
    return "gaussian_splat";
  case EnvironmentChunkFormat::kPointCloud:
    return "point_cloud";
  case EnvironmentChunkFormat::kPhotogrammetryMesh:
  default:
    return "photogrammetry_mesh";
  }
}

auto environmentScanResultToJson(const EnvironmentScanResult& result) -> nlohmann::json {
  nlohmann::json chunksJson = nlohmann::json::array();
  for (const EnvironmentChunkRecord& chunk : result.chunks) {
    chunksJson.push_back({
        {"coord", {chunk.coord.x, chunk.coord.y, chunk.coord.z}},
        {"mesh", chunk.meshPath},
        {"source_format", std::string(environmentChunkFormatToString(chunk.format))},
    });
  }

  return {
      {"venue_id", result.venueId},
      {"environment_asset_id", result.environmentAssetId},
      {"source", std::string(environmentScanSourceToString(result.source))},
      {"chunk_edge", result.chunkEdge},
      {"bounds",
       {
           {"min", {result.bounds.min[0], result.bounds.min[1], result.bounds.min[2]}},
           {"max", {result.bounds.max[0], result.bounds.max[1], result.bounds.max[2]}},
       }},
      {"chunks", std::move(chunksJson)},
      {"manifest_path", result.manifestPath},
      {"metadata", result.metadata},
  };
}

auto environmentChunkImportResultToJson(const EnvironmentChunkImportResult& result) -> nlohmann::json {
  return {
      {"venue_id", result.venueId},
      {"chunk",
       {
           {"coord", {result.chunk.coord.x, result.chunk.coord.y, result.chunk.coord.z}},
           {"mesh", result.chunk.meshPath},
           {"source_format", std::string(environmentChunkFormatToString(result.chunk.format))},
       }},
      {"manifest_path", result.manifestPath},
      {"metadata", result.metadata},
  };
}

} // namespace nexus::generative
