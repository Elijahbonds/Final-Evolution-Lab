#include "nexus/assets/asset_manifest.h"
#include "nexus/assets/mesh_importer.h"
#include "nexus/core/dev_stats.h"
#include "nexus/core/perf_monitor.h"
#include "nexus/renderer/animation_player.h"
#include "nexus/renderer/frustum.h"
#include "nexus/renderer/lighting.h"
#include "nexus/renderer/material.h"
#include "nexus/renderer/mesh.h"
#include "nexus/renderer/mesh_lod.h"
#include "nexus/renderer/metal_renderer.h"
#include "nexus/renderer/post_process.h"
#include "nexus/renderer/shadow_runtime.h"
#include "nexus/renderer/bloom_runtime.h"
#include "nexus/renderer/scene.h"

#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <string>

#include <chrono>
#include <thread>
#include <unistd.h>

namespace {

void require(bool condition, const char* message) {
  if (!condition) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    std::exit(1);
  }
}

void removeTreeBestEffort(const std::filesystem::path& root) {
  for (int attempt = 0; attempt < 5; ++attempt) {
    std::error_code ec;
    std::filesystem::remove_all(root, ec);
    if (!ec || !std::filesystem::exists(root)) {
      return;
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(10 * (attempt + 1)));
  }
}

struct TempDir {
  std::filesystem::path root;

  explicit TempDir(const char* label) {
    root = std::filesystem::temp_directory_path() /
           (std::string(label) + "_" + std::to_string(getpid()));
    removeTreeBestEffort(root);
    std::filesystem::create_directories(root);
  }

  ~TempDir() {
    removeTreeBestEffort(root);
  }
};

struct ScopedEnvVar {
  std::string key;
  bool hadPrevious{false};
  std::string previous;

  ScopedEnvVar(const char* envKey, const char* value) : key(envKey) {
    if (const char* prev = std::getenv(envKey); prev != nullptr) {
      hadPrevious = true;
      previous = prev;
    }
#if defined(_WIN32)
    _putenv_s(envKey, value);
#else
    setenv(envKey, value, 1);
#endif
  }

  ~ScopedEnvVar() {
#if defined(_WIN32)
    if (hadPrevious) {
      _putenv_s(key.c_str(), previous.c_str());
    } else {
      _putenv_s(key.c_str(), "");
    }
#else
    if (hadPrevious) {
      setenv(key.c_str(), previous.c_str(), 1);
    } else {
      unsetenv(key.c_str());
    }
#endif
  }
};

void writeDemoMeshFixture(const std::string& path) {
  std::ofstream mesh(path);
  mesh << R"json({
    "format": "nexusmesh",
    "version": "1",
    "vertices": [
      {"position": [0, 0, 0], "color": [1, 0, 0], "normal": [0, 1, 0], "uv": [0, 0]},
      {"position": [1, 0, 0], "color": [0, 1, 0], "normal": [0, 1, 0], "uv": [1, 0]},
      {"position": [0, 1, 0], "color": [0, 0, 1], "normal": [0, 1, 0], "uv": [0.5, 1]}
    ],
    "indices": [0, 1, 2]
  })json";
}

void mesh_vertex_layout_includes_pbr_channels() {
  require(sizeof(nexus::renderer::MeshVertex) >= sizeof(float) * 11, "mesh vertex pbr layout size");
}

void mesh_importer_reads_optional_normal_uv() {
  TempDir tempDir("nexus_renderer_test_pbr");
  const std::string meshPath = (tempDir.root / "pbr.nexusmesh.json").string();
  writeDemoMeshFixture(meshPath);

  const auto result = nexus::assets::MeshImporter::importFile(meshPath);
  require(result.isOk(), "import pbr channels");
  require(result.value().hasPbrChannels, "pbr flag set");
}

