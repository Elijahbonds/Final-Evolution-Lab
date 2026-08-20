#import "NexusMetalBridge.h"

#include "nexus/assets/asset_manifest.h"
#include "nexus/assets/mesh_importer.h"
#include "nexus/renderer/metal_renderer.h"
#include "nexus/renderer/scene.h"

#import <Foundation/Foundation.h>
#import <QuartzCore/CAMetalLayer.h>

#include <cstdlib>
#include <filesystem>
#include <memory>
#include <string>
#include <unordered_map>

namespace {

std::string bundleResourceRoot() {
#if defined(__APPLE__)
  NSBundle *bundle = [NSBundle mainBundle];
  NSString *resourcePath = [[bundle resourcePath] stringByStandardizingPath];
  if (resourcePath != nil) {
    return std::string([resourcePath UTF8String]);
  }
#endif
  return {};
}

void ensureBundleResourceRootEnv() {
  const std::string root = bundleResourceRoot();
  if (!root.empty()) {
    setenv("NEXUS_RESOURCE_ROOT", root.c_str(), 1);
  }
}

void ensureIOSMetalAssetEnv() {
  ensureBundleResourceRootEnv();
  setenv("NEXUS_MESH_PROFILE", "mobile", 1);
}

std::string normalizeRuntimeModeId(const char *modeId) {
  if (modeId == nullptr || modeId[0] == '\0') {
    return "basketball_dunk";
  }
  const std::string mode{modeId};
  if (mode == "venice_pickup") {
    return "basketball_h2h";
  }
  if (mode == "basketball_dunk_3d") {
    return "basketball_dunk";
  }
  return mode;
}

std::string resolveManifestPath() {
#if defined(__APPLE__)
  ensureIOSMetalAssetEnv();
  const std::string root = bundleResourceRoot();
  if (!root.empty()) {
    const std::string bundledManifest =
        root + "/assets/nexus/manifests/nexus_asset_manifest.json";
    if (std::filesystem::exists(bundledManifest)) {
      return bundledManifest;
    }
  }

  NSBundle *bundle = [NSBundle mainBundle];
  NSString *bundled =
      [bundle pathForResource:@"nexus_asset_manifest" ofType:@"json" inDirectory:@"nexus/manifests"];
  if (bundled != nil) {
    return std::string([bundled UTF8String]);
  }
  bundled = [bundle pathForResource:@"nexus_asset_manifest" ofType:@"json"];
  if (bundled != nil) {
    return std::string([bundled UTF8String]);
  }
#endif
  return "assets/nexus/manifests/nexus_asset_manifest.json";
}

} // namespace

struct NexusMetalRendererContext {
  nexus::renderer::MetalRenderer renderer;
  nexus::renderer::RenderScene scene{};
  std::string lastError;
  std::string modeId{"basketball_dunk"};
  float orbitRatePerFrame{0.0035F};
};

bool nexus_metal_bridge_is_linked(void) { return true; }

bool nexus_metal_bridge_has_bundled_manifest(void) {
  const std::string root = bundleResourceRoot();
  if (root.empty()) {
    return false;
  }
  const std::string bundledManifest =
      root + "/assets/nexus/manifests/nexus_asset_manifest.json";
  return std::filesystem::exists(bundledManifest);
}

bool nexus_metal_bridge_bundled_mesh_loadable(const char *assetId) {
  if (assetId == nullptr || assetId[0] == '\0') {
    return false;
  }
  if (!nexus_metal_bridge_has_bundled_manifest()) {
    return false;
  }
  const std::string asset{assetId};
  static std::unordered_map<std::string, bool> cache;
  if (const auto found = cache.find(asset); found != cache.end()) {
    return found->second;
  }
  ensureIOSMetalAssetEnv();
  const std::string manifestPath = resolveManifestPath();
  const auto manifestResult = nexus::assets::AssetManifest::loadFromFile(manifestPath);
  if (manifestResult.isErr()) {
    cache[asset] = false;
    return false;
  }
  const nexus::assets::AssetRecord *record = manifestResult.value().findAsset(asset);
  if (record == nullptr || record->importedMesh.empty()) {
    cache[asset] = false;
    return false;
  }
  const std::string meshPath = manifestResult.value().resolveMeshPath(*record);
  nexus::assets::MeshImportOptions importOptions{};
  importOptions.applyDecimation = false;
  const auto meshResult = nexus::assets::MeshImporter::importFile(meshPath, importOptions);
  const bool loadable = meshResult.isOk() && meshResult.value().triangleCount() > 0;
  cache[asset] = loadable;
  return loadable;
}

bool nexus_metal_bridge_resolve_bundled_mesh_path(const char *assetId, char *outPath,
                                                  size_t outPathLen) {
  if (assetId == nullptr || assetId[0] == '\0' || outPath == nullptr || outPathLen == 0) {
    return false;
  }
  ensureIOSMetalAssetEnv();
  const std::string manifestPath = resolveManifestPath();
  const auto manifestResult = nexus::assets::AssetManifest::loadFromFile(manifestPath);
  if (manifestResult.isErr()) {
    return false;
  }
  const nexus::assets::AssetRecord *record = manifestResult.value().findAsset(assetId);
  if (record == nullptr) {
    return false;
  }
  const std::string meshPath = manifestResult.value().resolveMeshPath(*record);
  if (!std::filesystem::exists(meshPath)) {
    return false;
  }
  if (meshPath.size() + 1 > outPathLen) {
    return false;
  }
  std::copy(meshPath.begin(), meshPath.end(), outPath);
  outPath[meshPath.size()] = '\0';
  return true;
}

