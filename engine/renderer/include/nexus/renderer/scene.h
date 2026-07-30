#pragma once

#include "nexus/renderer/camera.h"
#include "nexus/renderer/mesh.h"

#include <array>
#include <cstddef>
#include <nlohmann/json.hpp>
#include <string>
#include <string_view>
#include <vector>

namespace nexus::renderer {

enum class ProceduralFallback {
  kArenaGrid,
  kFlatPlane,
  kNone,
};

struct Transform {
  float translation[3]{0.0F, 0.0F, 0.0F};
  float rotationYRadians{0.0F};
  float scale[3]{1.0F, 1.0F, 1.0F};
};

struct MeshInstance {
  std::size_t meshIndex{0};
  Transform localTransform{};
};

struct SceneEntity {
  Transform transform{};
  std::vector<MeshInstance> meshInstances;
  std::vector<SceneEntity> children;
};

// Minimal scene graph: entities with optional child hierarchy and mesh instances.
class RenderScene {
public:
  [[nodiscard]] auto camera() -> Camera& { return m_camera; }
  [[nodiscard]] auto camera() const -> const Camera& { return m_camera; }

  auto addMesh(Mesh mesh) -> std::size_t;
  [[nodiscard]] auto mesh(std::size_t index) const -> const Mesh&;
  [[nodiscard]] auto meshCount() const -> std::size_t { return m_meshes.size(); }

  auto addRootEntity(SceneEntity entity) -> std::size_t;
  [[nodiscard]] auto rootEntityCount() const -> std::size_t { return m_rootEntities.size(); }

  struct DrawCommand {
    std::size_t meshIndex{0};
    std::array<float, 16> modelMatrix{};
  };

  struct DrawStats {
    std::size_t totalDraws{0};
    std::size_t visibleDraws{0};
    std::size_t culledDraws{0};
    std::size_t triangleCount{0};

    [[nodiscard]] static constexpr std::size_t kSceneTriangleBudget() { return 130'000; }
    [[nodiscard]] auto withinBudget() const -> bool {
      return triangleCount <= kSceneTriangleBudget();
    }
  };

  struct DrawCommandBatch {
    std::vector<DrawCommand> commands;
    DrawStats stats{};
  };

  /// One instanced draw: a mesh plus every visible per-instance model matrix.
  /// Backends submit this as a single draw with instanceCount = transforms.size()
  /// (Metal: drawIndexedPrimitives(...instanceCount:), Vulkan: vkCmdDrawIndexed).
  struct InstancedDraw {
    std::size_t meshIndex{0};
    std::vector<std::array<float, 16>> instanceTransforms;
  };

  struct InstancedDrawBatch {
    std::vector<InstancedDraw> draws;  // ordered by ascending meshIndex
    DrawStats stats{};                 // same stats as the flat batch

    /// GPU submissions needed after batching (vs stats.visibleDraws before).
    [[nodiscard]] auto instancedDrawCount() const -> std::size_t { return draws.size(); }
  };

  [[nodiscard]] auto collectDrawCommands(bool frustumCull = true) const -> std::vector<DrawCommand>;
  [[nodiscard]] auto collectDrawCommandBatch(bool frustumCull = true) const -> DrawCommandBatch;

  /// Groups the visible draw commands by mesh so backends can render each
  /// unique mesh once with per-instance transforms (draw-call batching).
  [[nodiscard]] auto collectInstancedDrawBatch(bool frustumCull = true) const
      -> InstancedDrawBatch;

  static auto createDefaultArena() -> RenderScene;
  static auto createProceduralArena(ProceduralFallback fallback) -> RenderScene;
  static auto createFromManifest(const std::string& manifestPath,
                                 std::string_view modeId = {}) -> RenderScene;
  static auto createFromVenueKey(const std::string& manifestPath,
                                 std::string_view venueKey) -> RenderScene;

  /// Frames orbit camera from mesh bounds (used after venue import).
  static auto frameCameraToBounds(Camera& camera,
                                  const MeshBounds& bounds,
                                  std::string_view modeId = {}) -> void;

  /// Stub: attaches chunked environment scan meshes as scene entities (Luma parity path).
  static auto attachEnvironmentChunks(RenderScene& scene,
                                      const nlohmann::json& environmentScanEntry) -> void;

  [[nodiscard]] static auto modelMatrix(const Transform& transform) -> std::array<float, 16>;
  [[nodiscard]] static auto multiplyMatrix(const std::array<float, 16>& a,
                                           const std::array<float, 16>& b)
      -> std::array<float, 16>;

private:
  [[nodiscard]] auto collectAllDrawCommands() const -> std::vector<DrawCommand>;
  void collectFromEntity(const SceneEntity& entity,
                         const std::array<float, 16>& parentWorld,
                         std::vector<DrawCommand>& out) const;

  std::vector<Mesh> m_meshes;
  std::vector<SceneEntity> m_rootEntities;
  Camera m_camera;
};

} // namespace nexus::renderer
