#pragma once

#include <nlohmann/json.hpp>

#include <string>
#include <vector>

namespace nexus::generative {

enum class EnvironmentScanSource {
  kLuma,
  kArkit,
  kPhotogrammetry,
};

enum class EnvironmentChunkFormat {
  kGaussianSplat,
  kPhotogrammetryMesh,
  kPointCloud,
};

struct EnvironmentChunkCoord {
  int x{0};
  int y{0};
  int z{0};

  [[nodiscard]] auto operator==(const EnvironmentChunkCoord& other) const -> bool {
    return x == other.x && y == other.y && z == other.z;
  }
};

struct EnvironmentBounds {
  float min[3]{-16.0F, 0.0F, -16.0F};
  float max[3]{16.0F, 8.0F, 16.0F};
};

struct EnvironmentChunkRecord {
  EnvironmentChunkCoord coord;
  std::string meshPath;
  EnvironmentChunkFormat format{EnvironmentChunkFormat::kPhotogrammetryMesh};
};

struct EnvironmentScanResult {
  std::string venueId;
  std::string environmentAssetId;
  EnvironmentScanSource source{EnvironmentScanSource::kPhotogrammetry};
  EnvironmentBounds bounds{};
  int chunkEdge{32};
  std::vector<EnvironmentChunkRecord> chunks;
  std::string manifestPath;
  nlohmann::json metadata;
};

struct EnvironmentChunkImportResult {
  std::string venueId;
  EnvironmentChunkRecord chunk;
  std::string manifestPath;
  nlohmann::json metadata;
};

struct MergedMeshResult {
  std::string path;
};

struct WrittenMeshPath {
  std::string path;
};

[[nodiscard]] auto parseEnvironmentScanSource(std::string_view value) -> EnvironmentScanSource;
[[nodiscard]] auto environmentScanSourceToString(EnvironmentScanSource source) -> std::string_view;
[[nodiscard]] auto parseEnvironmentChunkFormat(std::string_view value) -> EnvironmentChunkFormat;
[[nodiscard]] auto environmentChunkFormatToString(EnvironmentChunkFormat format) -> std::string_view;
[[nodiscard]] auto environmentScanResultToJson(const EnvironmentScanResult& result) -> nlohmann::json;
[[nodiscard]] auto environmentChunkImportResultToJson(const EnvironmentChunkImportResult& result)
    -> nlohmann::json;

} // namespace nexus::generative
