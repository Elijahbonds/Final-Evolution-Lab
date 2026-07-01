#pragma once

#include "nexus/core/result.h"
#include "nexus/renderer/bloom_runtime.h"
#include "nexus/renderer/lighting.h"
#include "nexus/renderer/post_process.h"
#include "nexus/renderer/shadow_runtime.h"
#include "nexus/renderer/scene.h"

#include <vulkan/vulkan.h>

#include <cstdint>
#include <vector>

struct SDL_Window;

namespace nexus::renderer {

struct RendererConfig {
  const char* title{"NEXUS Runtime (dev) — 3D arena preview"};
  std::uint32_t width{1280};
  std::uint32_t height{720};
  bool enableValidation{true};
  const char* manifestPath{"assets/nexus/manifests/nexus_asset_manifest.json"};
  const char* modeId{"basketball_dunk"};
};

class VulkanRenderer {
public:
  auto init(const RendererConfig& config) -> Result<void>;
  auto loadVenue(std::string_view modeId) -> Result<void>;
  void pollInput();
  void advanceScene(double deltaSeconds);
  void renderFrame();
  [[nodiscard]] auto shouldClose() const -> bool;
  [[nodiscard]] auto lastFrameDrawStats() const -> RenderScene::DrawStats;
  void shutdown();

private:
  struct GpuMesh {
    VkBuffer vertexBuffer{VK_NULL_HANDLE};
    VkDeviceMemory vertexMemory{VK_NULL_HANDLE};
    VkBuffer indexBuffer{VK_NULL_HANDLE};
    VkDeviceMemory indexMemory{VK_NULL_HANDLE};
    std::uint32_t indexCount{0};
  };

  auto createDevice() -> Result<void>;
  auto createRenderPass() -> Result<void>;
  auto createPipelineResources() -> Result<void>;
  auto createSwapchainResources() -> Result<void>;
  auto createDepthResources() -> Result<void>;
  auto createDescriptorResources() -> Result<void>;
  auto uploadSceneMeshes() -> Result<void>;
  void updateUniformBuffer();
  void recreateSwapchain();
  void destroyGpuMeshes();
  void destroyPipelineResources();
  void destroySwapchainResources();
  void destroyDepthResources();
  void destroyDevice();

  auto createShaderModule(const std::uint8_t* code, std::size_t codeSize) -> Result<VkShaderModule>;

  RenderScene m_scene{};
  std::vector<GpuMesh> m_gpuMeshes;
  SDL_Window* m_window{nullptr};
  VkInstance m_instance{VK_NULL_HANDLE};
  VkSurfaceKHR m_surface{VK_NULL_HANDLE};
  VkPhysicalDevice m_physicalDevice{VK_NULL_HANDLE};
  VkDevice m_device{VK_NULL_HANDLE};
  VkQueue m_graphicsQueue{VK_NULL_HANDLE};
  VkQueue m_presentQueue{VK_NULL_HANDLE};
  std::uint32_t m_graphicsQueueFamily{0};
  std::uint32_t m_presentQueueFamily{0};
  VkSwapchainKHR m_swapchain{VK_NULL_HANDLE};
  std::vector<VkImage> m_swapchainImages;
  std::vector<VkImageView> m_swapchainImageViews;
  VkFormat m_swapchainImageFormat{VK_FORMAT_UNDEFINED};
  VkExtent2D m_swapchainExtent{};
  VkRenderPass m_renderPass{VK_NULL_HANDLE};
  VkDescriptorSetLayout m_descriptorSetLayout{VK_NULL_HANDLE};
  VkDescriptorPool m_descriptorPool{VK_NULL_HANDLE};
  VkDescriptorSet m_descriptorSet{VK_NULL_HANDLE};
  VkPipelineLayout m_pipelineLayout{VK_NULL_HANDLE};
  VkPipeline m_pipeline{VK_NULL_HANDLE};
  VkBuffer m_uniformBuffer{VK_NULL_HANDLE};
  VkDeviceMemory m_uniformBufferMemory{VK_NULL_HANDLE};
  void* m_uniformMapped{nullptr};
  VkImage m_depthImage{VK_NULL_HANDLE};
  VkDeviceMemory m_depthImageMemory{VK_NULL_HANDLE};
  VkImageView m_depthImageView{VK_NULL_HANDLE};
  std::vector<VkFramebuffer> m_swapchainFramebuffers;
  VkCommandPool m_commandPool{VK_NULL_HANDLE};
  std::vector<VkCommandBuffer> m_commandBuffers;
  VkSemaphore m_imageAvailableSemaphore{VK_NULL_HANDLE};
  VkSemaphore m_renderFinishedSemaphore{VK_NULL_HANDLE};
  VkFence m_inFlightFence{VK_NULL_HANDLE};
  std::uint32_t m_currentImageIndex{0};
  bool m_swapchainReady{false};
  bool m_framebufferResized{false};
  bool m_shouldClose{false};
  std::string m_manifestPath;
  std::string m_modeId;
  std::string m_activeMeshProfile{"desktop"};
  RenderScene::DrawStats m_lastDrawStats{};
  LightingSetup m_lighting{};
  PostProcessChain m_postProcess{};
  ShadowPassRuntimeFlags m_shadowRuntime{};
  BloomPassRuntimeFlags m_bloomRuntime{};
  bool m_shadowPassExtensionLogged{false};
  bool m_postProcessExtensionLogged{false};
  void logDrawStats(const RenderScene::DrawStats& stats) const;
  void maybeLogDistanceLodExtension();
  void recordShadowPassStub(VkCommandBuffer commandBuffer);
  void recordPostProcessStub(VkCommandBuffer commandBuffer);
};

} // namespace nexus::renderer
