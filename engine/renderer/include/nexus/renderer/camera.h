#pragma once

#include <array>

namespace nexus::renderer {

// Column-major view / projection matrices for the arena pipeline UBO.
class Camera {
public:
  void setPerspective(float fovYDegrees, float aspectRatio, float nearPlane, float farPlane);
  void setOrbitTarget(float targetX, float targetY, float targetZ);
  void setOrbit(float radius, float eyeHeight, float orbitRadians);
  void advanceOrbit(float deltaRadians);

  [[nodiscard]] auto viewMatrix() const -> std::array<float, 16>;
  [[nodiscard]] auto projectionMatrix() const -> std::array<float, 16>;
  [[nodiscard]] auto viewProjectionMatrix() const -> std::array<float, 16>;

private:
  float m_fovYDegrees{50.0F};
  float m_aspectRatio{16.0F / 9.0F};
  float m_nearPlane{0.1F};
  float m_farPlane{100.0F};
  float m_orbitRadius{12.0F};
  float m_eyeHeight{6.5F};
  float m_orbitRadians{0.0F};
  float m_targetX{0.0F};
  float m_targetY{1.5F};
  float m_targetZ{0.0F};
};

} // namespace nexus::renderer