void frustum_culls_offscreen_mesh() {
  nexus::renderer::RenderScene scene;
  const std::size_t meshIndex = scene.addMesh(nexus::renderer::Mesh::createUnitCube(0.5F, 1, 1, 1));

  nexus::renderer::SceneEntity entity;
  nexus::renderer::MeshInstance instance;
  instance.meshIndex = meshIndex;
  entity.meshInstances.push_back(instance);
  entity.transform.translation[0] = 500.0F;
  scene.addRootEntity(std::move(entity));

  scene.camera().setOrbitTarget(0.0F, 0.0F, 0.0F);
  scene.camera().setOrbit(5.0F, 3.0F, 0.0F);
  scene.camera().setPerspective(60.0F, 16.0F / 9.0F, 0.1F, 100.0F);

  const auto culled = scene.collectDrawCommands(true);
  const auto unculled = scene.collectDrawCommands(false);
  require(unculled.size() == 1, "unculled draw present");
  require(culled.empty(), "offscreen mesh culled");
}

void manifest_resolve_mesh_path_respects_profile() {
  nexus::assets::AssetRecord record{};
  record.importedMesh = "demo.nexusmesh.json";
  record.importedMeshMobile = "demo_mobile.nexusmesh.json";

  const nexus::assets::AssetManifest manifest = nexus::assets::AssetManifest::loadFromFile(
      "assets/nexus/manifests/nexus_asset_manifest.json")
                                                  .value();

  const nexus::assets::AssetRecord* venice =
      manifest.findAsset("venice_beach_court_model_fbx");
  require(venice != nullptr, "venice asset in manifest");
  const std::string desktopPath = manifest.resolveImportedPath(*venice);
  require(!desktopPath.empty(), "desktop mesh path resolved");
}

void mesh_decimation_reduces_vertex_budget() {
  nexus::renderer::Mesh mesh = nexus::renderer::Mesh::createUnitCube(0.5F, 1.0F, 0.5F, 0.2F);
  const std::size_t originalVertices = mesh.vertexCount();
  mesh.decimateToVertexBudget(8);
  require(mesh.vertexCount() <= originalVertices, "decimation changed mesh");
  require(mesh.triangleCount() < 12, "decimation removed triangles");
}

void mesh_bounds_center_unit_cube() {
  const nexus::renderer::Mesh mesh = nexus::renderer::Mesh::createUnitCube(0.5F, 1.0F, 0.5F, 0.2F);
  const nexus::renderer::MeshBounds bounds = mesh.computeBounds();
  require(bounds.center[0] > -0.01F && bounds.center[0] < 0.01F, "cube center x");
  require(bounds.center[1] > -0.01F && bounds.center[1] < 0.01F, "cube center y");
  require(bounds.extent[0] > 0.9F && bounds.extent[0] < 1.1F, "cube extent");
}

void scene_graph_collects_child_draw_commands() {
  nexus::renderer::RenderScene scene;
  const std::size_t meshIndex = scene.addMesh(nexus::renderer::Mesh::createUnitCube(0.5F, 1, 1, 1));

  nexus::renderer::SceneEntity root;
  nexus::renderer::SceneEntity child;
  nexus::renderer::MeshInstance instance;
  instance.meshIndex = meshIndex;
  child.meshInstances.push_back(instance);
  child.transform.translation[0] = 2.0F;
  root.children.push_back(std::move(child));
  scene.addRootEntity(std::move(root));

  const auto commands = scene.collectDrawCommands(/*frustumCull=*/false);
  require(commands.size() == 1, "one draw command from child entity");
  require(commands.front().modelMatrix[12] > 1.5F, "child translation applied");
}

void mesh_importer_loads_nexusmesh_json() {
  TempDir tempDir("nexus_renderer_test_mesh");
  const std::string meshPath = (tempDir.root / "demo.nexusmesh.json").string();
  writeDemoMeshFixture(meshPath);

  const auto result = nexus::assets::MeshImporter::importFile(meshPath);
  require(result.isOk(), "import nexusmesh json");
  require(result.value().triangleCount() == 1, "single triangle mesh");
}

void scene_from_manifest_loads_venice_beach() {
  const auto scene = nexus::renderer::RenderScene::createFromManifest(
      "assets/nexus/manifests/nexus_asset_manifest.json", "basketball_dunk");
  require(scene.meshCount() >= 2, "venice court + luma backdrop meshes loaded");
  require(scene.rootEntityCount() >= 2, "venice court + backdrop entities present");
  const auto commands = scene.collectDrawCommands();
  require(!commands.empty(), "venue produces draw commands");
}

