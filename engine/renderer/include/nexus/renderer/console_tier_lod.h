#pragma once

// Console-tier renderer fidelity within the mobile budget (Workstream 4).
//
// CPU-side helpers that (a) batch draw commands into instanced groups to cut
// draw-call count, and (b) project triangle/draw load against the active
// EngineScalePlan and auto-degrade LOD when a frame would blow the mobile cap
// (<=130k tris, <750 draws). Pairs with PerfMonitor tiers (Workstream 5) so the
// engine self-scales. No GPU dependency — fully unit-testable headless-style.

#include "nexus/core/engine_scale_policy.h"
#include "nexus/renderer/scene.h"

#include <array>
#include <cstddef>
#include <vector>

namespace nexus::renderer {

/// One mesh drawn as N instances in a single (instanced) draw call.
struct InstancedBatch {
  std::size_t meshIndex{0};
  std::vector<std::array<float, 16>> instanceTransforms;
};

struct BatchedDrawList {
  std::vector<InstancedBatch> batches;
  std::size_t drawCalls{0};     // == distinct meshes (one instanced call each)
  std::size_t instanceCount{0}; // total instances drawn
};

/// Groups draw commands by mesh so each unique mesh becomes one instanced draw.
[[nodiscard]] auto batchDrawCommands(const std::vector<RenderScene::DrawCommand>& commands)
    -> BatchedDrawList;

/// LOD scaling decision for a frame given the active scale plan.
struct ConsoleTierFramePlan {
  std::size_t rawTriangles{0};
  std::size_t projectedTriangles{0}; // after LOD-distance bias
  std::size_t rawDrawCalls{0};
  std::size_t batchedDrawCalls{0};   // after instanced batching
  bool dynamicShadows{true};
  bool bloomEnabled{true};
  bool withinTriangleBudget{false};
  bool withinDrawBudget{false};
  bool recommendDegrade{false};      // frame still over budget at this tier

  [[nodiscard]] auto withinMobileBudget() const -> bool {
    return withinTriangleBudget && withinDrawBudget;
  }
};

/// Projects a collected frame against the plan and recommends degrade if needed.
[[nodiscard]] auto evaluateConsoleTierFrame(const RenderScene::DrawStats& stats,
                                            const BatchedDrawList& batched,
                                            const nexus::core::EngineScalePlan& plan)
    -> ConsoleTierFramePlan;

/// Convenience: collect, batch, and evaluate against the active PerfMonitor tier.
[[nodiscard]] auto planSceneForActiveTier(const RenderScene& scene)
    -> ConsoleTierFramePlan;

struct TierAwareDrawBatch {
  RenderScene::DrawCommandBatch batch;
  ConsoleTierFramePlan tierPlan;
};

/// Applies active PerfMonitor tier LOD bias and budget degrade to a collected batch.
[[nodiscard]] auto applyConsoleTierToDrawBatch(const RenderScene& scene,
                                               RenderScene::DrawCommandBatch collected)
    -> TierAwareDrawBatch;

} // namespace nexus::renderer
