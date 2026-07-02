#include "nexus/renderer/lighting.h"

#include <cmath>

namespace nexus::renderer {

auto LightingSetup::normalizedSunDirection() const -> std::array<float, 3> {
  const float x = m_sun.direction[0];
  const float y = m_sun.direction[1];
  const float z = m_sun.direction[2];
  const float len = std::sqrt(x * x + y * y + z * z);
  if (len <= 1e-6F) {
    return {0.0F, -1.0F, 0.0F};
  }
  return {x / len, y / len, z / len};
}

auto LightingSetup::shouldRecordShadowPass() const -> bool {
  return m_shadow.enabled && m_sun.castsShadows;
}

auto LightingSetup::shadowLightViewProjection() const -> std::array<float, 16> {
  const auto dir = normalizedSunDirection();
  // Column-major orthographic stub aligned to sun direction (full cascade fit deferred).
  std::array<float, 16> m{};
  m[0] = 1.0F;
  m[5] = 1.0F;
  m[10] = 1.0F + dir[2] * 0.01F;
  m[15] = 1.0F;
  m[2] = dir[0] * 0.01F;
  m[6] = dir[1] * 0.01F;
  return m;
}

} // namespace nexus::renderer