void scene_from_manifest_loads_zen_dojo_mobile() {
  const char* previousProfile = std::getenv("NEXUS_MESH_PROFILE");
#if defined(_POSIX_C_SOURCE) || defined(__APPLE__)
  setenv("NEXUS_MESH_PROFILE", "mobile", 1);
#else
  _putenv_s("NEXUS_MESH_PROFILE", "mobile");
#endif

  const auto scene = nexus::renderer::RenderScene::createFromManifest(
      "assets/nexus/manifests/nexus_asset_manifest.json", "karate_endless");
  require(scene.meshCount() >= 1, "zen dojo mesh loaded");
  require(scene.rootEntityCount() >= 1, "zen dojo entity present");

  const nexus::assets::AssetManifest manifest =
      nexus::assets::AssetManifest::loadFromFile(
          "assets/nexus/manifests/nexus_asset_manifest.json")
          .value();
  const nexus::assets::AssetRecord* zen = manifest.findAsset("zen_dojo_environment_model_fbx");
  require(zen != nullptr, "zen dojo asset");
  const std::string mobilePath = manifest.resolveMeshPathForProfile(*zen, "mobile");
  require(mobilePath.find("_mobile.nexusmesh.json") != std::string::npos,
          "zen dojo mobile sidecar path");

#if defined(_POSIX_C_SOURCE) || defined(__APPLE__)
  if (previousProfile != nullptr) {
    setenv("NEXUS_MESH_PROFILE", previousProfile, 1);
  } else {
    unsetenv("NEXUS_MESH_PROFILE");
  }
#endif
}

void mesh_lod_selector_picks_mobile_at_distance() {
  const nexus::renderer::MeshLodSelector selector;
  require(selector.selectProfile(10.0F) == nexus::renderer::MeshProfileChoice::kDesktop,
          "near camera uses desktop");
  require(selector.selectProfile(30.0F) == nexus::renderer::MeshProfileChoice::kMobile,
          "far camera uses mobile");
}

void draw_stats_count_triangles() {
  nexus::renderer::RenderScene scene;
  scene.addMesh(nexus::renderer::Mesh::createUnitCube(0.5F, 1, 1, 1));
  nexus::renderer::SceneEntity entity;
  nexus::renderer::MeshInstance instance;
  instance.meshIndex = 0;
  entity.meshInstances.push_back(instance);
  scene.addRootEntity(std::move(entity));

  const auto batch = scene.collectDrawCommandBatch(/*frustumCull=*/false);
  require(batch.stats.visibleDraws == 1, "one visible draw");
  require(batch.stats.triangleCount == 12, "cube triangle count");
}

void all_manifest_venues_load_scenes() {
  constexpr const char* kManifest = "assets/nexus/manifests/nexus_asset_manifest.json";
  const auto manifest = nexus::assets::AssetManifest::loadFromFile(kManifest).value();
  for (const nexus::assets::VenueRecord& venue : manifest.venues()) {
    const auto scene =
        nexus::renderer::RenderScene::createFromVenueKey(kManifest, venue.venueKey);
    require(scene.meshCount() >= 1, "venue mesh loaded");
    require(scene.rootEntityCount() >= 1, "venue entity present");
    const auto batch = scene.collectDrawCommandBatch(false);
    require(!batch.commands.empty(), "venue produces draw commands");
  }
}

void mobile_profile_loads_venice_within_budget() {
#if defined(_WIN32)
  _putenv_s("NEXUS_MESH_PROFILE", "mobile");
#else
  setenv("NEXUS_MESH_PROFILE", "mobile", 1);
#endif
  constexpr const char* kManifest = "assets/nexus/manifests/nexus_asset_manifest.json";
  const auto scene = nexus::renderer::RenderScene::createFromManifest(kManifest, "basketball_dunk");
  const auto batch = scene.collectDrawCommandBatch(false);
  require(batch.stats.withinBudget(), "mobile venice within tri budget");
}

