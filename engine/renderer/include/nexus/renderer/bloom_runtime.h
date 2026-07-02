#pragma once

#include <cstdint>
#include <string_view>

namespace nexus::renderer {

/// Runtime flags for the bloom post-process pass — honest preview labeling when GPU resolve is deferred.
struct BloomPassRuntimeFlags {
  /// True when the environment requested the future GPU bloom pass.
  bool gpuBloomResolveRequested{false};
  /// True when GPU bloom extract/blur passes are wired (future extension).
  bool gpuBloomResolveEnabled{false};
  /// True when the frame graph records CPU/stub bloom only.
  bool previewBloomStub{true};

  [[nodiscard]] static auto fromEnvironment() -> BloomPassRuntimeFlags;
  [[nodiscard]] auto previewLabel() const -> std::string_view;
  [[nodiscard]] auto shouldLogPreviewOnce() const -> bool;
};

} // namespace nexus::renderer
