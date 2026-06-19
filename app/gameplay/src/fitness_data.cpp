// File: app/gameplay/src/fitness_data.cpp
// Part of: Final Evolution Lab (FEL) Game Logic
// Spec: 02 Fitness Data Schema, 10 Phase 2 Biometric Integration
#include "nexus/gameplay/fitness_data.h"

namespace nexus::gameplay {

FitnessReadView::FitnessReadView(const ThreadSafeFitnessData& data) : m_data(data) {}

auto FitnessReadView::snapshot() const -> FitnessSnapshot {
  return m_data.snapshot();
}

void ThreadSafeFitnessData::update_frc(FRCMetrics metrics) {
  std::scoped_lock lock(m_mutex);
  m_snapshot.frc = metrics;
  ++m_snapshot.revision;
}

void ThreadSafeFitnessData::update_iap(IAPMetrics metrics) {
  std::scoped_lock lock(m_mutex);
  m_snapshot.iap = metrics;
  ++m_snapshot.revision;
}

void ThreadSafeFitnessData::update(FRCMetrics frc, IAPMetrics iap) {
  std::scoped_lock lock(m_mutex);
  m_snapshot.frc = frc;
  m_snapshot.iap = iap;
  ++m_snapshot.revision;
}

auto ThreadSafeFitnessData::snapshot() const -> FitnessSnapshot {
  std::scoped_lock lock(m_mutex);
  return m_snapshot;
}

auto ThreadSafeFitnessData::read_view() const -> FitnessReadView {
  return FitnessReadView(*this);
}

} // namespace nexus::gameplay
