#include "nexus/cell/spatial_sampler.h"

#include <algorithm>

namespace nexus::cell {

void SpatialSampler::registerZone(SpatialZone zone) {
  std::scoped_lock lock(m_mutex);
  // Replace existing zone with the same name if present.
  for (auto& existing : m_zones) {
    if (existing.name == zone.name) {
      existing = std::move(zone);
      return;
    }
  }
  m_zones.push_back(std::move(zone));
}

void SpatialSampler::clearZones() {
  std::scoped_lock lock(m_mutex);
  m_zones.clear();
}

auto SpatialSampler::zoneCount() const -> std::size_t {
  std::scoped_lock lock(m_mutex);
  return m_zones.size();
}

auto SpatialSampler::isInAnyZone(float x, float y, float z) const -> bool {
  std::scoped_lock lock(m_mutex);
  for (const auto& zone : m_zones) {
    const float dx = x - zone.cx;
    const float dy = y - zone.cy;
    const float dz = z - zone.cz;
    if (dx * dx + dy * dy + dz * dz <= zone.radius * zone.radius) {
      return true;
    }
  }
  return false;
}

auto SpatialSampler::filterRecords(std::vector<ExperienceRecord> records) const
    -> std::vector<ExperienceRecord> {
  std::scoped_lock lock(m_mutex);
  if (m_zones.empty()) {
    return records; // pass-through: no zones registered
  }

  std::vector<ExperienceRecord> out;
  out.reserve(records.size());

  for (auto& rec : records) {
    // Records without a "position" field are always retained.
    if (!rec.context_json.contains("position")) {
      out.push_back(std::move(rec));
      continue;
    }

    const auto& pos = rec.context_json["position"];
    const float px  = pos.value("x", 0.0f);
    const float py  = pos.value("y", 0.0f);
    const float pz  = pos.value("z", 0.0f);

    for (const auto& zone : m_zones) {
      const float dx = px - zone.cx;
      const float dy = py - zone.cy;
      const float dz = pz - zone.cz;
      if (dx * dx + dy * dy + dz * dz <= zone.radius * zone.radius) {
        out.push_back(std::move(rec));
        break;
      }
    }
  }

  return out;
}

} // namespace nexus::cell
