// NEXUS port of archived FEL venue volume registry
#pragma once

#include <array>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <vector>

namespace nexus::gameplay {

struct Vec3f {
  float x{0.0F};
  float y{0.0F};
  float z{0.0F};
};

struct VenueVolume {
  std::string venueToken;
  std::string defaultModeId;
  Vec3f minBounds{};
  Vec3f maxBounds{};
};

struct VenueTravelEvent {
  std::string venueToken;
  std::string modeId;
};

class VenueVolumeRegistry {
public:
  void registerVolume(VenueVolume volume);
  void clearVolumes();
  [[nodiscard]] auto volumes() const -> std::span<const VenueVolume>;
  [[nodiscard]] auto checkPlayerOverlap(const Vec3f& playerPosition)
      -> std::optional<VenueTravelEvent>;
  void setPlayerPosition(Vec3f position);
  [[nodiscard]] auto playerPosition() const -> Vec3f;

private:
  [[nodiscard]] static auto contains(const VenueVolume& volume, const Vec3f& point) -> bool;

  std::vector<VenueVolume> m_volumes;
  Vec3f m_playerPosition{};
  std::optional<VenueTravelEvent> m_lastTravel;
};

} // namespace nexus::gameplay
