// File: app/gameplay/src/fitness_data.cpp
// Part of: Final Evolution Lab (FEL) Game Logic
// Spec: 02 Fitness Data Schema, 10 Phase 2 Biometric Integration
#include "nexus/gameplay/fitness_data.h"

#include <algorithm>
#include <cmath>
#include <string>

namespace nexus::gameplay {

namespace {

[[nodiscard]] auto clampUnit(float value) -> float {
  return std::clamp(value, 0.0F, 1.0F);
}

void enrichSnapshot(FitnessSnapshot& snapshot) {
  snapshot.frcComposite = computeFrcComposite(snapshot.frc);
  snapshot.iapComposite = computeIapComposite(snapshot.iap);
  snapshot.powerReadiness = computePowerReadiness(snapshot.frc, snapshot.iap);
}

} // namespace

FitnessReadView::FitnessReadView(const ThreadSafeFitnessData& data) : m_data(data) {}

auto FitnessReadView::snapshot() const -> FitnessSnapshot {
  return m_data.snapshot();
}

void ThreadSafeFitnessData::commitSnapshot(FRCMetrics frc, IAPMetrics iap) {
  m_snapshot.frc = frc;
  m_snapshot.iap = iap;
  enrichSnapshot(m_snapshot);
  ++m_snapshot.revision;
}

void ThreadSafeFitnessData::update_frc(FRCMetrics metrics) {
  std::scoped_lock lock(m_mutex);
  commitSnapshot(metrics, m_snapshot.iap);
}

void ThreadSafeFitnessData::update_iap(IAPMetrics metrics) {
  std::scoped_lock lock(m_mutex);
  commitSnapshot(m_snapshot.frc, metrics);
}

void ThreadSafeFitnessData::update(FRCMetrics frc, IAPMetrics iap) {
  std::scoped_lock lock(m_mutex);
  commitSnapshot(frc, iap);
}

auto ThreadSafeFitnessData::snapshot() const -> FitnessSnapshot {
  std::scoped_lock lock(m_mutex);
  return m_snapshot;
}

auto ThreadSafeFitnessData::read_view() const -> FitnessReadView {
  return FitnessReadView(*this);
}

auto validateFitnessScalar(float value, std::string_view fieldName) -> Result<float> {
  if (!std::isfinite(value)) {
    return Result<float>::err(std::string(fieldName) + " must be a finite number");
  }
  return Result<float>::ok(clampUnit(value));
}

auto validateBreathPhase(int value) -> Result<std::int8_t> {
  if (value < -1 || value > 1) {
    return Result<std::int8_t>::err("breath_phase must be -1, 0, or 1");
  }
  return Result<std::int8_t>::ok(static_cast<std::int8_t>(value));
}

auto computeFrcComposite(const FRCMetrics& frc) -> float {
  return clampUnit((frc.mobilityScore + frc.activeRangeScore + frc.controlScore) / 3.0F);
}

auto computeIapComposite(const IAPMetrics& iap) -> float {
  return clampUnit(iap.engagementScore * iap.confidence);
}

auto computePowerReadiness(const FRCMetrics& frc, const IAPMetrics& iap) -> float {
  const float frcComposite = computeFrcComposite(frc);
  const float iapComposite = computeIapComposite(iap);
  return clampUnit(frcComposite * 0.55F + iapComposite * 0.45F);
}

auto fitnessSnapshotToJson(const FitnessSnapshot& snapshot) -> nlohmann::json {
  return {
      {"revision", snapshot.revision},
      {"frc_composite", snapshot.frcComposite},
      {"iap_composite", snapshot.iapComposite},
      {"power_readiness", snapshot.powerReadiness},
      {"frc",
       {
           {"mobility_score", snapshot.frc.mobilityScore},
           {"active_range_score", snapshot.frc.activeRangeScore},
           {"control_score", snapshot.frc.controlScore},
       }},
      {"iap",
       {
           {"engagement_score", snapshot.iap.engagementScore},
           {"confidence", snapshot.iap.confidence},
           {"breath_phase", snapshot.iap.breathPhase},
       }},
      {"throw_catch_hints",
       {
           {"catch_radius_normalized",
            0.30F + snapshot.frc.controlScore * 0.75F},
           {"expected_power_multiplier",
            1.0F + snapshot.frcComposite * 0.40F + snapshot.iapComposite * 0.30F +
                snapshot.powerReadiness * 0.25F},
           {"breath_impulse_boost",
            snapshot.iap.breathPhase == 1   ? 1.12F
            : snapshot.iap.breathPhase == -1 ? 0.92F
                                             : 1.0F},
       }},
  };
}

} // namespace nexus::gameplay
