#include "nexus/renderer/metal_renderer.h"

#include "nexus/core/log.h"
#include "nexus/core/engine_scale_policy.h"
#include "nexus/renderer/console_tier_lod.h"
#include "nexus/renderer/scene.h"

#include <cmath>

#if defined(__APPLE__)
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#endif

namespace nexus::renderer {

namespace {

#if defined(__APPLE__)
void releaseMetalObject(void*& handle) {
  if (handle == nullptr) {
    return;
  }
  (void)(__bridge_transfer id)handle;
  handle = nullptr;
}

struct MetalVertex {
  float position[3];
  float color[3];
};

auto makePerspectiveMvp(float aspect, float orbitDistance) -> std::array<float, 16> {
  const float fov = 60.0F * 3.14159265F / 180.0F;
  const float f = 1.0F / std::tan(fov * 0.5F);
  const float nearZ = 0.1F;
  const float farZ = 500.0F;
  const float range = nearZ - farZ;

  std::array<float, 16> projection{};
  projection[0] = f / aspect;
  projection[5] = f;
  projection[10] = (farZ + nearZ) / range;
  projection[11] = -1.0F;
  projection[14] = (2.0F * farZ * nearZ) / range;

  const float eyeY = orbitDistance * 0.35F;
  const float eyeZ = orbitDistance;
  std::array<float, 16> view{};
  view[0] = 1.0F;
  view[5] = 1.0F;
  view[10] = 1.0F;
  view[15] = 1.0F;
  view[13] = -eyeY;
  view[14] = -eyeZ;

  std::array<float, 16> mvp{};
  for (int row = 0; row < 4; ++row) {
    for (int col = 0; col < 4; ++col) {
      float sum = 0.0F;
      for (int k = 0; k < 4; ++k) {
        sum += projection[row + k * 4] * view[k + col * 4];
      }
      mvp[row + col * 4] = sum;
    }
  }
  return mvp;
}
#endif

} // namespace

auto MetalRenderer::initialize(CAMetalLayer* layer, const MetalRendererConfig& config)
    -> Result<void> {
  m_config = config;
  m_manifestPath = config.manifestPath;
  m_modeId = config.modeId;
  if (layer == nullptr) {
    m_lastError = "CAMetalLayer is null";
    return Result<void>::err(m_lastError);
  }

#if defined(__APPLE__)
  id<MTLDevice> device = MTLCreateSystemDefaultDevice();
  if (device == nil) {
    m_lastError = "MTLCreateSystemDefaultDevice failed";
    NEXUS_LOG_ERROR(nexus::LogChannel::kRenderer, m_lastError);
    return Result<void>::err(m_lastError);
  }

  layer.device = device;
  layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
  layer.framebufferOnly = YES;
  if (config.width > 0 && config.height > 0) {
    layer.drawableSize = CGSizeMake(config.width, config.height);
  }

  m_layer = layer;
  m_device = (__bridge_retained void*)device;
  m_commandQueue = (__bridge_retained void*)[device newCommandQueue];
  m_initialized = true;

  const auto pipelineResult = ensurePipeline();
  if (pipelineResult.isErr()) {
    shutdown();
    return pipelineResult;
  }

  NEXUS_LOG_INFO(nexus::LogChannel::kRenderer,
                 "MetalRenderer initialized (validate-only wireframe draw path)");
  return Result<void>::ok();
#else
  (void)layer;
  m_lastError = "MetalRenderer only available on Apple platforms";
  return Result<void>::err(m_lastError);
#endif
}

auto MetalRenderer::loadVenueFromManifest(std::string_view modeId) -> Result<void> {
  if (!m_initialized) {
    m_lastError = "MetalRenderer not initialized";
    return Result<void>::err(m_lastError);
  }
  m_modeId = std::string(modeId);
  const RenderScene scene = RenderScene::createFromManifest(m_manifestPath, modeId);
  releaseGpuMeshes();
  const auto uploadResult = uploadSceneMeshes(scene);
  if (uploadResult.isErr()) {
    return uploadResult;
  }
  NEXUS_LOG_INFO(nexus::LogChannel::kRenderer,
                 "MetalRenderer loaded venue mode=" + m_modeId + " meshes=" +
                     std::to_string(m_uploadedMeshCount));
  return Result<void>::ok();
}

auto MetalRenderer::ensurePipeline() -> Result<void> {
#if defined(__APPLE__)
  id<MTLDevice> device = (__bridge id)m_device;
  if (device == nil) {
    return Result<void>::err("Metal device missing for pipeline creation");
  }

  NSString* shaderSource = @R"(
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
  float3 position [[attribute(0)]];
  float3 color [[attribute(1)]];
};

struct VertexOut {
  float4 position [[position]];
  float3 color;
};

vertex VertexOut nexus_vertex(VertexIn in [[stage_in]], constant float4x4& mvp [[buffer(1)]]) {
  VertexOut out;
  out.position = mvp * float4(in.position, 1.0);
  out.color = in.color;
  return out;
}

fragment float4 nexus_fragment(VertexOut in [[stage_in]]) {
  return float4(in.color, 1.0);
}
)";

  NSError* error = nil;
  id<MTLLibrary> library = [device newLibraryWithSource:shaderSource options:nil error:&error];
  if (library == nil) {
    m_lastError = "Metal shader compile failed";
    return Result<void>::err(m_lastError);
  }

  id<MTLFunction> vertexFn = [library newFunctionWithName:@"nexus_vertex"];
  id<MTLFunction> fragmentFn = [library newFunctionWithName:@"nexus_fragment"];
  MTLRenderPipelineDescriptor* pipelineDesc = [[MTLRenderPipelineDescriptor alloc] init];
  pipelineDesc.vertexFunction = vertexFn;
  pipelineDesc.fragmentFunction = fragmentFn;
  pipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

  MTLVertexDescriptor* vertexDesc = [[MTLVertexDescriptor alloc] init];
  vertexDesc.attributes[0].format = MTLVertexFormatFloat3;
  vertexDesc.attributes[0].offset = 0;
  vertexDesc.attributes[0].bufferIndex = 0;
  vertexDesc.attributes[1].format = MTLVertexFormatFloat3;
  vertexDesc.attributes[1].offset = sizeof(float) * 3;
  vertexDesc.attributes[1].bufferIndex = 0;
  vertexDesc.layouts[0].stride = sizeof(MetalVertex);
  pipelineDesc.vertexDescriptor = vertexDesc;

  id<MTLRenderPipelineState> pipeline =
      [device newRenderPipelineStateWithDescriptor:pipelineDesc error:&error];
  if (pipeline == nil) {
    m_lastError = "Metal pipeline creation failed";
    return Result<void>::err(m_lastError);
  }

  MTLDepthStencilDescriptor* depthDesc = [[MTLDepthStencilDescriptor alloc] init];
  depthDesc.depthCompareFunction = MTLCompareFunctionLess;
  depthDesc.depthWriteEnabled = YES;
  id<MTLDepthStencilState> depthState = [device newDepthStencilStateWithDescriptor:depthDesc];

  m_pipelineState = (__bridge_retained void*)pipeline;
  m_depthStencilState = (__bridge_retained void*)depthState;
  m_pipelineReady = true;
  return Result<void>::ok();
