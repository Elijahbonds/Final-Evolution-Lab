// File: app/gameplay/include/nexus/gameplay/fitness_data.h
// Part of: Final Evolution Lab (FEL) Game Logic
// Spec: 02 Fitness Data Schema, 10 Phase 2 Biometric Integration
#pragma once

#include <cstdint>
#include <mutex>

namespace nexus::gameplay {

struct FRCMetrics {
  // Joint mobility score, normalized 0.0 to 1.0.
  float mobilityScore{0.0F};
  // Active range score, normalized 0.0 to 1.0.
  float activeRangeScore{0.0F};
  // Control quality score, normalized 0.0 to 1.0.
  float controlScore{0.0F};
};

struct IAPMetrics {
  // Breath engagement score, normalized 0.0 to 1.0.
  float engagementScore{0.0F};
  // Breath confidence score, normalized 0.0 to 1.0.
  float confidence{0.0F};
  // Breath phase: -1 exhale, 0 neutral, 1 inhale.
  std::int8_t breathPhase{0};
};

struct FitnessSnapshot {
  // FRC metrics copied atomically from the app fitness container.
  FRCMetrics frc;
  // IAP metrics copied atomically from the app fitness container.
  IAPMetrics iap;
  // Monotonic revision incremented on each fitness update.
  std::uint64_t revision{0};
};

class ThreadSafeFitnessData;

class FitnessReadView {
public:
  explicit FitnessReadView(const ThreadSafeFitnessData& data);

  /// Returns a consistent read-only snapshot for physics/gameplay consumers.
  [[nodiscard]] auto snapshot() const -> FitnessSnapshot;

private:
  const ThreadSafeFitnessData& m_data;
};

class ThreadSafeFitnessData {
public:
  /// Stores FRC mobility metrics using a mutex-protected snapshot update.
  void update_frc(FRCMetrics metrics);

  /// Stores IAP breath metrics using a mutex-protected snapshot update.
  void update_iap(IAPMetrics metrics);

  /// Stores both FRC and IAP metrics using a single snapshot revision.
  void update(FRCMetrics frc, IAPMetrics iap);

  /// Returns a consistent copy of the latest fitness metrics.
  [[nodiscard]] auto snapshot() const -> FitnessSnapshot;

  /// Returns the read-only view used by physics-facing gameplay modules.
  [[nodiscard]] auto read_view() const -> FitnessReadView;

private:
  mutable std::mutex m_mutex;
  FitnessSnapshot m_snapshot;
};

} // namespace nexus::gameplay
