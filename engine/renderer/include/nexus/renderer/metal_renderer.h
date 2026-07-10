#pragma once

#include "nexus/core/result.h"
#include "nexus/renderer/scene.h"

#include <cstdint>
#include <string>
#include <vector>

#if defined(__OBJC__)
@class CAMetalLayer;
#else
struct CAMetalLayer;
#endif

namespace nexus::renderer {

struct MetalRendererConfig {
  std::uint32_t width{1280};
  std::uint32_t height{720};
  bool tripleBuffering{true};
  std::uint32_t preferredFps{60};
  /// When true, draw venue meshes as wireframe (validate-only embed path).
  bool validateOnlyWireframe{true};
  const char* manifestPath{"assets/nexus/manifests/nexus_asset_manifest.json"};
  const char* modeId{"basketball_dunk"};
};

/// Metal backend for iOS embed (spec §4.5). Vulkan remains the desktop dev runtime.
class MetalRenderer {
public:
  [[nodiscard]] auto initialize(CAMetalLayer* layer, const MetalRendererConfig& config)
      -> Result<void>;
  auto loadVenueFromManifest(std::string_view modeId) -> Result<void>;
  auto render(const RenderScene& scene) -> Result<void>;
  auto shutdown() -> void;

  [[nodiscard]] auto isInitialized() const -> bool { return m_initialized; }
  [[nodiscard]] auto lastError() const -> const std::string& { return m_lastError; }
  [[nodiscard]] auto lastDrawStats() const -> RenderScene::DrawStats { return m_lastDrawStats; }
  [[nodiscard]] auto validateDrawPathReady() const -> bool { return m_pipelineReady; }

private:
  struct GpuMesh {
    void* vertexBuffer{nullptr};
    void* indexBuffer{nullptr};
    std::uint32_t indexCount{0};
  };

  auto ensurePipeline() -> Result<void>;
  auto uploadSceneMeshes(const RenderScene& scene) -> Result<void>;
  void releaseGpuMeshes();

  bool m_initialized{false};
  bool m_pipelineReady{false};
  std::string m_lastError;
  MetalRendererConfig m_config{};
  std::string m_manifestPath;
  std::string m_modeId;
  RenderScene::DrawStats m_lastDrawStats{};
  CAMetalLayer* m_layer{nullptr};
  void* m_device{nullptr};
  void* m_commandQueue{nullptr};
  void* m_pipelineState{nullptr};
  void* m_instancedPipelineState{nullptr};
  void* m_depthStencilState{nullptr};
  std::vector<GpuMesh> m_gpuMeshes;
  std::size_t m_uploadedMeshCount{0};
};

} // namespace nexus::renderer
