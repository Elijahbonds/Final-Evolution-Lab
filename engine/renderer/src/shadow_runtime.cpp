#include "nexus/renderer/shadow_runtime.h"

#include "nexus/core/env_flag.h"

namespace nexus::renderer {

auto ShadowPassRuntimeFlags::fromEnvironment() -> ShadowPassRuntimeFlags {
  ShadowPassRuntimeFlags flags{};
  flags.gpuDepthResolveRequested = core::envFlagEnabled("NEXUS_GPU_SHADOW");
  flags.gpuDepthResolveEnabled = false;
  flags.previewShadowStub = true;
  return flags;
}

auto ShadowPassRuntimeFlags::previewLabel() const -> std::string_view {
  if (gpuDepthResolveEnabled) {
    return "GPU shadow depth resolve enabled";
  }
  if (gpuDepthResolveRequested) {
    return "PREVIEW: NEXUS_GPU_SHADOW=1 set, but GPU shadow depth resolve is not implemented yet";
  }
  return "PREVIEW: shadow-map pass stub — GPU depth resolve deferred (set NEXUS_GPU_SHADOW=1 when wired)";
}

auto ShadowPassRuntimeFlags::shouldLogPreviewOnce() const -> bool {
  return previewShadowStub;
}

} // namespace nexus::renderer
