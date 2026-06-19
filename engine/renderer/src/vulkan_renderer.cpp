#include "nexus/renderer/vulkan_renderer.h"

#include "nexus/renderer/triangle_shader_spv.h"
#include "nexus/core/log.h"

#include <SDL3/SDL.h>
#include <SDL3/SDL_vulkan.h>

#include <algorithm>
#include <array>
#include <cstring>
#include <limits>
#include <optional>
#include <string>
#include <vector>

namespace nexus::renderer {

namespace {

struct TriangleVertex {
  float position[2];
  float color[3];
};

// Brand triangle + top banner bar (2 triangles) — must stay CCW in clip space (Y-up).
constexpr std::array<TriangleVertex, 9> kTriangleVertices = {
    TriangleVertex{{0.0F, -0.85F}, {0.0F, 0.83F, 1.0F}},
    TriangleVertex{{0.85F, 0.85F}, {0.0F, 0.95F, 0.9F}},
    TriangleVertex{{-0.85F, 0.85F}, {0.2F, 0.5F, 1.0F}},
    TriangleVertex{{-1.0F, 1.0F}, {0.0F, 0.83F, 1.0F}},
    TriangleVertex{{1.0F, 1.0F}, {0.0F, 0.83F, 1.0F}},
    TriangleVertex{{1.0F, 0.88F}, {0.0F, 0.83F, 1.0F}},
    TriangleVertex{{-1.0F, 1.0F}, {0.0F, 0.83F, 1.0F}},
    TriangleVertex{{1.0F, 0.88F}, {0.0F, 0.83F, 1.0F}},
    TriangleVertex{{-1.0F, 0.88F}, {0.0F, 0.83F, 1.0F}},
};

auto requiredValidationLayers() -> std::vector<const char*> {
#if defined(NDEBUG) || defined(__APPLE__)
  return {};
#else
  return {"VK_LAYER_KHRONOS_validation"};
#endif
}

auto requiredDeviceExtensions() -> std::vector<const char*> {
  std::vector<const char*> extensions = {VK_KHR_SWAPCHAIN_EXTENSION_NAME};
#if defined(__APPLE__)
  extensions.push_back("VK_KHR_portability_subset");
#endif
  return extensions;
}

auto findQueueFamilies(VkPhysicalDevice device, VkSurfaceKHR surface)
    -> std::optional<std::pair<std::uint32_t, std::uint32_t>> {
  std::uint32_t queueFamilyCount = 0;
  vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, nullptr);
  std::vector<VkQueueFamilyProperties> queueFamilies(queueFamilyCount);
  vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, queueFamilies.data());

  std::optional<std::uint32_t> graphicsFamily;
  std::optional<std::uint32_t> presentFamily;

  for (std::uint32_t index = 0; index < queueFamilyCount; ++index) {
    if (queueFamilies[index].queueFlags & VK_QUEUE_GRAPHICS_BIT) {
      graphicsFamily = index;
    }

    VkBool32 presentSupport = VK_FALSE;
    vkGetPhysicalDeviceSurfaceSupportKHR(device, index, surface, &presentSupport);
    if (presentSupport == VK_TRUE) {
      presentFamily = index;
    }

    if (graphicsFamily.has_value() && presentFamily.has_value()) {
      break;
    }
  }

  if (!graphicsFamily.has_value() || !presentFamily.has_value()) {
    return std::nullopt;
  }
  return std::make_pair(*graphicsFamily, *presentFamily);
}

auto findMemoryType(VkPhysicalDevice physicalDevice,
                    std::uint32_t typeFilter,
                    VkMemoryPropertyFlags properties) -> std::uint32_t {
  VkPhysicalDeviceMemoryProperties memoryProperties{};
  vkGetPhysicalDeviceMemoryProperties(physicalDevice, &memoryProperties);

  for (std::uint32_t index = 0; index < memoryProperties.memoryTypeCount; ++index) {
    if ((typeFilter & (1U << index)) &&
        (memoryProperties.memoryTypes[index].propertyFlags & properties) == properties) {
      return index;
    }
  }
  return std::numeric_limits<std::uint32_t>::max();
}

auto chooseSwapSurfaceFormat(const std::vector<VkSurfaceFormatKHR>& formats)
    -> VkSurfaceFormatKHR {
  for (const auto& format : formats) {
    if (format.format == VK_FORMAT_B8G8R8A8_SRGB &&
        format.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) {
      return format;
    }
  }
  return formats.front();
}

auto chooseSwapPresentMode(const std::vector<VkPresentModeKHR>& modes) -> VkPresentModeKHR {
  for (const auto mode : modes) {
    if (mode == VK_PRESENT_MODE_MAILBOX_KHR) {
      return mode;
    }
  }
  return VK_PRESENT_MODE_FIFO_KHR;
}

auto chooseSwapExtent(const VkSurfaceCapabilitiesKHR& capabilities,
                      std::uint32_t width,
                      std::uint32_t height) -> VkExtent2D {
  if (capabilities.currentExtent.width != std::numeric_limits<std::uint32_t>::max()) {
    return capabilities.currentExtent;
  }

  VkExtent2D extent{width, height};
  extent.width = std::clamp(extent.width,
                            capabilities.minImageExtent.width,
                            capabilities.maxImageExtent.width);
  extent.height = std::clamp(extent.height,
                             capabilities.minImageExtent.height,
                             capabilities.maxImageExtent.height);
  return extent;
}

} // namespace

