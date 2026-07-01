#pragma once

#include <array>
#include <vector>

namespace nexus::renderer {

enum class PostProcessStage {
  kBloomExtract,
  kBloomBlur,
  kToneMap,
  kFxaa,
  kPresent
};

enum class AntialiasingMode { kNone, kMsaa, kFxaa };

struct AntialiasingSettings {
  AntialiasingMode mode{AntialiasingMode::kFxaa};
  int msaaSamples{4};
  bool enabled{true};
};

struct BloomSettings {
  float threshold{0.85F};
  int mipLevels{3};
  float intensity{0.35F};
  bool enabled{true};
};

struct ToneMapSettings {
  enum class Operator { kAcesFilmic, kReinhard };

  Operator op{Operator::kAcesFilmic};
  float exposure{1.0F};
  bool enabled{true};
};

class PostProcessChain {
public:
  [[nodiscard]] auto bloom() const -> const BloomSettings& { return m_bloom; }
  [[nodiscard]] auto toneMap() const -> const ToneMapSettings& { return m_toneMap; }
  [[nodiscard]] auto antialiasing() const -> const AntialiasingSettings& { return m_antialiasing; }

  auto setBloom(BloomSettings settings) -> void { m_bloom = settings; }
  auto setToneMap(ToneMapSettings settings) -> void { m_toneMap = settings; }
  auto setAntialiasing(AntialiasingSettings settings) -> void { m_antialiasing = settings; }

  /// ACES filmic tonemap (matches spec §4.5 post-process stage).
  [[nodiscard]] auto applyToneMap(float linearRgb) const -> float;

  /// Render-pass ordering after the main scene pass (bloom → tonemap → present).
  [[nodiscard]] auto passOrder() const -> std::vector<PostProcessStage>;

  /// CPU bloom gate — pixels above threshold contribute to bloom extract.
  [[nodiscard]] auto exceedsBloomThreshold(float linearLuminance) const -> bool;

  /// True when the frame graph should reserve an FXAA resolve pass after tonemap.
  [[nodiscard]] auto shouldApplyFxaa() const -> bool;

private:
  BloomSettings m_bloom{};
  ToneMapSettings m_toneMap{};
  AntialiasingSettings m_antialiasing{};
};

} // namespace nexus::renderer
