#include "nexus/renderer/camera.h"

#include <cmath>

namespace nexus::renderer {

namespace {

constexpr float kPi = 3.14159265F;

auto multiplyMatrix(const std::array<float, 16>& a, const std::array<float, 16>& b)
    -> std::array<float, 16> {
  std::array<float, 16> out{};
  for (int column = 0; column < 4; ++column) {
    for (int row = 0; row < 4; ++row) {
      float sum = 0.0F;
      for (int k = 0; k < 4; ++k) {
        sum += a[k * 4 + row] * b[column * 4 + k];
      }
      out[column * 4 + row] = sum;
    }
  }
  return out;
}

auto perspectiveMatrix(float fovYRadians, float aspect, float nearPlane, float farPlane)
    -> std::array<float, 16> {
  const float tangent = std::tan(fovYRadians * 0.5F);
  const float sy = 1.0F / tangent;
  const float sx = sy / aspect;
  const float a = farPlane / (nearPlane - farPlane);
  const float b = (nearPlane * farPlane) / (nearPlane - farPlane);
  return {sx, 0.0F, 0.0F, 0.0F, 0.0F, sy, 0.0F, 0.0F, 0.0F, 0.0F, a, -1.0F, 0.0F, 0.0F, b, 0.0F};
}

auto lookAtMatrix(float eyeX,
                  float eyeY,
                  float eyeZ,
                  float centerX,
                  float centerY,
                  float centerZ) -> std::array<float, 16> {
  float forwardX = centerX - eyeX;
  float forwardY = centerY - eyeY;
  float forwardZ = centerZ - eyeZ;
  const float forwardLength =
      std::sqrt(forwardX * forwardX + forwardY * forwardY + forwardZ * forwardZ);
  forwardX /= forwardLength;
  forwardY /= forwardLength;
  forwardZ /= forwardLength;

  float sideX = forwardY * 0.0F - forwardZ * 1.0F;
  float sideY = forwardZ * 0.0F - forwardX * 0.0F;
  float sideZ = forwardX * 1.0F - forwardY * 0.0F;
  const float sideLength = std::sqrt(sideX * sideX + sideY * sideY + sideZ * sideZ);
  sideX /= sideLength;
  sideY /= sideLength;
  sideZ /= sideLength;

  const float upX = sideY * forwardZ - sideZ * forwardY;
  const float upY = sideZ * forwardX - sideX * forwardZ;
  const float upZ = sideX * forwardY - sideY * forwardX;

  return {sideX,
          upX,
          -forwardX,
          0.0F,
          sideY,
          upY,
          -forwardY,
          0.0F,
          sideZ,
          upZ,
          -forwardZ,
          0.0F,
          -(sideX * eyeX + sideY * eyeY + sideZ * eyeZ),
          -(upX * eyeX + upY * eyeY + upZ * eyeZ),
          forwardX * eyeX + forwardY * eyeY + forwardZ * eyeZ,
          1.0F};
}

} // namespace

void Camera::setPerspective(float fovYDegrees,
                            float aspectRatio,
                            float nearPlane,
                            float farPlane) {
  m_fovYDegrees = fovYDegrees;
  m_aspectRatio = aspectRatio;
  m_nearPlane = nearPlane;
  m_farPlane = farPlane;
}

void Camera::setOrbitTarget(float targetX, float targetY, float targetZ) {
  m_targetX = targetX;
  m_targetY = targetY;
  m_targetZ = targetZ;
}

void Camera::setOrbit(float radius, float eyeHeight, float orbitRadians) {
  m_orbitRadius = radius;
  m_eyeHeight = eyeHeight;
  m_orbitRadians = orbitRadians;
}

void Camera::advanceOrbit(float deltaRadians) {
  m_orbitRadians += deltaRadians;
}

auto Camera::viewMatrix() const -> std::array<float, 16> {
  const float eyeX = m_orbitRadius * std::cos(m_orbitRadians);
  const float eyeZ = m_orbitRadius * std::sin(m_orbitRadians);
  return lookAtMatrix(eyeX, m_eyeHeight, eyeZ, m_targetX, m_targetY, m_targetZ);
}

auto Camera::projectionMatrix() const -> std::array<float, 16> {
  return perspectiveMatrix(m_fovYDegrees * kPi / 180.0F, m_aspectRatio, m_nearPlane, m_farPlane);
}

auto Camera::viewProjectionMatrix() const -> std::array<float, 16> {
  return multiplyMatrix(projectionMatrix(), viewMatrix());
}

} // namespace nexus::renderer
