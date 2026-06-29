#include "nexus/gameplay/venue_volume_registry.h"

#include <algorithm>

namespace nexus::gameplay {

void VenueVolumeRegistry::registerVolume(VenueVolume volume) {
  m_volumes.push_back(std::move(volume));
}

void VenueVolumeRegistry::clearVolumes() {
  m_volumes.clear();
  m_lastTravel.reset();
}

auto VenueVolumeRegistry::volumes() const -> std::span<const VenueVolume> {
  return m_volumes;
}

void VenueVolumeRegistry::setPlayerPosition(Vec3f position) {
  m_playerPosition = position;
}

auto VenueVolumeRegistry::playerPosition() const -> Vec3f {
  return m_playerPosition;
}

auto VenueVolumeRegistry::contains(const VenueVolume& volume, const Vec3f& point) -> bool {
  return point.x >= volume.minBounds.x && point.x <= volume.maxBounds.x &&
         point.y >= volume.minBounds.y && point.y <= volume.maxBounds.y &&
         point.z >= volume.minBounds.z && point.z <= volume.maxBounds.z;
}

auto VenueVolumeRegistry::checkPlayerOverlap(const Vec3f& playerPosition)
    -> std::optional<VenueTravelEvent> {
  for (const VenueVolume& volume : m_volumes) {
    if (!contains(volume, playerPosition)) {
      continue;
    }
    VenueTravelEvent event{
        .venueToken = volume.venueToken,
        .modeId = volume.defaultModeId,
    };
    if (m_lastTravel.has_value() && m_lastTravel->venueToken == event.venueToken &&
        m_lastTravel->modeId == event.modeId) {
      return std::nullopt;
    }
    m_lastTravel = event;
    return event;
  }
  return std::nullopt;
}

} // namespace nexus::gameplay