auto VulkanRenderer::init(const RendererConfig& config) -> Result<void> {
  if (!SDL_Init(SDL_INIT_VIDEO)) {
    return Result<void>::err(SDL_GetError());
  }

#if defined(__APPLE__)
  // Use the same Vulkan loader the binary links against (Vulkan::Vulkan).
  // Loading libMoltenVK.dylib directly here duplicates MoltenVK in-process and
  // crashes inside MVK entry-point dispatch when vk* calls go through the loader.
  if (!SDL_Vulkan_LoadLibrary(nullptr)) {
    const std::string error = SDL_GetError();
    SDL_Quit();
    return Result<void>::err(error);
  }
#endif

  m_window = SDL_CreateWindow(config.title,
                              static_cast<int>(config.width),
                              static_cast<int>(config.height),
                              SDL_WINDOW_VULKAN | SDL_WINDOW_RESIZABLE);
  if (m_window == nullptr) {
    const std::string error = SDL_GetError();
    SDL_Quit();
    return Result<void>::err(error);
  }

  VkApplicationInfo appInfo{};
  appInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
  appInfo.pApplicationName = config.title;
  appInfo.applicationVersion = VK_MAKE_VERSION(0, 1, 0);
  appInfo.pEngineName = "NEXUS";
  appInfo.engineVersion = VK_MAKE_VERSION(0, 1, 0);
  appInfo.apiVersion = VK_API_VERSION_1_1;

  auto validationLayers = config.enableValidation ? requiredValidationLayers()
                                                  : std::vector<const char*>{};

  std::vector<const char*> instanceExtensions{};
  Uint32 sdlExtensionCount = 0;
  const char* const* sdlExtensions = SDL_Vulkan_GetInstanceExtensions(&sdlExtensionCount);
  if (sdlExtensions == nullptr) {
    const std::string error = SDL_GetError();
    SDL_DestroyWindow(m_window);
    m_window = nullptr;
    SDL_Quit();
    return Result<void>::err(error);
  }
  instanceExtensions.insert(instanceExtensions.end(), sdlExtensions, sdlExtensions + sdlExtensionCount);

#if defined(__APPLE__)
  instanceExtensions.push_back(VK_KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME);
#endif

  VkInstanceCreateInfo createInfo{};
  createInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
  createInfo.pApplicationInfo = &appInfo;
  createInfo.enabledLayerCount = static_cast<std::uint32_t>(validationLayers.size());
  createInfo.ppEnabledLayerNames = validationLayers.empty() ? nullptr : validationLayers.data();
  createInfo.enabledExtensionCount = static_cast<std::uint32_t>(instanceExtensions.size());
  createInfo.ppEnabledExtensionNames =
      instanceExtensions.empty() ? nullptr : instanceExtensions.data();
#if defined(__APPLE__)
  createInfo.flags |= VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR;
#endif

  const VkResult instanceResult = vkCreateInstance(&createInfo, nullptr, &m_instance);
  if (instanceResult != VK_SUCCESS) {
    SDL_DestroyWindow(m_window);
    m_window = nullptr;
    SDL_Quit();
    return Result<void>::err("Failed to create Vulkan instance (VkResult=" +
                             std::to_string(static_cast<int>(instanceResult)) + ")");
  }

  if (!SDL_Vulkan_CreateSurface(m_window, m_instance, nullptr, &m_surface)) {
    const std::string error = SDL_GetError();
    shutdown();
    return Result<void>::err(error);
  }

  const auto deviceResult = createDevice();
  if (deviceResult.isErr()) {
    shutdown();
    return deviceResult;
  }

  std::uint32_t formatCount = 0;
  vkGetPhysicalDeviceSurfaceFormatsKHR(m_physicalDevice, m_surface, &formatCount, nullptr);
  if (formatCount == 0) {
    shutdown();
    return Result<void>::err("No Vulkan surface formats available");
  }
  std::vector<VkSurfaceFormatKHR> formats(formatCount);
  vkGetPhysicalDeviceSurfaceFormatsKHR(m_physicalDevice, m_surface, &formatCount, formats.data());
  m_swapchainImageFormat = chooseSwapSurfaceFormat(formats).format;

  const auto renderPassResult = createRenderPass();
  if (renderPassResult.isErr()) {
    shutdown();
    return renderPassResult;
  }

  const auto pipelineResult = createPipelineResources();
  if (pipelineResult.isErr()) {
    shutdown();
    return pipelineResult;
  }

  const auto swapchainResult = createSwapchainResources();
  if (swapchainResult.isErr()) {
    shutdown();
    return swapchainResult;
  }

  NEXUS_LOG_INFO(LogChannel::kRenderer, "Vulkan renderer initialized with swapchain present loop");
  NEXUS_LOG_WARN(LogChannel::kRenderer,
                 "This is the NEXUS dev runtime (Vulkan smoke test), not the Final Evolution Lab app. "
                 "On iPhone/iPad run FinalEvolutionLab from Xcode; on Mac use the marketing sites under sites/.");
  return Result<void>::ok();
}

