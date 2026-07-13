// Golf Closest to Pin — Links_Course 9-hole stroke-play simulator (golf)
#pragma once

#include "nexus/core/result.h"

#include <nlohmann/json.hpp>
#include <cstdint>
#include <string_view>

namespace nexus::gameplay {

enum class GolfHolePhase : std::uint8_t {
  kTeeBox = 0,   // about to hit from the tee
  kFairway = 1,  // approach shot(s) remaining
  kGreen = 2,    // putting
  kHoleOut = 3,  // ball in the cup
  kRoundOver = 4,
};

enum class ShotGrade : std::uint8_t {
  kHoleInOne = 0,   // tee shot goes in (par-3 only)
  kBirdie = 1,      // approach / putt sinks for -1
  kPar = 2,         // regulation strokes
  kBogey = 3,       // +1 over par
  kDoubleBogey = 4, // +2 or worse
};

class GolfClosestPinMode {
public:
  static constexpr int kTotalHoles = 9;
  static constexpr int kParPerHole = 4;   // par-4 layout
  static constexpr int kCoursePar = kTotalHoles * kParPerHole; // 36

  void reset();
  void update(double deltaSeconds);

  // tee_shot: power [0,1], alignment [-1 left … +1 right]
  auto teeShot(float power, float alignment) -> Result<nlohmann::json>;
  // approach: power [0,1], accuracy [0,1], club: "iron" | "wedge" | "chip"
  auto approach(float power, float accuracy, std::string_view club) -> Result<nlohmann::json>;
  // putt: power [0,1], line [-1 … +1]
  auto putt(float power, float line) -> Result<nlohmann::json>;

  [[nodiscard]] auto totalStrokes() const -> int32_t { return m_totalStrokes; }
  [[nodiscard]] auto holesCompleted() const -> int32_t { return m_holesCompleted; }
  [[nodiscard]] auto currentHole() const -> int32_t { return m_currentHole; }
  [[nodiscard]] auto isRoundOver() const -> bool { return m_phase == GolfHolePhase::kRoundOver; }
  [[nodiscard]] auto isVictory() const -> bool {
    return isRoundOver() && m_totalStrokes <= kCoursePar;
  }
  [[nodiscard]] auto stateJson() const -> nlohmann::json;

private:
  void advanceHole();
  [[nodiscard]] auto gradeHole(int32_t holeStrokes) const -> ShotGrade;
  [[nodiscard]] auto opponentStrokesForHole() const -> int32_t;

  GolfHolePhase m_phase{GolfHolePhase::kTeeBox};
  int32_t m_currentHole{1};
  int32_t m_holesCompleted{0};
  int32_t m_totalStrokes{0};
  int32_t m_holeStrokes{0};          // strokes taken on the current hole
  int32_t m_shotsToGreen{2};         // tee + 1 approach = on green (par-4 regulation)
  bool m_onGreen{false};
  int32_t m_opponentStrokes{0};
  int32_t m_birdies{0};
  int32_t m_pars{0};
  int32_t m_bogeys{0};
  float m_distanceToPin{100.0F};     // metres remaining on current hole
};

} // namespace nexus::gameplay
