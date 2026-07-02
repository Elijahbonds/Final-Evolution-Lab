// File: app/gameplay/include/nexus/gameplay/fitness_data.h
// Part of: Final Evolution Lab (FEL) Game Logic
// Spec: 02 Fitness Data Schema, 10 Phase 2 Biometric Integration
#pragma once

#include "nexus/core/result.h"

#include <nlohmann/json.hpp>
#include <cstdint>
#include <mutex>
#include <string_view>

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
  // Mean of mobility, active range, and control (HUD + throw-catch input).
  float frcComposite{0.0F};
  // engagement × confidence (HUD + throw-catch input).
  float iapComposite{0.0F};
  // Combined readiness score for gameplay impulse scaling (0.0–1.0).
  float powerReadiness{0.0F};
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
  void commitSnapshot(FRCMetrics frc, IAPMetrics iap);

  mutable std::mutex m_mutex;
  FitnessSnapshot m_snapshot;
};

/// Validates a normalized fitness scalar (finite, clamped 0–1).
[[nodiscard]] auto validateFitnessScalar(float value, std::string_view fieldName)
    -> Result<float>;

/// Validates breath phase is −1, 0, or 1.
[[nodiscard]] auto validateBreathPhase(int value) -> Result<std::int8_t>;

/// Computes HUD/physics aggregates from raw FRC metrics.
[[nodiscard]] auto computeFrcComposite(const FRCMetrics& frc) -> float;

/// Computes HUD/physics aggregates from raw IAP metrics.
[[nodiscard]] auto computeIapComposite(const IAPMetrics& iap) -> float;

/// Combined readiness used by throw-catch impulse and HUD meters.
[[nodiscard]] auto computePowerReadiness(const FRCMetrics& frc, const IAPMetrics& iap) -> float;

/// Serializes a fitness snapshot for agent/HUD consumers.
[[nodiscard]] auto fitnessSnapshotToJson(const FitnessSnapshot& snapshot) -> nlohmann::json;

} // namespace nexus::gameplay