void pbr_material_shades_with_light() {
  const nexus::renderer::MaterialLibrary library;
  const nexus::renderer::PbrMaterial material = library.defaultVenueMaterial();
  const auto rgb = nexus::renderer::shadePbr(material, {0.0F, 1.0F, 0.0F}, {0.0F, -1.0F, 0.0F});
  require(rgb[0] > 0.0F && rgb[1] > 0.0F && rgb[2] > 0.0F, "pbr shade non-zero");
}

void lighting_setup_normalizes_sun() {
  nexus::renderer::LightingSetup lighting;
  nexus::renderer::DirectionalLight sun{};
  sun.direction = {0.0F, -2.0F, 0.0F};
  lighting.setDirectionalLight(sun);
  const auto dir = lighting.normalizedSunDirection();
  require(dir[1] < -0.9F, "sun points down");
  require(lighting.shadowPass().mapSize == 1024, "default shadow map size");
  require(lighting.shouldRecordShadowPass(), "shadow pass enabled by default");
  const auto lightVp = lighting.shadowLightViewProjection();
  require(lightVp[15] == 1.0F, "shadow light VP stub identity w");
}

void post_process_aces_tonemap_clamps() {
  nexus::renderer::PostProcessChain chain;
  const float mapped = chain.applyToneMap(4.0F);
  require(mapped >= 0.0F && mapped <= 1.0F, "aces tonemap in range");
  const auto order = chain.passOrder();
  require(order.size() >= 4, "post-process pass order includes bloom+tonemap+fxaa");
  require(order.back() == nexus::renderer::PostProcessStage::kPresent, "present is final stage");
  require(chain.shouldApplyFxaa(), "fxaa enabled by default");
  require(chain.exceedsBloomThreshold(0.9F), "bloom threshold gate");
  require(!chain.exceedsBloomThreshold(0.1F), "sub-threshold bloom rejected");
}

void mesh_fallback_placeholder_has_geometry() {
  const nexus::renderer::Mesh fallback = nexus::renderer::Mesh::createFallbackPlaceholder();
  require(fallback.triangleCount() > 0, "fallback mesh has triangles");
  nexus::renderer::Mesh empty{};
  const nexus::renderer::Mesh ensured = nexus::renderer::Mesh::ensureValidGeometry(empty);
  require(ensured.triangleCount() > 0, "ensureValidGeometry substitutes fallback");
}

void frame_pacer_smooths_delta_time() {
  nexus::core::FramePacer pacer;
  const double first = pacer.smoothDelta(0.05, 0.25);
  const double second = pacer.smoothDelta(0.016, 0.25);
  require(first > 0.0 && second > 0.0, "smoothed delta positive");
  require(second < first, "pacer tracks shorter frame times");
}

void dev_hud_disabled_by_default() {
  require(!nexus::core::devHudOverlayEnabled(), "dev hud off unless NEXUS_DEV_HUD=1");
}

void perf_gate_draw_call_budget_constant() {
  require(nexus::core::kMaxDrawCallsMobile == 750, "mobile draw call budget");
  require(nexus::core::kMaxRamBudgetMbMobile == 400, "mobile ram budget");
}

void animation_player_advances_clip() {
  nexus::renderer::AnimationPlayer player;
  const auto clip = player.loadClip("characters/athlete/anim_idle.nexusanim");
  require(clip.isOk(), "load anim clip");
  require(player.play(clip.value().clipId).isOk(), "play clip");
  player.advance(0.5F);
  require(player.normalizedTime() > 0.0F, "animation time advanced");
  require(player.pose().boneCount == 22, "skeleton bone count");
}

