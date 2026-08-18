// Spec §2.2 / Appendix C — apex tap QTE grading
#pragma once

#include <string_view>
#include <cstdint>

namespace nexus::gameplay {

enum class QTEGrade : std::uint8_t {
  kPerfect = 0,
  kGreat = 1,
  kGood = 2,
  kOk = 3,
  kMiss = 4,
};

class QTESystem {
public:
  void startApexWindow(float windowSeconds);
  void update(double deltaSeconds);
  [[nodiscard]] auto onTap() -> QTEGrade;
  [[nodiscard]] auto isActive() const -> bool { return m_active; }
  [[nodiscard]] static auto gradeLabel(QTEGrade grade) -> std::string_view;
  [[nodiscard]] static auto timingBonus(QTEGrade grade) -> float;

private:
  bool m_active{false};
  float m_windowSeconds{0.0F};
  float m_elapsedSeconds{0.0F};
};

} // namespace nexus::gameplay
