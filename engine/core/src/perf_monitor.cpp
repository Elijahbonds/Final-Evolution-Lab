#include "nexus/core/perf_monitor.h"

#include <algorithm>

namespace nexus::core {

auto FramePacer::smoothDelta(double rawSeconds, double maxFrameSeconds) -> double {
  const double clamped = std::min(rawSeconds, maxFrameSeconds);
  m_smoothedSeconds += kSmoothingAlpha * (clamped - m_smoothedSeconds);
  return m_smoothedSeconds;
}

auto PerfMonitor::instance() -> PerfMonitor& {
  static PerfMonitor inst;
  return inst;
}

void PerfMonitor::beginFrame() {
  m_frameStart = Clock::now();
}

void PerfMonitor::endFrame() {
  const auto now = Clock::now();
  m_lastFrameMs =
      std::chrono::duration<float, std::milli>(now - m_frameStart).count();
  ++m_frameCount;

  // Smooth frame time using exponential moving average (EMA)
  m_smoothedFrameTimeMs += 0.1F * (m_lastFrameMs - m_smoothedFrameTimeMs);

  if (m_frameCount == 1) {
    m_lastSample = now;
    m_smoothedFps = 60.0F;
    return;
  }

  const float elapsed =
      std::chrono::duration<float>(now - m_lastSample).count();
  if (elapsed >= 0.5F) {
    m_smoothedFps = static_cast<float>(m_frameCount) / elapsed;
    m_frameCount = 0;
    m_lastSample = now;
    
    if (m_smoothedFrameTimeMs > 33.33F) {
      m_engineSuggestedTier = PerformanceTier::kLowPower;
    } else if (m_smoothedFrameTimeMs > 18.0F) {
      m_engineSuggestedTier = PerformanceTier::kBalanced;
    } else if (m_smoothedFrameTimeMs < 16.0F) {
      m_engineSuggestedTier = PerformanceTier::kHigh;
    }
    refreshActiveTierFromSources();
  }
}

auto PerfMonitor::fps() const -> float {
  return m_smoothedFps;
}

auto PerfMonitor::frameTimeMs() const -> float {
  return m_lastFrameMs;
}

void PerfMonitor::setTier(PerformanceTier tier) {
  m_activeTier = tier;
  m_engineSuggestedTier = tier;
}

void PerfMonitor::setPlatformTier(PerformanceTier tier) {
  m_platformTierLocked = true;
  m_activeTier = tier;
}

void PerfMonitor::clearPlatformTier() {
  m_platformTierLocked = false;
  refreshActiveTierFromSources();
}

auto PerfMonitor::hasPlatformTier() const -> bool {
  return m_platformTierLocked;
}

auto PerfMonitor::getTier() const -> PerformanceTier {
  return m_activeTier;
}

auto PerfMonitor::getEngineSuggestedTier() const -> PerformanceTier {
  return m_engineSuggestedTier;
}

void PerfMonitor::refreshActiveTierFromSources() {
  if (m_platformTierLocked) {
    return;
  }
  m_activeTier = m_engineSuggestedTier;
}

auto PerfMonitor::isBudgetExceeded() const -> bool {
  return m_lastFrameMs > 16.67F;
}

auto PerfMonitor::getPhysicsSubstepFactor() const -> float {
  if (m_activeTier == PerformanceTier::kLowPower) {
    return 0.25F;
  } else if (m_activeTier == PerformanceTier::kBalanced || isBudgetExceeded()) {
    return 0.5F;
  }
  return 1.0F;
}

auto PerfMonitor::getCollisionCheckFactor() const -> float {
  if (m_activeTier == PerformanceTier::kLowPower) {
    return 0.0F;
  } else if (m_activeTier == PerformanceTier::kBalanced || isBudgetExceeded()) {
    return 0.5F;
  }
  return 1.0F;
}

auto sceneTriangleBudgetExceeded(std::size_t triangleCount, std::size_t budget) -> bool {
  return triangleCount > budget;
}

} // namespace nexus::core