auto VulkanRenderer::createDevice() -> Result<void> {
  std::uint32_t deviceCount = 0;
  vkEnumeratePhysicalDevices(m_instance, &deviceCount, nullptr);
  if (deviceCount == 0) {
    return Result<void>::err("No Vulkan physical devices found");
  }

  std::vector<VkPhysicalDevice> devices(deviceCount);
  vkEnumeratePhysicalDevices(m_instance, &deviceCount, devices.data());

  for (const VkPhysicalDevice device : devices) {
    const auto families = findQueueFamilies(device, m_surface);
    if (!families.has_value()) {
      continue;
    }

    const auto deviceExtensions = requiredDeviceExtensions();
    std::uint32_t extensionCount = 0;
    vkEnumerateDeviceExtensionProperties(device, nullptr, &extensionCount, nullptr);
    std::vector<VkExtensionProperties> availableExtensions(extensionCount);
    vkEnumerateDeviceExtensionProperties(device, nullptr, &extensionCount, availableExtensions.data());

    bool allExtensionsSupported = true;
    for (const char* requiredExtension : deviceExtensions) {
      const bool found = std::any_of(availableExtensions.begin(),
                                     availableExtensions.end(),
                                     [requiredExtension](const VkExtensionProperties& properties) {
                                       return std::string(properties.extensionName) == requiredExtension;
                                     });
      if (!found) {
        allExtensionsSupported = false;
        break;
      }
    }
    if (!allExtensionsSupported) {
      continue;
    }

    m_physicalDevice = device;
    m_graphicsQueueFamily = families->first;
    m_presentQueueFamily = families->second;
    break;
  }

  if (m_physicalDevice == VK_NULL_HANDLE) {
    return Result<void>::err("No suitable Vulkan physical device found");
  }

  const float queuePriority = 1.0F;
  std::vector<VkDeviceQueueCreateInfo> queueCreateInfos;
  std::vector<std::uint32_t> uniqueFamilies;
  uniqueFamilies.push_back(m_graphicsQueueFamily);
  if (m_presentQueueFamily != m_graphicsQueueFamily) {
    uniqueFamilies.push_back(m_presentQueueFamily);
  }

  for (const std::uint32_t queueFamily : uniqueFamilies) {
    VkDeviceQueueCreateInfo queueCreateInfo{};
    queueCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    queueCreateInfo.queueFamilyIndex = queueFamily;
    queueCreateInfo.queueCount = 1;
    queueCreateInfo.pQueuePriorities = &queuePriority;
    queueCreateInfos.push_back(queueCreateInfo);
  }

  VkPhysicalDeviceFeatures deviceFeatures{};

  const auto deviceExtensions = requiredDeviceExtensions();
  VkDeviceCreateInfo deviceCreateInfo{};
  deviceCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
  deviceCreateInfo.queueCreateInfoCount = static_cast<std::uint32_t>(queueCreateInfos.size());
  deviceCreateInfo.pQueueCreateInfos = queueCreateInfos.data();
  deviceCreateInfo.pEnabledFeatures = &deviceFeatures;
  deviceCreateInfo.enabledExtensionCount = static_cast<std::uint32_t>(deviceExtensions.size());
  deviceCreateInfo.ppEnabledExtensionNames = deviceExtensions.data();

  const VkResult deviceResult =
      vkCreateDevice(m_physicalDevice, &deviceCreateInfo, nullptr, &m_device);
  if (deviceResult != VK_SUCCESS) {
    return Result<void>::err("Failed to create Vulkan device (VkResult=" +
                             std::to_string(static_cast<int>(deviceResult)) + ")");
  }

  vkGetDeviceQueue(m_device, m_graphicsQueueFamily, 0, &m_graphicsQueue);
  vkGetDeviceQueue(m_device, m_presentQueueFamily, 0, &m_presentQueue);
  return Result<void>::ok();
}

auto VulkanRenderer::createShaderModule(const std::uint8_t* code, std::size_t codeSize)
    -> Result<VkShaderModule> {
  VkShaderModuleCreateInfo createInfo{};
  createInfo.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
  createInfo.codeSize = codeSize;
  createInfo.pCode = reinterpret_cast<const std::uint32_t*>(code);

  VkShaderModule shaderModule = VK_NULL_HANDLE;
  const VkResult result = vkCreateShaderModule(m_device, &createInfo, nullptr, &shaderModule);
  if (result != VK_SUCCESS) {
    return Result<VkShaderModule>::err("Failed to create shader module");
  }
  return Result<VkShaderModule>::ok(shaderModule);
}

auto VulkanRenderer::createRenderPass() -> Result<void> {
  VkAttachmentDescription colorAttachment{};
  colorAttachment.format = m_swapchainImageFormat;
  colorAttachment.samples = VK_SAMPLE_COUNT_1_BIT;
  colorAttachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
  colorAttachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
  colorAttachment.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
  colorAttachment.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
  colorAttachment.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
  colorAttachment.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

  VkAttachmentReference colorAttachmentRef{};
  colorAttachmentRef.attachment = 0;
  colorAttachmentRef.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

  VkSubpassDescription subpass{};
  subpass.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
  subpass.colorAttachmentCount = 1;
  subpass.pColorAttachments = &colorAttachmentRef;

  VkSubpassDependency dependency{};
  dependency.srcSubpass = VK_SUBPASS_EXTERNAL;
  dependency.dstSubpass = 0;
  dependency.srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
  dependency.srcAccessMask = 0;
  dependency.dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
  dependency.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;

  VkRenderPassCreateInfo renderPassInfo{};
  renderPassInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
  renderPassInfo.attachmentCount = 1;
  renderPassInfo.pAttachments = &colorAttachment;
  renderPassInfo.subpassCount = 1;
  renderPassInfo.pSubpasses = &subpass;
  renderPassInfo.dependencyCount = 1;
  renderPassInfo.pDependencies = &dependency;

  const VkResult renderPassResult =
      vkCreateRenderPass(m_device, &renderPassInfo, nullptr, &m_renderPass);
  if (renderPassResult != VK_SUCCESS) {
    return Result<void>::err("Failed to create render pass");
  }
  return Result<void>::ok();
}