#else
  return Result<void>::err("Metal pipeline unavailable on this platform");
#endif
}

auto MetalRenderer::uploadSceneMeshes(const RenderScene& scene) -> Result<void> {
#if defined(__APPLE__)
  id<MTLDevice> device = (__bridge id)m_device;
  if (device == nil) {
    return Result<void>::err("Metal device missing for mesh upload");
  }

  m_gpuMeshes.clear();
  m_gpuMeshes.resize(scene.meshCount());
  m_uploadedMeshCount = 0;

  for (std::size_t meshIndex = 0; meshIndex < scene.meshCount(); ++meshIndex) {
    const Mesh& mesh = scene.mesh(meshIndex);
    if (mesh.vertices.empty() || mesh.indices.empty()) {
      continue;
    }

    std::vector<MetalVertex> interleaved;
    interleaved.reserve(mesh.vertices.size());
    for (const MeshVertex& vertex : mesh.vertices) {
      interleaved.push_back(
          MetalVertex{{vertex.position[0], vertex.position[1], vertex.position[2]},
                      {vertex.color[0], vertex.color[1], vertex.color[2]}});
    }

    const std::size_t vertexBytes = interleaved.size() * sizeof(MetalVertex);
    id<MTLBuffer> vertexBuffer =
        [device newBufferWithBytes:interleaved.data() length:vertexBytes options:MTLResourceStorageModeShared];
    id<MTLBuffer> indexBuffer = [device newBufferWithBytes:mesh.indices.data()
                                                      length:mesh.indices.size() * sizeof(std::uint32_t)
                                                     options:MTLResourceStorageModeShared];
    if (vertexBuffer == nil || indexBuffer == nil) {
      return Result<void>::err("Metal mesh buffer allocation failed");
    }

    GpuMesh& gpuMesh = m_gpuMeshes[meshIndex];
    gpuMesh.vertexBuffer = (__bridge_retained void*)vertexBuffer;
    gpuMesh.indexBuffer = (__bridge_retained void*)indexBuffer;
    gpuMesh.indexCount = static_cast<std::uint32_t>(mesh.indices.size());
    ++m_uploadedMeshCount;
  }

  return Result<void>::ok();
#else
  (void)scene;
  return Result<void>::err("Metal mesh upload unavailable on this platform");
#endif
}

void MetalRenderer::releaseGpuMeshes() {
#if defined(__APPLE__)
  for (GpuMesh& mesh : m_gpuMeshes) {
    releaseMetalObject(mesh.vertexBuffer);
    releaseMetalObject(mesh.indexBuffer);
  }
#endif
  m_gpuMeshes.clear();
  m_uploadedMeshCount = 0;
}

