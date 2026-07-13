#pragma once

// CELL Spatial Sampler — Hot-Zone Filtering
//
// Maintains a set of named spatial zones (axis-aligned spheres with an
// importance weight). The ResearchLoop uses the sampler to pre-filter
// ExperienceRecords to only those that originated near a registered hot zone,
// dramatically reducing analysis compute when many athletes or game objects
// are active. Records that carry no position information are always retained.

#include "nexus/cell/experience_ledger.h"

#include <cmath>
#include <mutex>
#include <string>
#include <vector>

namespace nexus::cell {

struct SpatialZone {
  std::string name;
  float cx{0.0f};
  float cy{0.0f};
  float cz{0.0f};
  float radius{1.0f};
  float importance{1.0f}; ///< Sampling priority weight in [0, 1]
};

class SpatialSampler {
public:
  /// Register a new hot zone. Replaces any existing zone with the same name.
  void registerZone(SpatialZone zone);

  /// Remove all registered zones (reverts to pass-through filtering).
  void clearZones();

  [[nodiscard]] auto zoneCount() const -> std::size_t;

  /// Returns true if (x, y, z) falls within any registered zone.
  [[nodiscard]] auto isInAnyZone(float x, float y, float z) const -> bool;

  /// Filter experience records. Retains:
  ///   • Records whose context_json["position"] (keys "x","y","z") lies in a zone.
  ///   • Records that have no "position" field at all (position-agnostic events).
  /// When no zones are registered every record is retained.
  [[nodiscard]] auto filterRecords(std::vector<ExperienceRecord> records) const
      -> std::vector<ExperienceRecord>;

private:
  mutable std::mutex       m_mutex;
  std::vector<SpatialZone> m_zones;
};

} // namespace nexus::cell
