#pragma once

// Batched CPU skinning pose advance (Sprint 1, nexus/engine-gfx).
//
// The renderer has no GPU skinning yet (MeshVertex carries no bone weights —
// see docs/architecture/NEXUS_GPU_Feature_Decisions.md). Until that lands,
// scenes with many animated characters advance every AnimationPlayer on the
// engine JobSystem in parallel: each player owns disjoint state, so
// parallelFor over players is deterministic and race-free.

#include "nexus/renderer/animation_player.h"

#include <cstddef>
#include <span>

namespace nexus::core {
class JobSystem;
}

namespace nexus::renderer {

struct SkinningBatchStats {
  std::size_t playersAdvanced{0};
  std::size_t bonesSkinned{0};
  bool ranParallel{false};
};

/// Advances all players by deltaSeconds. With a JobSystem, players are
/// distributed across workers (grain: kParallelGrain); below
/// kParallelThreshold players it runs serially — thread wake-up costs more
/// than the work itself for a handful of skeletons.
class SkinningBatch {
public:
  static constexpr std::size_t kParallelThreshold = 4;
  static constexpr std::size_t kParallelGrain = 2;

  static auto advanceAll(std::span<AnimationPlayer> players,
                         float deltaSeconds,
                         core::JobSystem* jobs = nullptr) -> SkinningBatchStats;
};

} // namespace nexus::renderer
