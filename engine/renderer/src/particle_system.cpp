#include "nexus/renderer/particle_system.h"

#include "nexus/core/job_system.h"

#include <algorithm>
#include <cmath>

namespace nexus::renderer {

auto particleBudgetForTier(ParticleTier tier) -> std::size_t {
  switch (tier) {
  case ParticleTier::kMobileLow:
    return 512;
  case ParticleTier::kMobileMid:
    return 2048;
  case ParticleTier::kMobileHigh:
    return 8192;
  }
  return 2048;
}

// ── ParticleEmitter ─────────────────────────────────────────────────────────

ParticleEmitter::ParticleEmitter(ParticleEmitterConfig config)
    : m_config(config), m_rngState(config.randomSeed == 0 ? 1U : config.randomSeed) {
  m_positions.resize(m_config.maxParticles);
  m_velocities.resize(m_config.maxParticles);
  m_ages.resize(m_config.maxParticles);
  m_rotations.resize(m_config.maxParticles);
}

auto ParticleEmitter::nextRandom01() -> float {
  std::uint32_t x = m_rngState;
  x ^= x << 13;
  x ^= x >> 17;
  x ^= x << 5;
  m_rngState = x;
  return static_cast<float>(x) / static_cast<float>(0xFFFFFFFFU);
}

auto ParticleEmitter::spawnOne() -> void {
  if (m_liveCount >= m_config.maxParticles) {
    return;
  }
  const std::size_t slot = m_liveCount++;
  m_positions[slot] = m_config.spawnPosition;
  for (int axis = 0; axis < 3; ++axis) {
    const float jitter = (nextRandom01() * 2.0F - 1.0F) * m_config.velocityJitter[axis];
    m_velocities[slot][axis] = m_config.initialVelocity[axis] + jitter;
  }
  m_ages[slot] = 0.0F;
  m_rotations[slot] = nextRandom01() * 6.2831853F;
}

auto ParticleEmitter::update(float deltaSeconds) -> void {
  if (deltaSeconds <= 0.0F) {
    return;
  }

  // Expire (swap-remove keeps the live range compact; order is not part of
  // the contract — draws are unsorted particles).
  std::size_t index = 0;
  while (index < m_liveCount) {
    m_ages[index] += deltaSeconds;
    if (m_ages[index] >= m_config.lifetimeSeconds) {
      const std::size_t last = m_liveCount - 1;
      m_positions[index] = m_positions[last];
      m_velocities[index] = m_velocities[last];
      m_ages[index] = m_ages[last];
      m_rotations[index] = m_rotations[last];
      --m_liveCount;
      continue; // re-check swapped-in particle
    }
    ++index;
  }

  // Integrate.
  for (std::size_t i = 0; i < m_liveCount; ++i) {
    for (int axis = 0; axis < 3; ++axis) {
      m_velocities[i][axis] += m_config.gravity[axis] * deltaSeconds;
      m_positions[i][axis] += m_velocities[i][axis] * deltaSeconds;
    }
  }

  // Spawn owed particles.
  m_spawnAccumulator += m_config.spawnPerSecond * deltaSeconds;
  while (m_spawnAccumulator >= 1.0F && m_liveCount < m_config.maxParticles) {
    spawnOne();
    m_spawnAccumulator -= 1.0F;
  }
  m_spawnAccumulator = std::min(m_spawnAccumulator, 1.0F); // cap owed backlog
}

auto ParticleEmitter::buildSpriteBatch() const -> ParticleSpriteBatch {
  ParticleSpriteBatch batch{};
  batch.instances.reserve(m_liveCount);
  const float lifetime = std::max(m_config.lifetimeSeconds, 1e-6F);
  const float frames = static_cast<float>(std::max<std::uint32_t>(m_config.flipbookFrames, 1));

  for (std::size_t i = 0; i < m_liveCount; ++i) {
    const float lifeT = std::clamp(m_ages[i] / lifetime, 0.0F, 1.0F);
    ParticleInstanceData instance{};
    instance.position[0] = m_positions[i][0];
    instance.position[1] = m_positions[i][1];
    instance.position[2] = m_positions[i][2];
    instance.scale = m_config.startScale + (m_config.endScale - m_config.startScale) * lifeT;
    instance.rotationRadians = m_rotations[i];
    instance.frameIndex = std::min(lifeT * frames, frames - 1.0F);
    instance.opacity = 1.0F - lifeT;
    batch.instances.push_back(instance);
  }
  return batch;
}

// ── ParticleSystem ──────────────────────────────────────────────────────────

ParticleSystem::ParticleSystem(ParticleTier tier)
    : m_tier(tier), m_budget(particleBudgetForTier(tier)) {}

auto ParticleSystem::totalCapacity() const -> std::size_t {
  std::size_t total = 0;
  for (const ParticleEmitter& emitter : m_emitters) {
    total += emitter.config().maxParticles;
  }
  return total;
}

auto ParticleSystem::totalLive() const -> std::size_t {
  std::size_t total = 0;
  for (const ParticleEmitter& emitter : m_emitters) {
    total += emitter.liveCount();
  }
  return total;
}

auto ParticleSystem::addEmitter(ParticleEmitterConfig config) -> std::size_t {
  const std::size_t used = totalCapacity();
  const std::size_t remaining = used >= m_budget ? 0 : m_budget - used;
  config.maxParticles = std::min(config.maxParticles, remaining);
  m_emitters.emplace_back(config);
  return m_emitters.size() - 1;
}

auto ParticleSystem::emitter(std::size_t index) -> ParticleEmitter& {
  return m_emitters.at(index);
}

auto ParticleSystem::update(float deltaSeconds, core::JobSystem* jobs) -> void {
  if (m_emitters.empty()) {
    return;
  }
  if (jobs != nullptr && m_emitters.size() >= 2) {
    jobs->parallelFor(m_emitters.size(), 1, [this, deltaSeconds](std::size_t index) {
      m_emitters[index].update(deltaSeconds);
    });
  } else {
    for (ParticleEmitter& emitter : m_emitters) {
      emitter.update(deltaSeconds);
    }
  }
}

auto ParticleSystem::buildSpriteBatches() const -> std::vector<ParticleSpriteBatch> {
  std::vector<ParticleSpriteBatch> batches;
  batches.reserve(m_emitters.size());
  for (const ParticleEmitter& emitter : m_emitters) {
    batches.push_back(emitter.buildSpriteBatch());
  }
  return batches;
}

} // namespace nexus::renderer
