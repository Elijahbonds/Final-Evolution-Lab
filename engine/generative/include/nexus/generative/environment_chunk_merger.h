#pragma once

#include "nexus/core/result.h"
#include "nexus/generative/environment_scan_types.h"

#include <string>
#include <string_view>

namespace nexus::generative {

struct EnvironmentChunkMergerConfig {
  std::string importRoot{"assets/nexus/imported/environments"};
};

/// Combines per-chunk venue meshes into a merged manifest entry (stub merger for Luma parity).
class EnvironmentChunkMerger {
public:
  explicit EnvironmentChunkMerger(EnvironmentChunkMergerConfig config = {});

  [[nodiscard]] auto mergeVenueChunks(std::string_view venueId,
                                      const std::vector<EnvironmentChunkRecord>& chunks)
      -> Result<MergedMeshResult>;

  [[nodiscard]] auto mergedMeshPath(std::string_view venueId) const -> std::string;

private:
  EnvironmentChunkMergerConfig m_config;
};

} // namespace nexus::generative
