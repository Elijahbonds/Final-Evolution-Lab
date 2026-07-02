#include "nexus/renderer/bloom_runtime.h"

#include "nexus/core/env_flag.h"

namespace nexus::renderer {

auto BloomPassRuntimeFlags::fromEnvironment() -> BloomPassRuntimeFlags {
  BloomPassRuntimeFlags flags{};
  flags.gpuBloomResolveRequested = core::envFlagEnabled("NEXUS_GPU_BLOOM");
  flags.gpuBloomResolveEnabled = false;
  flags.previewBloomStub = true;
  return flags;
}

auto BloomPassRuntimeFlags::previewLabel() const -> std::string_view {
  if (gpuBloomResolveEnabled) {
    return "GPU bloom extract/blur enabled";
  }
  if (gpuBloomResolveRequested) {
    return "PREVIEW: NEXUS_GPU_BLOOM=1 set, but GPU bloom extract/blur is not implemented yet";
  }
  return "PREVIEW: bloom pass stub — GPU mip blur deferred (set NEXUS_GPU_BLOOM=1 when wired)";
}

auto BloomPassRuntimeFlags::shouldLogPreviewOnce() const -> bool {
  return previewBloomStub;
}

} // namespace nexus::renderer
