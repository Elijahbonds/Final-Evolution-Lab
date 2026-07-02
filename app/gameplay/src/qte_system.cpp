#include "nexus/gameplay/qte_system.h"

#include <algorithm>
#include <cmath>

namespace nexus::gameplay {

namespace {

constexpr float kPerfectZone = 0.20F;
constexpr float kGreatZone = 0.15F;
constexpr float kGoodZone = 0.25F;

} // namespace

void QTESystem::startApexWindow(float windowSeconds) {
  m_active = true;
  m_windowSeconds = std::max(windowSeconds, 0.05F);
  m_elapsedSeconds = 0.0F;
}

void QTESystem::update(double deltaSeconds) {
  if (!m_active) {
    return;
  }
  m_elapsedSeconds += static_cast<float>(deltaSeconds);
  if (m_elapsedSeconds >= m_windowSeconds) {
    m_active = false;
  }
}

auto QTESystem::onTap() -> QTEGrade {
  if (!m_active || m_windowSeconds <= 0.0F) {
    return QTEGrade::kMiss;
  }

  m_active = false;
  const float center = m_windowSeconds * 0.5F;
  const float delta = std::abs(m_elapsedSeconds - center) / m_windowSeconds;

  if (delta <= kPerfectZone * 0.5F) {
    return QTEGrade::kPerfect;
  }
  if (delta <= kGreatZone) {
    return QTEGrade::kGreat;
  }
  if (delta <= kGoodZone) {
    return QTEGrade::kGood;
  }
  if (delta <= 0.45F) {
    return QTEGrade::kOk;
  }
  return QTEGrade::kMiss;
}

auto QTESystem::gradeLabel(QTEGrade grade) -> std::string_view {
  switch (grade) {
  case QTEGrade::kPerfect:
    return "PERFECT";
  case QTEGrade::kGreat:
    return "GREAT";
  case QTEGrade::kGood:
    return "GOOD";
  case QTEGrade::kOk:
    return "OK";
  case QTEGrade::kMiss:
    return "MISS";
  }
  return "MISS";
}

auto QTESystem::timingBonus(QTEGrade grade) -> float {
  switch (grade) {
  case QTEGrade::kPerfect:
    return 3.0F;
  case QTEGrade::kGreat:
    return 2.0F;
  case QTEGrade::kGood:
    return 1.0F;
  case QTEGrade::kOk:
    return 0.5F;
  case QTEGrade::kMiss:
    return 0.0F;
  }
  return 0.0F;
}

} // namespace nexus::gameplay
