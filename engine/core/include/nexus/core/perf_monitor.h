#pragma once

#include <chrono>
#include <cstddef>
#include <cstdint>

namespace nexus::core {

/// Ship-gate FPS targets (see docs/architecture/NEXUS_Performance_Targets.md).
inline constexpr float kTargetFpsMobile = 60.0F;
inline constexpr float kTargetFpsDesktop = 60.0F;
inline constexpr float kTargetFpsTolerance = 1.0F;
inline constexpr std::size_t kSceneTriangleBudget = 130'000;
inline constexpr std::size_t kMaxDrawCallsMobile = 750;
inline constexpr std::size_t kMaxRamBudgetMbMobile = 400;

enum class PerformanceTier : std::uint8_t {
  kHigh = 0,
  kBalanced = 1,
  kLowPower = 2
};

/// Exponential moving average frame-time smoother for gameplay/camera (not physics).
class FramePacer {
public:
  [[nodiscard]] auto smoothDelta(double rawSeconds, double maxFrameSeconds) -> double;
  [[nodiscard]] auto smoothedDeltaSeconds() const -> double { return m_smoothedSeconds; }

private:
  double m_smoothedSeconds{1.0 / 60.0};
  static constexpr double kSmoothingAlpha = 0.12;
};

class PerfMonitor {
public:
  PerfMonitor() = default;
  static auto instance() -> PerfMonitor&;

  void beginFrame();
  void endFrame();

  [[nodiscard]] auto fps() const -> float;
  [[nodiscard]] auto frameTimeMs() const -> float;
  [[nodiscard]] auto frameCount() const -> std::uint64_t { return m_frameCount; }

  [[nodiscard]] auto withinFpsTarget(float targetFps = kTargetFpsMobile) const -> bool {
    return fps() >= targetFps - kTargetFpsTolerance;
  }

  // Active Performance Tier
  void setTier(PerformanceTier tier);
  /// Platform (iOS) tier override — blocks endFrame() auto-degrade until cleared.
  void setPlatformTier(PerformanceTier tier);
  void clearPlatformTier();
  [[nodiscard]] auto hasPlatformTier() const -> bool;
  [[nodiscard]] auto getTier() const -> PerformanceTier;
  [[nodiscard]] auto getEngineSuggestedTier() const -> PerformanceTier;

  // Frame-time budget and scaling factors
  [[nodiscard]] auto isBudgetExceeded() const -> bool;
  [[nodiscard]] auto getPhysicsSubstepFactor() const -> float;
  [[nodiscard]] auto getCollisionCheckFactor() const -> float;

private:
  using Clock = std::chrono::steady_clock;
  Clock::time_point m_frameStart{};
  Clock::time_point m_lastSample{};
  float m_smoothedFps{60.0F};
  float m_lastFrameMs{16.67F};
  std::uint64_t m_frameCount{0};
  
  PerformanceTier m_activeTier{PerformanceTier::kHigh};
  PerformanceTier m_engineSuggestedTier{PerformanceTier::kHigh};
  bool m_platformTierLocked{false};
  float m_smoothedFrameTimeMs{16.67F};

  void refreshActiveTierFromSources();
};

[[nodiscard]] auto sceneTriangleBudgetExceeded(
    std::size_t triangleCount,
    std::size_t budget = kSceneTriangleBudget) -> bool;

} // namespace nexus::core
