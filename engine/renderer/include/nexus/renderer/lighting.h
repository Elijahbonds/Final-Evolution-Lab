#pragma once

#include <array>
#include <cstdint>

namespace nexus::renderer {

struct DirectionalLight {
  std::array<float, 3> direction{-0.35F, -1.0F, -0.25F};
  std::array<float, 3> color{1.0F, 0.98F, 0.94F};
  float intensity{1.15F};
  bool castsShadows{true};
};

struct ShadowPassConfig {
  std::uint32_t mapSize{1024};
  float cascadeSplit{1.0F};
  float bias{0.002F};
  bool enabled{true};
};

class LightingSetup {
public:
  [[nodiscard]] auto directionalLight() const -> const DirectionalLight& { return m_sun; }
  [[nodiscard]] auto shadowPass() const -> const ShadowPassConfig& { return m_shadow; }

  auto setDirectionalLight(DirectionalLight light) -> void { m_sun = light; }
  auto setShadowPass(ShadowPassConfig config) -> void { m_shadow = config; }

  [[nodiscard]] auto normalizedSunDirection() const -> std::array<float, 3>;

  /// True when the frame graph should reserve a shadow-map pass before the main pass.
  [[nodiscard]] auto shouldRecordShadowPass() const -> bool;

  /// Orthographic light-space matrix stub for shadow-map pass (column-major 4×4).
  [[nodiscard]] auto shadowLightViewProjection() const -> std::array<float, 16>;

private:
  DirectionalLight m_sun{};
  ShadowPassConfig m_shadow{};
};

} // namespace nexus::renderer