bool nexus_metal_bridge_bundled_venue_mesh_loadable(const char *modeId) {
  if (!nexus_metal_bridge_has_bundled_manifest()) {
    return false;
  }
  const std::string mode = normalizeRuntimeModeId(modeId);
  static std::unordered_map<std::string, bool> cache;
  if (const auto found = cache.find(mode); found != cache.end()) {
    return found->second;
  }
  ensureIOSMetalAssetEnv();
  const std::string manifestPath = resolveManifestPath();
  const nexus::renderer::RenderScene scene =
      nexus::renderer::RenderScene::createFromManifest(manifestPath, mode);
  const bool loadable =
      scene.meshCount() >= 1 && !scene.collectDrawCommands(/*frustumCull=*/false).empty();
  cache[mode] = loadable;
  return loadable;
}

NexusMetalRendererHandle nexus_metal_renderer_create(void) {
  ensureIOSMetalAssetEnv();
  return new NexusMetalRendererContext();
}

void nexus_metal_renderer_set_mode_id(NexusMetalRendererHandle handle, const char *modeId) {
  if (handle == nullptr || modeId == nullptr) {
    return;
  }
  auto *ctx = static_cast<NexusMetalRendererContext *>(handle);
  ctx->modeId = normalizeRuntimeModeId(modeId);
}

void nexus_metal_renderer_destroy(NexusMetalRendererHandle handle) {
  if (handle == nullptr) {
    return;
  }
  auto *ctx = static_cast<NexusMetalRendererContext *>(handle);
  ctx->renderer.shutdown();
  delete ctx;
}

bool nexus_metal_renderer_initialize(NexusMetalRendererHandle handle, CAMetalLayer *layer,
                                     uint32_t width, uint32_t height) {
  if (handle == nullptr || layer == nullptr) {
    return false;
  }
  auto *ctx = static_cast<NexusMetalRendererContext *>(handle);
  ensureIOSMetalAssetEnv();
  nexus::renderer::MetalRendererConfig config{};
  config.width = width;
  config.height = height;
  config.preferredFps = 60;
  config.validateOnlyWireframe = false;
  config.modeId = ctx->modeId.c_str();
  const std::string manifestPath = resolveManifestPath();
  config.manifestPath = manifestPath.c_str();
  const auto result = ctx->renderer.initialize(layer, config);
  if (!result.isOk()) {
    ctx->lastError = ctx->renderer.lastError();
    return false;
  }
  ctx->scene = nexus::renderer::RenderScene::createFromManifest(manifestPath, ctx->modeId);
  const auto loadResult = ctx->renderer.loadVenueFromManifest(ctx->modeId);
  if (ctx->scene.meshCount() == 0 ||
      ctx->scene.collectDrawCommands(/*frustumCull=*/false).empty()) {
    ctx->lastError = "Venue scene has no drawable meshes for mode=" + ctx->modeId;
    return false;
  }
  ctx->lastError.clear();
  return true;
}

bool nexus_metal_renderer_render(NexusMetalRendererHandle handle) {
  if (handle == nullptr) {
    return false;
  }
  auto *ctx = static_cast<NexusMetalRendererContext *>(handle);
  if (!ctx->renderer.isInitialized()) {
    ctx->lastError = "Metal renderer not initialized";
    return false;
  }
  if (ctx->orbitRatePerFrame != 0.0F) {
    ctx->scene.camera().advanceOrbit(ctx->orbitRatePerFrame);
  }
  const auto result = ctx->renderer.render(ctx->scene);
  if (!result.isOk()) {
    ctx->lastError = ctx->renderer.lastError();
    return false;
  }
  ctx->lastError.clear();
  return true;
}

void nexus_metal_renderer_set_orbit_rate(NexusMetalRendererHandle handle, float radiansPerFrame) {
  if (handle == nullptr) {
    return;
  }
  auto *ctx = static_cast<NexusMetalRendererContext *>(handle);
  ctx->orbitRatePerFrame = radiansPerFrame;
}

void nexus_metal_renderer_shutdown(NexusMetalRendererHandle handle) {
  if (handle == nullptr) {
    return;
  }
  auto *ctx = static_cast<NexusMetalRendererContext *>(handle);
  ctx->renderer.shutdown();
  ctx->lastError.clear();
}

const char *nexus_metal_renderer_last_error(NexusMetalRendererHandle handle) {
  if (handle == nullptr) {
    return "null handle";
  }
  const auto *ctx = static_cast<const NexusMetalRendererContext *>(handle);
  return ctx->lastError.empty() ? nullptr : ctx->lastError.c_str();
}
