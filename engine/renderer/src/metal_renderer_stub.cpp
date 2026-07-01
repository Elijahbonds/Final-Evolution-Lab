#include "nexus/renderer/metal_renderer.h"

#include "nexus/core/log.h"

namespace nexus::renderer {

auto MetalRenderer::initialize(CAMetalLayer* layer, const MetalRendererConfig& config)
    -> Result<void> {
  (void)layer;
  (void)config;
  m_lastError = "MetalRenderer only available on Apple platforms";
  NEXUS_LOG_INFO(nexus::LogChannel::kRenderer, m_lastError);
  return Result<void>::err(m_lastError);
}

auto MetalRenderer::loadVenueFromManifest(std::string_view modeId) -> Result<void> {
  (void)modeId;
  m_lastError = "MetalRenderer only available on Apple platforms";
  return Result<void>::err(m_lastError);
}

auto MetalRenderer::render(const RenderScene& scene) -> Result<void> {
  (void)scene;
  if (!m_initialized) {
    m_lastError = "MetalRenderer not initialized";
    return Result<void>::err(m_lastError);
  }
  m_lastError = "MetalRenderer only available on Apple platforms";
  return Result<void>::err(m_lastError);
}

auto MetalRenderer::shutdown() -> void {
  m_initialized = false;
  m_pipelineReady = false;
  m_layer = nullptr;
  m_device = nullptr;
  m_commandQueue = nullptr;
  m_lastError.clear();
}

auto MetalRenderer::ensurePipeline() -> Result<void> {
  return Result<void>::err("MetalRenderer only available on Apple platforms");
}

auto MetalRenderer::uploadSceneMeshes(const RenderScene& scene) -> Result<void> {
  (void)scene;
  return Result<void>::err("MetalRenderer only available on Apple platforms");
}

void MetalRenderer::releaseGpuMeshes() {}

} // namespace nexus::renderer