void animation_player_interpolates_keyframes_from_json() {
  TempDir tempDir("nexus_renderer_test_anim");
  const std::string clipPath = (tempDir.root / "anim_test.nexusanim.json").string();

  std::ofstream clipFile(clipPath);
  clipFile << R"json({
    "format": "nexusanim",
    "version": "1",
    "clip_id": "anim_test",
    "duration_seconds": 1.0,
    "frames_per_second": 30,
    "looping": true,
    "skeleton": {"bone_count": 2},
    "keyframes": [
      {"time": 0.0, "bones": [{"translation": [0, 0, 0]}, {"translation": [0, 0, 0]}]},
      {"time": 1.0, "bones": [{"translation": [0, 0.2, 0]}, {"translation": [0.1, 0, 0]}]}
    ]
  })json";
  clipFile.close();

  nexus::renderer::AnimationPlayer player;
  const auto clip = player.loadClip(clipPath);
  require(clip.isOk(), "load json anim clip");
  require(clip.value().keyframeCount == 2, "parsed keyframe count");
  require(player.play("anim_test").isOk(), "play json clip");

  const float restY = player.pose().boneMatrices[0][13];
  player.advance(0.5F);
  const float midY = player.pose().boneMatrices[0][13];
  require(midY > restY, "keyframe interpolation moved bone");
  require(player.gpuSkinningUniformByteSize() == 2 * 16 * sizeof(float),
           "gpu skinning buffer size");
  require(!player.skinningMatrixData().empty(), "skinning matrix data populated");
}

void draw_stats_budget_gate() {
  nexus::renderer::RenderScene::DrawStats stats{};
  stats.triangleCount = nexus::renderer::RenderScene::DrawStats::kSceneTriangleBudget();
  require(stats.withinBudget(), "exact budget allowed");
  stats.triangleCount += 1;
  require(!stats.withinBudget(), "budget overflow rejected");
  require(nexus::core::sceneTriangleBudgetExceeded(stats.triangleCount), "perf gate tri exceeded");
  require(!nexus::core::sceneTriangleBudgetExceeded(stats.triangleCount - 1), "perf gate tri ok");
}

void perf_monitor_fps_target_gate() {
  nexus::core::PerfMonitor monitor;
  monitor.beginFrame();
  monitor.endFrame();
  require(monitor.withinFpsTarget(nexus::core::kTargetFpsMobile), "default fps target on bootstrap");
  require(nexus::core::kSceneTriangleBudget == 130'000, "scene triangle budget constant");
}

void metal_renderer_null_layer_fails() {
  nexus::renderer::MetalRenderer renderer;
  const auto result = renderer.initialize(nullptr, {});
  require(result.isErr(), "null metal layer rejected");
}

void perf_monitor_tracks_frames() {
  nexus::core::PerfMonitor monitor;
  monitor.beginFrame();
  monitor.endFrame();
  require(monitor.frameTimeMs() >= 0.0F, "frame time recorded");
}

void lod_policy_selects_lod1_at_distance() {
  const nexus::renderer::MeshLodPolicy policy{};
  require(nexus::renderer::selectLodIndex(10.0F, policy) == 0, "hero lod near camera");
  require(nexus::renderer::selectLodIndex(30.0F, policy) == 1, "lod1 far from camera");
}

void shadow_runtime_flags_label_preview_mode() {
  nexus::renderer::ShadowPassRuntimeFlags flags{};
  require(!flags.gpuDepthResolveEnabled, "gpu shadow off by default");
  require(flags.previewShadowStub, "preview stub default");
  require(flags.shouldLogPreviewOnce(), "preview logging enabled");
  const std::string label(flags.previewLabel());
  require(label.find("PREVIEW") != std::string::npos, "preview label present");
}

void shadow_runtime_flags_from_environment_requests_gpu() {
  ScopedEnvVar gpuShadow("NEXUS_GPU_SHADOW", "1");
  const auto flags = nexus::renderer::ShadowPassRuntimeFlags::fromEnvironment();
  require(flags.gpuDepthResolveRequested, "env requests gpu shadow");
  require(!flags.gpuDepthResolveEnabled, "gpu shadow remains disabled until implemented");
  require(flags.previewShadowStub, "preview stub remains active when gpu shadow is requested");
  require(flags.shouldLogPreviewOnce(), "preview log remains enabled when gpu shadow is requested");
  const std::string label(flags.previewLabel());
  require(label.find("PREVIEW") != std::string::npos, "preview shadow label remains present");
  require(label.find("NEXUS_GPU_SHADOW=1") != std::string::npos, "gpu shadow request label present");
}

void bloom_runtime_flags_label_preview_mode() {
  nexus::renderer::BloomPassRuntimeFlags flags{};
  require(!flags.gpuBloomResolveEnabled, "gpu bloom off by default");
  require(flags.previewBloomStub, "bloom preview stub default");
  require(flags.shouldLogPreviewOnce(), "bloom preview logging enabled");
  const std::string label(flags.previewLabel());
  require(label.find("PREVIEW") != std::string::npos, "bloom preview label present");
}

void bloom_runtime_flags_from_environment_requests_gpu() {
  ScopedEnvVar gpuBloom("NEXUS_GPU_BLOOM", "1");
  const auto flags = nexus::renderer::BloomPassRuntimeFlags::fromEnvironment();
  require(flags.gpuBloomResolveRequested, "env requests gpu bloom");
  require(!flags.gpuBloomResolveEnabled, "gpu bloom remains disabled until implemented");
  require(flags.previewBloomStub, "preview stub remains active when gpu bloom is requested");
  require(flags.shouldLogPreviewOnce(), "preview log remains enabled when gpu bloom is requested");
  const std::string label(flags.previewLabel());
  require(label.find("PREVIEW") != std::string::npos, "preview bloom label remains present");
  require(label.find("NEXUS_GPU_BLOOM=1") != std::string::npos, "gpu bloom request label present");
}

void metal_renderer_config_defaults_validate_only() {
  const nexus::renderer::MetalRendererConfig config{};
  require(config.validateOnlyWireframe, "metal validate-only wireframe default");
  require(config.manifestPath != nullptr, "manifest path default set");
}

void metal_manifest_scene_has_mesh_indices() {
  const auto scene = nexus::renderer::RenderScene::createFromManifest(
      "assets/nexus/manifests/nexus_asset_manifest.json", "basketball_dunk");
  require(scene.meshCount() > 0, "manifest venue exposes meshes");
  const auto batch = scene.collectDrawCommandBatch(false);
  require(!batch.commands.empty(), "manifest venue produces draw commands");
  require(batch.stats.triangleCount > 0, "manifest venue has triangle indices");
}

} // namespace

