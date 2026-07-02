#pragma once

#include <cstdint>
#include <string_view>

namespace nexus::renderer {

/// Runtime flags for the shadow pass — honest preview labeling when GPU resolve is deferred.
struct ShadowPassRuntimeFlags {
  /// True when VkFramebuffer depth resolve is wired (future extension).
  bool gpuDepthResolveEnabled{false};
  /// True when the frame graph records a CPU/stub shadow pass only.
  bool previewShadowStub{true};

  [[nodiscard]] static auto fromEnvironment() -> ShadowPassRuntimeFlags;
  [[nodiscard]] auto previewLabel() const -> std::string_view;
  [[nodiscard]] auto shouldLogPreviewOnce() const -> bool;
};

} // namespace nexus::renderer