auto VulkanRenderer::createPipelineResources() -> Result<void> {
  const auto vertModuleResult =
      createShaderModule(kTriangleVertSpv, kTriangleVertSpv_size);
  if (vertModuleResult.isErr()) {
    return Result<void>::err(vertModuleResult.error());
  }
  const auto fragModuleResult =
      createShaderModule(kTriangleFragSpv, kTriangleFragSpv_size);
  if (fragModuleResult.isErr()) {
    vkDestroyShaderModule(m_device, vertModuleResult.value(), nullptr);
    return Result<void>::err(fragModuleResult.error());
  }

  const VkShaderModule vertModule = vertModuleResult.value();
  const VkShaderModule fragModule = fragModuleResult.value();

  VkPipelineShaderStageCreateInfo shaderStages[2]{};
  shaderStages[0].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
  shaderStages[0].stage = VK_SHADER_STAGE_VERTEX_BIT;
  shaderStages[0].module = vertModule;
  shaderStages[0].pName = "main";
  shaderStages[1].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
  shaderStages[1].stage = VK_SHADER_STAGE_FRAGMENT_BIT;
  shaderStages[1].module = fragModule;
  shaderStages[1].pName = "main";

  VkVertexInputBindingDescription bindingDescription{};
  bindingDescription.binding = 0;
  bindingDescription.stride = sizeof(TriangleVertex);
  bindingDescription.inputRate = VK_VERTEX_INPUT_RATE_VERTEX;

  std::array<VkVertexInputAttributeDescription, 2> attributeDescriptions{};
  attributeDescriptions[0].binding = 0;
  attributeDescriptions[0].location = 0;
  attributeDescriptions[0].format = VK_FORMAT_R32G32_SFLOAT;
  attributeDescriptions[0].offset = offsetof(TriangleVertex, position);
  attributeDescriptions[1].binding = 0;
  attributeDescriptions[1].location = 1;
  attributeDescriptions[1].format = VK_FORMAT_R32G32B32_SFLOAT;
  attributeDescriptions[1].offset = offsetof(TriangleVertex, color);

  VkPipelineVertexInputStateCreateInfo vertexInputInfo{};
  vertexInputInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
  vertexInputInfo.vertexBindingDescriptionCount = 1;
  vertexInputInfo.pVertexBindingDescriptions = &bindingDescription;
  vertexInputInfo.vertexAttributeDescriptionCount =
      static_cast<std::uint32_t>(attributeDescriptions.size());
  vertexInputInfo.pVertexAttributeDescriptions = attributeDescriptions.data();

  VkPipelineInputAssemblyStateCreateInfo inputAssembly{};
  inputAssembly.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
  inputAssembly.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
  inputAssembly.primitiveRestartEnable = VK_FALSE;

  VkPipelineViewportStateCreateInfo viewportState{};
  viewportState.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
  viewportState.viewportCount = 1;
  viewportState.scissorCount = 1;

  VkPipelineRasterizationStateCreateInfo rasterizer{};
  rasterizer.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
  rasterizer.depthClampEnable = VK_FALSE;
  rasterizer.rasterizerDiscardEnable = VK_FALSE;
  rasterizer.polygonMode = VK_POLYGON_MODE_FILL;
  rasterizer.lineWidth = 1.0F;
  rasterizer.cullMode = VK_CULL_MODE_NONE;
  rasterizer.frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE;
  rasterizer.depthBiasEnable = VK_FALSE;

  VkPipelineMultisampleStateCreateInfo multisampling{};
  multisampling.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
  multisampling.sampleShadingEnable = VK_FALSE;
  multisampling.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;

  VkPipelineColorBlendAttachmentState colorBlendAttachment{};
  colorBlendAttachment.colorWriteMask =
      VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT | VK_COLOR_COMPONENT_B_BIT |
      VK_COLOR_COMPONENT_A_BIT;
  colorBlendAttachment.blendEnable = VK_FALSE;

  VkPipelineColorBlendStateCreateInfo colorBlending{};
  colorBlending.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
  colorBlending.logicOpEnable = VK_FALSE;
  colorBlending.attachmentCount = 1;
  colorBlending.pAttachments = &colorBlendAttachment;

  std::array dynamicStates{VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR};
  VkPipelineDynamicStateCreateInfo dynamicState{};
  dynamicState.sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
  dynamicState.dynamicStateCount = static_cast<std::uint32_t>(dynamicStates.size());
  dynamicState.pDynamicStates = dynamicStates.data();

  VkPipelineLayoutCreateInfo pipelineLayoutInfo{};
  pipelineLayoutInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;

  const VkResult layoutResult =
      vkCreatePipelineLayout(m_device, &pipelineLayoutInfo, nullptr, &m_pipelineLayout);
  if (layoutResult != VK_SUCCESS) {
    vkDestroyShaderModule(m_device, fragModule, nullptr);
    vkDestroyShaderModule(m_device, vertModule, nullptr);
    return Result<void>::err("Failed to create pipeline layout");
  }

  VkGraphicsPipelineCreateInfo pipelineInfo{};
  pipelineInfo.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
  pipelineInfo.stageCount = 2;
  pipelineInfo.pStages = shaderStages;
  pipelineInfo.pVertexInputState = &vertexInputInfo;
  pipelineInfo.pInputAssemblyState = &inputAssembly;
  pipelineInfo.pViewportState = &viewportState;
  pipelineInfo.pRasterizationState = &rasterizer;
  pipelineInfo.pMultisampleState = &multisampling;
  pipelineInfo.pColorBlendState = &colorBlending;
  pipelineInfo.pDynamicState = &dynamicState;
  pipelineInfo.layout = m_pipelineLayout;
  pipelineInfo.renderPass = m_renderPass;
  pipelineInfo.subpass = 0;

  const VkResult pipelineResult =
      vkCreateGraphicsPipelines(m_device, VK_NULL_HANDLE, 1, &pipelineInfo, nullptr, &m_pipeline);
  vkDestroyShaderModule(m_device, fragModule, nullptr);
  vkDestroyShaderModule(m_device, vertModule, nullptr);
  if (pipelineResult != VK_SUCCESS) {
    return Result<void>::err("Failed to create graphics pipeline");
  }

  VkBufferCreateInfo bufferInfo{};
  bufferInfo.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
  bufferInfo.size = sizeof(kTriangleVertices);
  bufferInfo.usage = VK_BUFFER_USAGE_VERTEX_BUFFER_BIT;
  bufferInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;

  const VkResult bufferResult = vkCreateBuffer(m_device, &bufferInfo, nullptr, &m_vertexBuffer);
  if (bufferResult != VK_SUCCESS) {
    return Result<void>::err("Failed to create vertex buffer");
  }

  VkMemoryRequirements memoryRequirements{};
  vkGetBufferMemoryRequirements(m_device, m_vertexBuffer, &memoryRequirements);

  VkMemoryAllocateInfo allocInfo{};
  allocInfo.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
  allocInfo.allocationSize = memoryRequirements.size;
  allocInfo.memoryTypeIndex =
      findMemoryType(m_physicalDevice,
                     memoryRequirements.memoryTypeBits,
                     VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
  if (allocInfo.memoryTypeIndex == std::numeric_limits<std::uint32_t>::max()) {
    return Result<void>::err("Failed to find suitable memory type for vertex buffer");
  }

  const VkResult memoryResult =
      vkAllocateMemory(m_device, &allocInfo, nullptr, &m_vertexBufferMemory);
  if (memoryResult != VK_SUCCESS) {
    return Result<void>::err("Failed to allocate vertex buffer memory");
  }

  vkBindBufferMemory(m_device, m_vertexBuffer, m_vertexBufferMemory, 0);

  void* mappedData = nullptr;
  vkMapMemory(m_device, m_vertexBufferMemory, 0, bufferInfo.size, 0, &mappedData);
  std::memcpy(mappedData, kTriangleVertices.data(), sizeof(kTriangleVertices));
  vkUnmapMemory(m_device, m_vertexBufferMemory);

  return Result<void>::ok();
}

auto VulkanRenderer::createSwapchainResources() -> Result<void> {
  VkSurfaceCapabilitiesKHR capabilities{};
  vkGetPhysicalDeviceSurfaceCapabilitiesKHR(m_physicalDevice, m_surface, &capabilities);

  std::uint32_t formatCount = 0;
  vkGetPhysicalDeviceSurfaceFormatsKHR(m_physicalDevice, m_surface, &formatCount, nullptr);
  if (formatCount == 0) {
    return Result<void>::err("No Vulkan surface formats available");
  }
  std::vector<VkSurfaceFormatKHR> formats(formatCount);
  vkGetPhysicalDeviceSurfaceFormatsKHR(m_physicalDevice, m_surface, &formatCount, formats.data());

  std::uint32_t presentModeCount = 0;
  vkGetPhysicalDeviceSurfacePresentModesKHR(m_physicalDevice, m_surface, &presentModeCount, nullptr);
  std::vector<VkPresentModeKHR> presentModes(presentModeCount);
  vkGetPhysicalDeviceSurfacePresentModesKHR(
      m_physicalDevice, m_surface, &presentModeCount, presentModes.data());

  const VkSurfaceFormatKHR surfaceFormat = chooseSwapSurfaceFormat(formats);
  const VkPresentModeKHR presentMode = chooseSwapPresentMode(presentModes);
  int width = 0;
  int height = 0;
  SDL_GetWindowSizeInPixels(m_window, &width, &height);
  m_swapchainExtent = chooseSwapExtent(capabilities,
                                       static_cast<std::uint32_t>(width),
                                       static_cast<std::uint32_t>(height));

  std::uint32_t imageCount = capabilities.minImageCount + 1;
  if (capabilities.maxImageCount > 0 && imageCount > capabilities.maxImageCount) {
    imageCount = capabilities.maxImageCount;
  }

  VkSwapchainKHR oldSwapchain = m_swapchain;

  VkSwapchainCreateInfoKHR swapchainCreateInfo{};
  swapchainCreateInfo.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
  swapchainCreateInfo.surface = m_surface;
  swapchainCreateInfo.minImageCount = imageCount;
  swapchainCreateInfo.imageFormat = surfaceFormat.format;
  swapchainCreateInfo.imageColorSpace = surfaceFormat.colorSpace;
  swapchainCreateInfo.imageExtent = m_swapchainExtent;
  swapchainCreateInfo.imageArrayLayers = 1;
  swapchainCreateInfo.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

  const std::array queueFamilyIndices{m_graphicsQueueFamily, m_presentQueueFamily};
  if (m_graphicsQueueFamily != m_presentQueueFamily) {
    swapchainCreateInfo.imageSharingMode = VK_SHARING_MODE_CONCURRENT;
    swapchainCreateInfo.queueFamilyIndexCount = static_cast<std::uint32_t>(queueFamilyIndices.size());
    swapchainCreateInfo.pQueueFamilyIndices = queueFamilyIndices.data();
  } else {
    swapchainCreateInfo.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
  }

  swapchainCreateInfo.preTransform = capabilities.currentTransform;
  swapchainCreateInfo.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
  swapchainCreateInfo.presentMode = presentMode;
  swapchainCreateInfo.clipped = VK_TRUE;
  swapchainCreateInfo.oldSwapchain = oldSwapchain;

  const VkResult swapchainResult =
      vkCreateSwapchainKHR(m_device, &swapchainCreateInfo, nullptr, &m_swapchain);
  if (swapchainResult != VK_SUCCESS) {
    return Result<void>::err("Failed to create swapchain (VkResult=" +
                             std::to_string(static_cast<int>(swapchainResult)) + ")");
  }

  if (oldSwapchain != VK_NULL_HANDLE) {
    vkDestroySwapchainKHR(m_device, oldSwapchain, nullptr);
  }

  m_swapchainImageFormat = surfaceFormat.format;

  std::uint32_t swapchainImageCount = 0;
  vkGetSwapchainImagesKHR(m_device, m_swapchain, &swapchainImageCount, nullptr);
  m_swapchainImages.resize(swapchainImageCount);
  vkGetSwapchainImagesKHR(m_device, m_swapchain, &swapchainImageCount, m_swapchainImages.data());

  m_swapchainImageViews.resize(m_swapchainImages.size());
  for (std::size_t index = 0; index < m_swapchainImages.size(); ++index) {
    VkImageViewCreateInfo viewCreateInfo{};
    viewCreateInfo.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
    viewCreateInfo.image = m_swapchainImages[index];
    viewCreateInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;
    viewCreateInfo.format = m_swapchainImageFormat;
    viewCreateInfo.components.r = VK_COMPONENT_SWIZZLE_IDENTITY;
    viewCreateInfo.components.g = VK_COMPONENT_SWIZZLE_IDENTITY;
    viewCreateInfo.components.b = VK_COMPONENT_SWIZZLE_IDENTITY;
    viewCreateInfo.components.a = VK_COMPONENT_SWIZZLE_IDENTITY;
    viewCreateInfo.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    viewCreateInfo.subresourceRange.baseMipLevel = 0;
    viewCreateInfo.subresourceRange.levelCount = 1;
    viewCreateInfo.subresourceRange.baseArrayLayer = 0;
    viewCreateInfo.subresourceRange.layerCount = 1;

    const VkResult viewResult =
        vkCreateImageView(m_device, &viewCreateInfo, nullptr, &m_swapchainImageViews[index]);
    if (viewResult != VK_SUCCESS) {
      return Result<void>::err("Failed to create swapchain image view");
    }
  }

  m_swapchainFramebuffers.resize(m_swapchainImageViews.size());
  for (std::size_t index = 0; index < m_swapchainImageViews.size(); ++index) {
    VkImageView attachments[] = {m_swapchainImageViews[index]};

    VkFramebufferCreateInfo framebufferInfo{};
    framebufferInfo.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
    framebufferInfo.renderPass = m_renderPass;
    framebufferInfo.attachmentCount = 1;
    framebufferInfo.pAttachments = attachments;
    framebufferInfo.width = m_swapchainExtent.width;
    framebufferInfo.height = m_swapchainExtent.height;
    framebufferInfo.layers = 1;

    const VkResult framebufferResult =
        vkCreateFramebuffer(m_device, &framebufferInfo, nullptr, &m_swapchainFramebuffers[index]);
    if (framebufferResult != VK_SUCCESS) {
      return Result<void>::err("Failed to create framebuffer");
    }
  }

  if (m_commandPool == VK_NULL_HANDLE) {
    VkCommandPoolCreateInfo poolInfo{};
    poolInfo.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    poolInfo.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
    poolInfo.queueFamilyIndex = m_graphicsQueueFamily;

    const VkResult poolResult = vkCreateCommandPool(m_device, &poolInfo, nullptr, &m_commandPool);
    if (poolResult != VK_SUCCESS) {
      return Result<void>::err("Failed to create command pool");
    }
  } else {
    vkResetCommandPool(m_device, m_commandPool, 0);
  }

  m_commandBuffers.resize(m_swapchainFramebuffers.size());
  VkCommandBufferAllocateInfo allocInfo{};
  allocInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
  allocInfo.commandPool = m_commandPool;
  allocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
  allocInfo.commandBufferCount = static_cast<std::uint32_t>(m_commandBuffers.size());

  const VkResult allocResult = vkAllocateCommandBuffers(m_device, &allocInfo, m_commandBuffers.data());
  if (allocResult != VK_SUCCESS) {
    return Result<void>::err("Failed to allocate command buffers");
  }

  if (m_imageAvailableSemaphore == VK_NULL_HANDLE) {
    VkSemaphoreCreateInfo semaphoreInfo{};
    semaphoreInfo.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;

    VkFenceCreateInfo fenceInfo{};
    fenceInfo.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
    fenceInfo.flags = VK_FENCE_CREATE_SIGNALED_BIT;

    if (vkCreateSemaphore(m_device, &semaphoreInfo, nullptr, &m_imageAvailableSemaphore) !=
            VK_SUCCESS ||
        vkCreateSemaphore(m_device, &semaphoreInfo, nullptr, &m_renderFinishedSemaphore) !=
            VK_SUCCESS ||
        vkCreateFence(m_device, &fenceInfo, nullptr, &m_inFlightFence) != VK_SUCCESS) {
      return Result<void>::err("Failed to create synchronization objects");
    }
  }

  m_swapchainReady = true;
  return Result<void>::ok();
}

void VulkanRenderer::recreateSwapchain() {
  if (m_device == VK_NULL_HANDLE || m_window == nullptr) {
    return;
  }

  int width = 0;
  int height = 0;
  SDL_GetWindowSizeInPixels(m_window, &width, &height);
  while (width == 0 || height == 0) {
    SDL_Event event{};
    SDL_WaitEvent(&event);
    pollInput();
    SDL_GetWindowSizeInPixels(m_window, &width, &height);
  }

  vkDeviceWaitIdle(m_device);

  for (VkFramebuffer framebuffer : m_swapchainFramebuffers) {
    vkDestroyFramebuffer(m_device, framebuffer, nullptr);
  }
  m_swapchainFramebuffers.clear();

  for (VkImageView imageView : m_swapchainImageViews) {
    vkDestroyImageView(m_device, imageView, nullptr);
  }
  m_swapchainImageViews.clear();
  m_swapchainImages.clear();

  if (!m_commandBuffers.empty()) {
    vkFreeCommandBuffers(m_device,
                         m_commandPool,
                         static_cast<std::uint32_t>(m_commandBuffers.size()),
                         m_commandBuffers.data());
    m_commandBuffers.clear();
  }

  m_swapchainReady = false;

  const auto result = createSwapchainResources();
  if (result.isErr()) {
    NEXUS_LOG_ERROR(LogChannel::kRenderer, "Swapchain recreate failed: " + result.error());
    m_shouldClose = true;
    return;
  }

  m_framebufferResized = false;
  NEXUS_LOG_INFO(LogChannel::kRenderer, "Swapchain recreated");
}

void VulkanRenderer::destroyPipelineResources() {
  if (m_device == VK_NULL_HANDLE) {
    return;
  }

  if (m_vertexBuffer != VK_NULL_HANDLE) {
    vkDestroyBuffer(m_device, m_vertexBuffer, nullptr);
    m_vertexBuffer = VK_NULL_HANDLE;
  }
  if (m_vertexBufferMemory != VK_NULL_HANDLE) {
    vkFreeMemory(m_device, m_vertexBufferMemory, nullptr);
    m_vertexBufferMemory = VK_NULL_HANDLE;
  }
  if (m_pipeline != VK_NULL_HANDLE) {
    vkDestroyPipeline(m_device, m_pipeline, nullptr);
    m_pipeline = VK_NULL_HANDLE;
  }
  if (m_pipelineLayout != VK_NULL_HANDLE) {
    vkDestroyPipelineLayout(m_device, m_pipelineLayout, nullptr);
    m_pipelineLayout = VK_NULL_HANDLE;
  }
  if (m_renderPass != VK_NULL_HANDLE) {
    vkDestroyRenderPass(m_device, m_renderPass, nullptr);
    m_renderPass = VK_NULL_HANDLE;
  }
}

void VulkanRenderer::destroySwapchainResources() {
  if (m_device == VK_NULL_HANDLE) {
    return;
  }

  if (m_inFlightFence != VK_NULL_HANDLE) {
    vkWaitForFences(m_device, 1, &m_inFlightFence, VK_TRUE, UINT64_MAX);
  }

  for (VkFramebuffer framebuffer : m_swapchainFramebuffers) {
    vkDestroyFramebuffer(m_device, framebuffer, nullptr);
  }
  m_swapchainFramebuffers.clear();

  if (!m_commandBuffers.empty()) {
    vkFreeCommandBuffers(m_device,
                         m_commandPool,
                         static_cast<std::uint32_t>(m_commandBuffers.size()),
                         m_commandBuffers.data());
    m_commandBuffers.clear();
  }

  if (m_commandPool != VK_NULL_HANDLE) {
    vkDestroyCommandPool(m_device, m_commandPool, nullptr);
    m_commandPool = VK_NULL_HANDLE;
  }

  for (VkImageView imageView : m_swapchainImageViews) {
    vkDestroyImageView(m_device, imageView, nullptr);
  }
  m_swapchainImageViews.clear();
  m_swapchainImages.clear();

  if (m_swapchain != VK_NULL_HANDLE) {
    vkDestroySwapchainKHR(m_device, m_swapchain, nullptr);
    m_swapchain = VK_NULL_HANDLE;
  }

  if (m_imageAvailableSemaphore != VK_NULL_HANDLE) {
    vkDestroySemaphore(m_device, m_imageAvailableSemaphore, nullptr);
    m_imageAvailableSemaphore = VK_NULL_HANDLE;
  }
  if (m_renderFinishedSemaphore != VK_NULL_HANDLE) {
    vkDestroySemaphore(m_device, m_renderFinishedSemaphore, nullptr);
    m_renderFinishedSemaphore = VK_NULL_HANDLE;
  }
  if (m_inFlightFence != VK_NULL_HANDLE) {
    vkDestroyFence(m_device, m_inFlightFence, nullptr);
    m_inFlightFence = VK_NULL_HANDLE;
  }

  m_swapchainReady = false;
}

void VulkanRenderer::destroyDevice() {
  if (m_device != VK_NULL_HANDLE) {
    vkDeviceWaitIdle(m_device);
  }

  destroySwapchainResources();
  destroyPipelineResources();

  if (m_device != VK_NULL_HANDLE) {
    vkDestroyDevice(m_device, nullptr);
    m_device = VK_NULL_HANDLE;
  }

  if (m_surface != VK_NULL_HANDLE && m_instance != VK_NULL_HANDLE) {
    vkDestroySurfaceKHR(m_instance, m_surface, nullptr);
    m_surface = VK_NULL_HANDLE;
  }

  m_physicalDevice = VK_NULL_HANDLE;
  m_graphicsQueue = VK_NULL_HANDLE;
  m_presentQueue = VK_NULL_HANDLE;
}

void VulkanRenderer::pollInput() {
  SDL_Event event{};
  while (SDL_PollEvent(&event)) {
    if (event.type == SDL_EVENT_QUIT) {
      m_shouldClose = true;
    } else if (event.type == SDL_EVENT_WINDOW_RESIZED ||
               event.type == SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED) {
      m_framebufferResized = true;
    }
  }
}

void VulkanRenderer::renderFrame() {
  if (!m_swapchainReady || m_device == VK_NULL_HANDLE) {
    return;
  }

  if (m_framebufferResized) {
    recreateSwapchain();
    if (!m_swapchainReady) {
      return;
    }
  }

  vkWaitForFences(m_device, 1, &m_inFlightFence, VK_TRUE, UINT64_MAX);

  VkResult acquireResult = vkAcquireNextImageKHR(m_device,
                                                 m_swapchain,
                                                 UINT64_MAX,
                                                 m_imageAvailableSemaphore,
                                                 VK_NULL_HANDLE,
                                                 &m_currentImageIndex);
  if (acquireResult == VK_ERROR_OUT_OF_DATE_KHR) {
    recreateSwapchain();
    return;
  }
  if (acquireResult != VK_SUCCESS && acquireResult != VK_SUBOPTIMAL_KHR) {
    NEXUS_LOG_WARN(LogChannel::kRenderer, "Failed to acquire swapchain image");
    return;
  }

  vkResetFences(m_device, 1, &m_inFlightFence);

  VkCommandBuffer commandBuffer = m_commandBuffers[m_currentImageIndex];
  vkResetCommandBuffer(commandBuffer, 0);

  VkCommandBufferBeginInfo beginInfo{};
  beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;

  if (vkBeginCommandBuffer(commandBuffer, &beginInfo) != VK_SUCCESS) {
    NEXUS_LOG_WARN(LogChannel::kRenderer, "Failed to begin command buffer");
    return;
  }

  VkClearValue clearColor{};
  clearColor.color = {{0.05F, 0.08F, 0.14F, 1.0F}};

  VkRenderPassBeginInfo renderPassInfo{};
  renderPassInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
  renderPassInfo.renderPass = m_renderPass;
  renderPassInfo.framebuffer = m_swapchainFramebuffers[m_currentImageIndex];
  renderPassInfo.renderArea.offset = {0, 0};
  renderPassInfo.renderArea.extent = m_swapchainExtent;
  renderPassInfo.clearValueCount = 1;
  renderPassInfo.pClearValues = &clearColor;

  vkCmdBeginRenderPass(commandBuffer, &renderPassInfo, VK_SUBPASS_CONTENTS_INLINE);

  VkViewport viewport{};
  viewport.x = 0.0F;
  viewport.y = 0.0F;
  viewport.width = static_cast<float>(m_swapchainExtent.width);
  viewport.height = static_cast<float>(m_swapchainExtent.height);
  viewport.minDepth = 0.0F;
  viewport.maxDepth = 1.0F;
  vkCmdSetViewport(commandBuffer, 0, 1, &viewport);

  VkRect2D scissor{};
  scissor.offset = {0, 0};
  scissor.extent = m_swapchainExtent;
  vkCmdSetScissor(commandBuffer, 0, 1, &scissor);

  vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, m_pipeline);

  VkBuffer vertexBuffers[] = {m_vertexBuffer};
  VkDeviceSize offsets[] = {0};
  vkCmdBindVertexBuffers(commandBuffer, 0, 1, vertexBuffers, offsets);
  vkCmdDraw(commandBuffer, static_cast<std::uint32_t>(kTriangleVertices.size()), 1, 0, 0);

  vkCmdEndRenderPass(commandBuffer);

  if (vkEndCommandBuffer(commandBuffer) != VK_SUCCESS) {
    NEXUS_LOG_WARN(LogChannel::kRenderer, "Failed to record command buffer");
    return;
  }

  VkPipelineStageFlags waitStages[] = {VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};
  VkSubmitInfo submitInfo{};
  submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
  submitInfo.waitSemaphoreCount = 1;
  submitInfo.pWaitSemaphores = &m_imageAvailableSemaphore;
  submitInfo.pWaitDstStageMask = waitStages;
  submitInfo.commandBufferCount = 1;
  submitInfo.pCommandBuffers = &commandBuffer;
  submitInfo.signalSemaphoreCount = 1;
  submitInfo.pSignalSemaphores = &m_renderFinishedSemaphore;

  if (vkQueueSubmit(m_graphicsQueue, 1, &submitInfo, m_inFlightFence) != VK_SUCCESS) {
    NEXUS_LOG_WARN(LogChannel::kRenderer, "Failed to submit draw command buffer");
    return;
  }

  VkPresentInfoKHR presentInfo{};
  presentInfo.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
  presentInfo.waitSemaphoreCount = 1;
  presentInfo.pWaitSemaphores = &m_renderFinishedSemaphore;
  presentInfo.swapchainCount = 1;
  presentInfo.pSwapchains = &m_swapchain;
  presentInfo.pImageIndices = &m_currentImageIndex;

  const VkResult presentResult = vkQueuePresentKHR(m_presentQueue, &presentInfo);
  if (presentResult == VK_ERROR_OUT_OF_DATE_KHR || presentResult == VK_SUBOPTIMAL_KHR) {
    m_framebufferResized = true;
    return;
  }
  if (presentResult != VK_SUCCESS) {
    NEXUS_LOG_WARN(LogChannel::kRenderer, "Failed to present swapchain image");
  }
}

auto VulkanRenderer::shouldClose() const -> bool {
  return m_shouldClose;
}

void VulkanRenderer::shutdown() {
  destroyDevice();

  if (m_instance != VK_NULL_HANDLE) {
    vkDestroyInstance(m_instance, nullptr);
    m_instance = VK_NULL_HANDLE;
  }

  if (m_window != nullptr) {
    SDL_DestroyWindow(m_window);
    m_window = nullptr;
  }

#if defined(__APPLE__)
  SDL_Vulkan_UnloadLibrary();
#endif
  SDL_Quit();
  NEXUS_LOG_INFO(LogChannel::kRenderer, "Vulkan renderer shutdown");
}

} // namespace nexus::renderer
