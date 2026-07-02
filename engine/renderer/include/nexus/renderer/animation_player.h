#pragma once

#include "nexus/core/result.h"

#include <array>
#include <cstddef>
#include <nlohmann/json_fwd.hpp>
#include <span>
#include <string>
#include <string_view>
#include <vector>

namespace nexus::renderer {

struct SkeletonPose {
  std::vector<std::array<float, 16>> boneMatrices;
  std::size_t boneCount{0};
};

struct AnimationClip {
  std::string clipId;
  float durationSeconds{1.0F};
  float framesPerSecond{30.0F};
  std::size_t keyframeCount{0};
  bool isLooping{true};
};

/// Advances skeletal clips and produces bone matrices for GPU skinning uniform upload.
class AnimationPlayer {
public:
  [[nodiscard]] auto loadClip(std::string_view clipPath) -> Result<AnimationClip>;
  auto play(std::string_view clipId) -> Result<void>;
  auto advance(float deltaSeconds) -> void;
  auto stop() -> void;

  [[nodiscard]] auto currentClipId() const -> std::string_view { return m_activeClipId; }
  [[nodiscard]] auto normalizedTime() const -> float;
  [[nodiscard]] auto pose() const -> SkeletonPose;

  /// Flat column-major 4x4 bone matrices for `vkCmdPushConstants` / skinning UBO.
  [[nodiscard]] auto skinningMatrixData() const -> std::span<const float>;
  [[nodiscard]] auto gpuSkinningUniformByteSize() const -> std::size_t;

private:
  struct BoneSample {
    float translation[3]{0.0F, 0.0F, 0.0F};
  };

  struct Keyframe {
    float timeSeconds{0.0F};
    std::vector<BoneSample> bones;
  };

  struct LoadedClip {
    AnimationClip metadata;
    std::vector<Keyframe> keyframes;
  };

  void rebuildSkinningBuffer();
  void samplePoseAtTime(float timeSeconds, const LoadedClip& clip);
  [[nodiscard]] static auto identityBoneMatrix() -> std::array<float, 16>;
  [[nodiscard]] static auto boneMatrixFromTranslation(const BoneSample& sample)
      -> std::array<float, 16>;
  [[nodiscard]] static auto parseClipJson(const nlohmann::json& root, std::string_view fallbackId)
      -> LoadedClip;

  std::vector<LoadedClip> m_clips;
  std::string m_activeClipId;
  float m_timeSeconds{0.0F};
  SkeletonPose m_pose{};
  std::vector<float> m_skinningFlat;
};

} // namespace nexus::renderer