auto MetalRenderer::render(const RenderScene& scene) -> Result<void> {
  if (!m_initialized) {
    m_lastError = "MetalRenderer not initialized";
    return Result<void>::err(m_lastError);
  }

#if defined(__APPLE__)
  if (CAMetalLayer* layer = m_layer) {
    const CGSize drawableSize = layer.drawableSize;
    if (drawableSize.width > 0.0 && drawableSize.height > 0.0) {
      m_config.width = static_cast<uint32_t>(drawableSize.width);
      m_config.height = static_cast<uint32_t>(drawableSize.height);
    }
  }
#endif

  const float aspect = m_config.height > 0
                           ? static_cast<float>(m_config.width) / static_cast<float>(m_config.height)
                           : 16.0F / 9.0F;
  RenderScene& mutableScene = const_cast<RenderScene&>(scene);
  mutableScene.camera().setPerspective(54.0F, aspect, 0.1F, 500.0F);

  const auto collected = scene.collectDrawCommandBatch(true);
  const TierAwareDrawBatch tierBatch = applyConsoleTierToDrawBatch(scene, collected);
  const RenderScene::DrawCommandBatch& batch = tierBatch.batch;
  m_lastDrawStats = batch.stats;
  if (tierBatch.tierPlan.recommendDegrade) {
    NEXUS_LOG_INFO(nexus::LogChannel::kRenderer,
                   "Metal tier LOD degrade active projected_tris=" +
                       std::to_string(tierBatch.tierPlan.projectedTriangles) + " bias=" +
                       std::to_string(nexus::core::activeScalePlan().lodDistanceBias));
  }

  if (scene.meshCount() != m_uploadedMeshCount || m_gpuMeshes.size() != scene.meshCount()) {
    const auto uploadResult = uploadSceneMeshes(scene);
    if (uploadResult.isErr()) {
      m_lastError = uploadResult.error();
      return uploadResult;
    }
  }

#if defined(__APPLE__)
  CAMetalLayer* layer = m_layer;
  id<MTLDevice> device = (__bridge id)m_device;
  id<MTLCommandQueue> commandQueue = (__bridge id)m_commandQueue;
  id<MTLRenderPipelineState> pipeline = (__bridge id)m_pipelineState;
  if (layer == nullptr || device == nil || commandQueue == nil || pipeline == nil) {
    m_lastError = "MetalRenderer backend handles missing";
    return Result<void>::err(m_lastError);
  }

  id<CAMetalDrawable> drawable = [layer nextDrawable];
  if (drawable == nil) {
    return Result<void>::ok();
  }

  const auto viewProjection = scene.camera().viewProjectionMatrix();

  MTLRenderPassDescriptor* passDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
  passDescriptor.colorAttachments[0].texture = drawable.texture;
  passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
  passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
  passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.06, 0.09, 0.14, 1.0);

  id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
  id<MTLRenderCommandEncoder> encoder =
      [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
  [encoder setRenderPipelineState:pipeline];
  if (m_config.validateOnlyWireframe) {
    [encoder setTriangleFillMode:MTLTriangleFillModeLines];
  }
  [encoder setViewport:(MTLViewport){0.0,
                                    0.0,
                                    static_cast<double>(m_config.width),
                                    static_cast<double>(m_config.height),
                                    0.0,
                                    1.0}];

  for (const RenderScene::DrawCommand& command : batch.commands) {
    if (command.meshIndex >= m_gpuMeshes.size()) {
      continue;
    }
    const auto mvp = RenderScene::multiplyMatrix(viewProjection, command.modelMatrix);
    [encoder setVertexBytes:mvp.data() length:sizeof(mvp) atIndex:1];
    const GpuMesh& gpuMesh = m_gpuMeshes[command.meshIndex];
    if (gpuMesh.vertexBuffer == nullptr || gpuMesh.indexBuffer == nullptr ||
        gpuMesh.indexCount == 0) {
      continue;
    }
    id<MTLBuffer> vertexBuffer = (__bridge id)gpuMesh.vertexBuffer;
    id<MTLBuffer> indexBuffer = (__bridge id)gpuMesh.indexBuffer;
    [encoder setVertexBuffer:vertexBuffer offset:0 atIndex:0];
    [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                        indexCount:gpuMesh.indexCount
                         indexType:MTLIndexTypeUInt32
                       indexBuffer:indexBuffer
                 indexBufferOffset:0];
  }

  [encoder endEncoding];
  [commandBuffer presentDrawable:drawable];
  [commandBuffer commit];

  return Result<void>::ok();
#else
  m_lastError = "MetalRenderer only available on Apple platforms";
  return Result<void>::err(m_lastError);
#endif
}

auto MetalRenderer::shutdown() -> void {
#if defined(__APPLE__)
  releaseGpuMeshes();
  releaseMetalObject(m_depthStencilState);
  releaseMetalObject(m_pipelineState);
  releaseMetalObject(m_commandQueue);
  releaseMetalObject(m_device);
#endif
  m_layer = nullptr;
  m_initialized = false;
  m_pipelineReady = false;
  m_lastError.clear();
}

} // namespace nexus::renderer