auto main() -> int {
  mesh_vertex_layout_includes_pbr_channels();
  mesh_importer_reads_optional_normal_uv();
  mesh_decimation_reduces_vertex_budget();
  mesh_bounds_center_unit_cube();
  scene_graph_collects_child_draw_commands();
  frustum_culls_offscreen_mesh();
  mesh_importer_loads_nexusmesh_json();
  scene_from_manifest_loads_venice_beach();
  scene_from_manifest_loads_zen_dojo_mobile();
  manifest_resolve_mesh_path_respects_profile();
  mesh_lod_selector_picks_mobile_at_distance();
  draw_stats_count_triangles();
  lod_policy_selects_lod1_at_distance();
  all_manifest_venues_load_scenes();
  mobile_profile_loads_venice_within_budget();
  pbr_material_shades_with_light();
  lighting_setup_normalizes_sun();
  post_process_aces_tonemap_clamps();
  mesh_fallback_placeholder_has_geometry();
  frame_pacer_smooths_delta_time();
  dev_hud_disabled_by_default();
  perf_gate_draw_call_budget_constant();
  animation_player_advances_clip();
  animation_player_interpolates_keyframes_from_json();
  draw_stats_budget_gate();
  perf_monitor_fps_target_gate();
  shadow_runtime_flags_label_preview_mode();
  shadow_runtime_flags_from_environment_requests_gpu();
  bloom_runtime_flags_label_preview_mode();
  bloom_runtime_flags_from_environment_requests_gpu();
  metal_renderer_config_defaults_validate_only();
  metal_manifest_scene_has_mesh_indices();
  metal_renderer_null_layer_fails();
  perf_monitor_tracks_frames();
  std::fprintf(stderr, "PASS: nexus_renderer_test\n");
  return 0;
}
