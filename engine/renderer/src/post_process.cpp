#include "nexus/renderer/post_process.h"

#include <algorithm>
#include <cmath>

namespace nexus::renderer {

namespace {

auto acesFilmic(float x) -> float {
  const float a = 2.51F;
  const float b = 0.03F;
  const float c = 2.43F;
  const float d = 0.59F;
  const float e = 0.14F;
  return std::clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0F, 1.0F);
}

} // namespace

auto PostProcessChain::applyToneMap(float linearRgb) const -> float {
  if (!m_toneMap.enabled) {
    return linearRgb;
  }
  const float exposed = linearRgb * m_toneMap.exposure;
  switch (m_toneMap.op) {
  case ToneMapSettings::Operator::kAcesFilmic:
    return acesFilmic(exposed);
  case ToneMapSettings::Operator::kReinhard:
    return exposed / (1.0F + exposed);
  }
  return exposed;
}

auto PostProcessChain::passOrder() const -> std::vector<PostProcessStage> {
  std::vector<PostProcessStage> stages;
  if (m_bloom.enabled) {
    stages.push_back(PostProcessStage::kBloomExtract);
    stages.push_back(PostProcessStage::kBloomBlur);
  }
  if (m_toneMap.enabled) {
    stages.push_back(PostProcessStage::kToneMap);
  }
  if (shouldApplyFxaa()) {
    stages.push_back(PostProcessStage::kFxaa);
  }
  stages.push_back(PostProcessStage::kPresent);
  return stages;
}

auto PostProcessChain::shouldApplyFxaa() const -> bool {
  return m_antialiasing.enabled && m_antialiasing.mode == AntialiasingMode::kFxaa;
}

auto PostProcessChain::exceedsBloomThreshold(float linearLuminance) const -> bool {
  return m_bloom.enabled && linearLuminance >= m_bloom.threshold;
}

} // namespace nexus::renderer
