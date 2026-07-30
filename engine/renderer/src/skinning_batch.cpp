#include "nexus/renderer/skinning_batch.h"

#include "nexus/core/job_system.h"

namespace nexus::renderer {

auto SkinningBatch::advanceAll(std::span<AnimationPlayer> players,
                               float deltaSeconds,
                               core::JobSystem* jobs) -> SkinningBatchStats {
  SkinningBatchStats stats{};
  if (players.empty()) {
    return stats;
  }

  const bool parallel = jobs != nullptr && players.size() >= kParallelThreshold;
  if (parallel) {
    jobs->parallelFor(players.size(), kParallelGrain, [&players, deltaSeconds](std::size_t index) {
      players[index].advance(deltaSeconds);
    });
  } else {
    for (AnimationPlayer& player : players) {
      player.advance(deltaSeconds);
    }
  }

  stats.playersAdvanced = players.size();
  stats.ranParallel = parallel;
  for (const AnimationPlayer& player : players) {
    stats.bonesSkinned += player.pose().boneCount;
  }
  return stats;
}

} // namespace nexus::renderer
