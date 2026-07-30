#pragma once

// NEXUS particle system — phase 1: CPU simulation + GPU-ready sprite batching
// (Sprint 1, nexus/engine-gfx).
//
// Simulation runs on the CPU (optionally JobSystem-parallel) with SoA storage;
// buildSpriteBatch() flattens live particles into one per-emitter instance
// array so a backend renders the whole emitter as a single instanced quad
// draw over a flipbook sheet (scripts/assets/particle_sheet_gen.py output).
// Promotion of the integration step to a Metal compute pass is tracked in
// docs/architecture/NEXUS_GPU_Feature_Decisions.md — the instance-buffer
// contract below is the same in both phases, so backends do not change.
//
// Budgets follow infra/asset_spec.md (mobile-low 512 / mid 2048 / high 8192).

#include <array>
#include <cstddef>
#include <cstdint>
#include <vector>

namespace nexus::core {
class JobSystem;
}

namespace nexus::renderer {

enum class ParticleTier : std::uint8_t {
  kMobileLow,
  kMobileMid,
  kMobileHigh,
};

/// Live-particle ceiling per scene for a device tier (infra/asset_spec.md).
[[nodiscard]] auto particleBudgetForTier(ParticleTier tier) -> std::size_t;

struct ParticleEmitterConfig {
  std::size_t maxParticles{256};
  float spawnPerSecond{64.0F};
  float lifetimeSeconds{1.2F};
  std::array<float, 3> spawnPosition{0.0F, 0.0F, 0.0F};
  std::array<float, 3> initialVelocity{0.0F, 3.0F, 0.0F};
  /// Deterministic per-particle velocity jitter amplitude (xyz).
  std::array<float, 3> velocityJitter{1.0F, 0.5F, 1.0F};
  std::array<float, 3> gravity{0.0F, -9.8F, 0.0F};
  float startScale{0.25F};
  float endScale{0.05F};
  std::uint32_t flipbookFrames{16};
  std::uint32_t randomSeed{0x4E455855U}; // "NEXU"
};

/// Per-instance data consumed by an instanced-quad draw. Layout is
/// intentionally flat/trivially-copyable for direct buffer upload.
struct ParticleInstanceData {
  float position[3];
  float scale;
  float rotationRadians;
  float frameIndex;   // flipbook frame, floor()ed by the shader
  float opacity;      // linear fade-out over life
  float pad{0.0F};    // 32-byte stride
};
static_assert(sizeof(ParticleInstanceData) == 32);

struct ParticleSpriteBatch {
  std::vector<ParticleInstanceData> instances;
  /// One instanced draw per emitter: instanceCount == instances.size().
  [[nodiscard]] auto drawCallCount() const -> std::size_t {
    return instances.empty() ? 0 : 1;
  }
};

/// One emitter: fixed-capacity SoA pool with deterministic spawn/integrate.
class ParticleEmitter {
public:
  explicit ParticleEmitter(ParticleEmitterConfig config);

  /// Spawns owed particles, integrates velocity/gravity, expires dead ones.
  auto update(float deltaSeconds) -> void;

  [[nodiscard]] auto liveCount() const -> std::size_t { return m_liveCount; }
  [[nodiscard]] auto config() const -> const ParticleEmitterConfig& { return m_config; }

  /// Flattens live particles into a single instanced-draw payload.
  [[nodiscard]] auto buildSpriteBatch() const -> ParticleSpriteBatch;

private:
  auto spawnOne() -> void;
  /// xorshift32 — deterministic across platforms for a fixed seed.
  auto nextRandom01() -> float;

  ParticleEmitterConfig m_config;
  std::uint32_t m_rngState;
  float m_spawnAccumulator{0.0F};
  std::size_t m_liveCount{0};

  // SoA pools, size == maxParticles; [0, m_liveCount) are live.
  std::vector<std::array<float, 3>> m_positions;
  std::vector<std::array<float, 3>> m_velocities;
  std::vector<float> m_ages;
  std::vector<float> m_rotations;
};

/// Scene-level collection enforcing the per-tier live-particle budget.
class ParticleSystem {
public:
  explicit ParticleSystem(ParticleTier tier = ParticleTier::kMobileMid);

  /// Clamps emitter capacity so the scene total stays within the tier budget.
  /// Returns the emitter index.
  auto addEmitter(ParticleEmitterConfig config) -> std::size_t;

  [[nodiscard]] auto emitterCount() const -> std::size_t { return m_emitters.size(); }
  [[nodiscard]] auto emitter(std::size_t index) -> ParticleEmitter&;
  [[nodiscard]] auto totalCapacity() const -> std::size_t;
  [[nodiscard]] auto totalLive() const -> std::size_t;
  [[nodiscard]] auto tierBudget() const -> std::size_t { return m_budget; }

  /// Updates every emitter; with >=2 emitters and a JobSystem, emitters run in
  /// parallel (each owns disjoint state).
  auto update(float deltaSeconds, core::JobSystem* jobs = nullptr) -> void;

  /// One ParticleSpriteBatch per emitter, in emitter order.
  [[nodiscard]] auto buildSpriteBatches() const -> std::vector<ParticleSpriteBatch>;

private:
  ParticleTier m_tier;
  std::size_t m_budget;
  std::vector<ParticleEmitter> m_emitters;
};

} // namespace nexus::renderer
