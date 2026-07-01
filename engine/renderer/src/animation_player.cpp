#include "nexus/renderer/animation_player.h"

#include "nexus/core/log.h"

#include <algorithm>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <nlohmann/json.hpp>

namespace nexus::renderer {

auto AnimationPlayer::identityBoneMatrix() -> std::array<float, 16> {
  return {1.0F, 0.0F, 0.0F, 0.0F, 0.0F, 1.0F, 0.0F, 0.0F,
          0.0F, 0.0F, 1.0F, 0.0F, 0.0F, 0.0F, 0.0F, 1.0F};
}

auto AnimationPlayer::boneMatrixFromTranslation(const BoneSample& sample) -> std::array<float, 16> {
  auto matrix = identityBoneMatrix();
  matrix[12] = sample.translation[0];
  matrix[13] = sample.translation[1];
  matrix[14] = sample.translation[2];
  return matrix;
}

auto AnimationPlayer::parseClipJson(const nlohmann::json& root, std::string_view fallbackId)
    -> LoadedClip {
  LoadedClip loaded{};
  loaded.metadata.clipId = root.value("clip_id", std::string(fallbackId));
  loaded.metadata.durationSeconds = root.value("duration_seconds", 1.0F);
  loaded.metadata.framesPerSecond = root.value("frames_per_second", 30.0F);
  loaded.metadata.isLooping = root.value("looping", true);

  const std::size_t boneCount =
      root.value("/skeleton/bone_count"_json_pointer, static_cast<std::size_t>(22));

  if (root.contains("keyframes") && root["keyframes"].is_array()) {
    for (const nlohmann::json& keyframeNode : root["keyframes"]) {
      Keyframe keyframe{};
      keyframe.timeSeconds = keyframeNode.value("time", 0.0F);
      keyframe.bones.assign(boneCount, BoneSample{});

      if (keyframeNode.contains("bones") && keyframeNode["bones"].is_array()) {
        const auto& bones = keyframeNode["bones"];
        for (std::size_t boneIndex = 0;
             boneIndex < std::min(boneCount, bones.size());
             ++boneIndex) {
          const auto& boneNode = bones[boneIndex];
          if (boneNode.contains("translation") && boneNode["translation"].is_array() &&
              boneNode["translation"].size() >= 3) {
            keyframe.bones[boneIndex].translation[0] = boneNode["translation"][0];
            keyframe.bones[boneIndex].translation[1] = boneNode["translation"][1];
            keyframe.bones[boneIndex].translation[2] = boneNode["translation"][2];
          }
        }
      }
      loaded.keyframes.push_back(std::move(keyframe));
    }
  }

  if (loaded.keyframes.empty()) {
    Keyframe rest{};
    rest.timeSeconds = 0.0F;
    rest.bones.assign(boneCount, BoneSample{});
    loaded.keyframes.push_back(rest);

    Keyframe peak{};
    peak.timeSeconds = loaded.metadata.durationSeconds * 0.5F;
    peak.bones.assign(boneCount, BoneSample{});
    for (std::size_t bone = 0; bone < boneCount; ++bone) {
      peak.bones[bone].translation[1] = 0.05F + static_cast<float>(bone) * 0.001F;
    }
    loaded.keyframes.push_back(std::move(peak));
  }

  std::sort(loaded.keyframes.begin(),
            loaded.keyframes.end(),
            [](const Keyframe& left, const Keyframe& right) {
              return left.timeSeconds < right.timeSeconds;
            });
  loaded.metadata.keyframeCount = loaded.keyframes.size();
  return loaded;
}

auto AnimationPlayer::loadClip(std::string_view clipPath) -> Result<AnimationClip> {
  LoadedClip loaded{};
  const std::string pathString(clipPath);

  if (std::filesystem::exists(pathString)) {
    std::ifstream input(pathString);
    if (!input.is_open()) {
      return Result<AnimationClip>::err("Failed to open animation clip: " + pathString);
    }

    const nlohmann::json root = nlohmann::json::parse(input, nullptr, false);
    if (root.is_discarded()) {
      return Result<AnimationClip>::err("Invalid nexusanim JSON: " + pathString);
    }
    loaded = parseClipJson(root, clipPath);
    NEXUS_LOG_INFO(nexus::LogChannel::kRenderer,
                   "AnimationPlayer loaded clip: " + loaded.metadata.clipId + " keyframes=" +
                       std::to_string(loaded.metadata.keyframeCount));
  } else {
    loaded.metadata.clipId = pathString;
    loaded.metadata.durationSeconds = 1.0F;
    loaded.metadata.framesPerSecond = 30.0F;
    loaded.metadata.isLooping = true;
    loaded = parseClipJson(nlohmann::json::object(), clipPath);
    loaded.metadata.clipId = pathString;
    NEXUS_LOG_INFO(nexus::LogChannel::kRenderer,
                   "AnimationPlayer synthesized clip: " + loaded.metadata.clipId);
  }

  m_pose.boneCount = loaded.keyframes.front().bones.size();
  m_pose.boneMatrices.assign(m_pose.boneCount, identityBoneMatrix());
  rebuildSkinningBuffer();
  m_clips.push_back(std::move(loaded));
  return Result<AnimationClip>::ok(m_clips.back().metadata);
}

auto AnimationPlayer::play(std::string_view clipId) -> Result<void> {
  for (const LoadedClip& clip : m_clips) {
    if (clip.metadata.clipId == clipId) {
      m_activeClipId = clip.metadata.clipId;
      m_timeSeconds = 0.0F;
      samplePoseAtTime(0.0F, clip);
      return Result<void>::ok();
    }
  }
  return Result<void>::err("Clip not found: " + std::string(clipId));
}

auto AnimationPlayer::advance(float deltaSeconds) -> void {
  if (m_activeClipId.empty()) {
    return;
  }

  const LoadedClip* active = nullptr;
  for (const LoadedClip& clip : m_clips) {
    if (clip.metadata.clipId == m_activeClipId) {
      active = &clip;
      break;
    }
  }
  if (active == nullptr) {
    return;
  }

  m_timeSeconds += deltaSeconds;
  if (active->metadata.isLooping && active->metadata.durationSeconds > 0.0F) {
    m_timeSeconds = std::fmod(m_timeSeconds, active->metadata.durationSeconds);
  } else if (active->metadata.durationSeconds > 0.0F) {
    m_timeSeconds = std::min(m_timeSeconds, active->metadata.durationSeconds);
  }

  samplePoseAtTime(m_timeSeconds, *active);
}

auto AnimationPlayer::stop() -> void {
  m_activeClipId.clear();
  m_timeSeconds = 0.0F;
}

auto AnimationPlayer::normalizedTime() const -> float {
  if (m_activeClipId.empty()) {
    return 0.0F;
  }
  for (const LoadedClip& clip : m_clips) {
    if (clip.metadata.clipId == m_activeClipId && clip.metadata.durationSeconds > 0.0F) {
      return std::clamp(m_timeSeconds / clip.metadata.durationSeconds, 0.0F, 1.0F);
    }
  }
  return 0.0F;
}

auto AnimationPlayer::pose() const -> SkeletonPose {
  return m_pose;
}

auto AnimationPlayer::skinningMatrixData() const -> std::span<const float> {
  return m_skinningFlat;
}

auto AnimationPlayer::gpuSkinningUniformByteSize() const -> std::size_t {
  return m_skinningFlat.size() * sizeof(float);
}

void AnimationPlayer::rebuildSkinningBuffer() {
  m_skinningFlat.clear();
  m_skinningFlat.reserve(m_pose.boneCount * 16);
  for (const auto& matrix : m_pose.boneMatrices) {
    m_skinningFlat.insert(m_skinningFlat.end(), matrix.begin(), matrix.end());
  }
}

void AnimationPlayer::samplePoseAtTime(float timeSeconds, const LoadedClip& clip) {
  if (clip.keyframes.empty()) {
    return;
  }

  const Keyframe* previous = &clip.keyframes.front();
  const Keyframe* next = &clip.keyframes.back();
  for (std::size_t index = 1; index < clip.keyframes.size(); ++index) {
    if (clip.keyframes[index].timeSeconds >= timeSeconds) {
      next = &clip.keyframes[index];
      previous = &clip.keyframes[index - 1];
      break;
    }
    previous = &clip.keyframes[index];
    next = &clip.keyframes[index];
  }

  const float span = next->timeSeconds - previous->timeSeconds;
  const float alpha = span > 0.0F ? std::clamp((timeSeconds - previous->timeSeconds) / span, 0.0F, 1.0F)
                                  : 0.0F;

  const std::size_t boneCount = previous->bones.size();
  m_pose.boneCount = boneCount;
  if (m_pose.boneMatrices.size() != boneCount) {
    m_pose.boneMatrices.assign(boneCount, identityBoneMatrix());
  }

  for (std::size_t bone = 0; bone < boneCount; ++bone) {
    BoneSample blended{};
    for (int axis = 0; axis < 3; ++axis) {
      blended.translation[axis] = std::lerp(previous->bones[bone].translation[axis],
                                            next->bones[bone].translation[axis],
                                            alpha);
    }
    m_pose.boneMatrices[bone] = boneMatrixFromTranslation(blended);
  }

  rebuildSkinningBuffer();
}

} // namespace nexus::renderer
