#pragma once

#include "nexus/core/result.h"

#include <vulkan/vulkan.h>

#include <cstdint>
#include <vector>

struct SDL_Window;

namespace nexus::renderer {

struct RendererConfig {
  const char* title{"NEXUS Runtime (dev) — open FinalEvolutionLab on iPhone"};
  std::uint32_t width{1280};
  std::uint32_t height{720};
  bool enableValidation{true};
};

class VulkanRenderer {
public:
  auto init(const RendererConfig& config) -> Result<void>;
  void pollInput();
  void renderFrame();
  [[nodiscard]] auto shouldClose() const -> bool;
  void shutdown();

private:
  auto createDevice() -> Result<void>;
  auto createRenderPass() -> Result<void>;
  auto createPipelineResources() -> Result<void>;
  auto createSwapchainResources() -> Result<void>;
  void recreateSwapchain();
  void destroyPipelineResources();
  void destroySwapchainResources();
  void destroyDevice();

  auto createShaderModule(const std::uint8_t* code, std::size_t codeSize) -> Result<VkShaderModule>;

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
  VkPipelineLayout m_pipelineLayout{VK_NULL_HANDLE};
  VkPipeline m_pipeline{VK_NULL_HANDLE};
  VkBuffer m_vertexBuffer{VK_NULL_HANDLE};
  VkDeviceMemory m_vertexBufferMemory{VK_NULL_HANDLE};
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
};

} // namespace nexus::renderer
