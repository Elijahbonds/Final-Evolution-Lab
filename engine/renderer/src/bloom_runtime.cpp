#include "nexus/renderer/bloom_runtime.h"

#include "nexus/core/env_flag.h"

namespace nexus::renderer {

auto BloomPassRuntimeFlags::fromEnvironment() -> BloomPassRuntimeFlags {
  BloomPassRuntimeFlags flags{};
  flags.gpuBloomResolveEnabled = core::envFlagEnabled("NEXUS_GPU_BLOOM");
  flags.previewBloomStub = !flags.gpuBloomResolveEnabled;
  return flags;
}

auto BloomPassRuntimeFlags::previewLabel() const -> std::string_view {
  if (gpuBloomResolveEnabled) {
    return "GPU bloom extract/blur enabled";
  }
  return "PREVIEW: bloom pass stub — GPU mip blur deferred (set NEXUS_GPU_BLOOM=1 when wired)";
}

auto BloomPassRuntimeFlags::shouldLogPreviewOnce() const -> bool {
  return previewBloomStub;
}

} // namespace nexus::renderer
