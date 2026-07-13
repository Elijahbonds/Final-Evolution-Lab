// Golf Closest to Pin — Links_Course 9-hole stroke-play simulator (golf)
#include "nexus/gameplay/golf_closest_pin_mode.h"

#include <algorithm>
#include <cmath>
#include <cstdint>

namespace nexus::gameplay {

namespace {

constexpr float kPowerStraightMin = 0.65F;
constexpr float kAlignmentTolerance = 0.30F;
constexpr float kPuttSinkPowerMin = 0.30F;
constexpr float kPuttSinkPowerMax = 0.85F;
constexpr float kPuttLineTolerance = 0.25F;
constexpr float kApproachOnGreenAccuracy = 0.60F;

} // namespace

void GolfClosestPinMode::reset() {
  m_phase = GolfHolePhase::kTeeBox;
  m_currentHole = 1;
  m_holesCompleted = 0;
  m_totalStrokes = 0;
  m_holeStrokes = 0;
  m_shotsToGreen = 2;
  m_onGreen = false;
  m_opponentStrokes = 0;
  m_birdies = 0;
  m_pars = 0;
  m_bogeys = 0;
  m_distanceToPin = 100.0F;
}

void GolfClosestPinMode::update(double /*deltaSeconds*/) {
  // Shot phases are event-driven; no time-based transitions
}

auto GolfClosestPinMode::teeShot(float power, float alignment) -> Result<nlohmann::json> {
  if (m_phase == GolfHolePhase::kRoundOver) {
    return Result<nlohmann::json>::err("round already over");
  }
  if (m_phase != GolfHolePhase::kTeeBox) {
    return Result<nlohmann::json>::err("not on the tee box");
  }

  const float p = std::clamp(power, 0.0F, 1.0F);
  const float a = std::clamp(alignment, -1.0F, 1.0F);
  ++m_holeStrokes;
  ++m_totalStrokes;

  const bool straight = std::abs(a) <= kAlignmentTolerance;
  const bool powerful = p >= kPowerStraightMin;

  if (straight && p >= 0.95F) {
    // Rare hole-in-one chance on a perfect drive to pin
    m_distanceToPin = 0.0F;
    m_phase = GolfHolePhase::kHoleOut;
    advanceHole();
    nlohmann::json payload = stateJson();
    payload["tee_shot"] = {{"power", p}, {"alignment", a}, {"result", "hole_in_one"}};
    payload["agent_envelope"] = {{"command", "fel.golf.tee_shot"}, {"result", "hole_in_one"}};
    return Result<nlohmann::json>::ok(std::move(payload));
  }

  // Good drive lands near the green; errant drive adds distance
  if (straight && powerful) {
    m_distanceToPin = 20.0F;  // short iron range
    m_phase = GolfHolePhase::kFairway;
  } else if (powerful) {
    m_distanceToPin = 35.0F;  // off-centre but long
    m_phase = GolfHolePhase::kFairway;
  } else {
    m_distanceToPin = 60.0F;  // short drive
    m_phase = GolfHolePhase::kFairway;
  }

  nlohmann::json payload = stateJson();
  payload["tee_shot"] = {
      {"power", p},
      {"alignment", a},
      {"straight", straight},
      {"distance_to_pin", m_distanceToPin},
      {"result", straight && powerful ? "great_drive" : powerful ? "long_drive" : "short_drive"},
  };
  payload["agent_envelope"] = {
      {"command", "fel.golf.tee_shot"},
      {"distance_to_pin", m_distanceToPin},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto GolfClosestPinMode::approach(float power, float accuracy, std::string_view club)
    -> Result<nlohmann::json> {
  if (m_phase == GolfHolePhase::kRoundOver) {
    return Result<nlohmann::json>::err("round already over");
  }
  if (m_phase == GolfHolePhase::kTeeBox) {
    return Result<nlohmann::json>::err("take tee shot first");
  }
  if (m_phase == GolfHolePhase::kGreen || m_phase == GolfHolePhase::kHoleOut) {
    return Result<nlohmann::json>::err("already on the green");
  }

  const float p = std::clamp(power, 0.0F, 1.0F);
  const float acc = std::clamp(accuracy, 0.0F, 1.0F);
  ++m_holeStrokes;
  ++m_totalStrokes;

  const bool chipShot = (club == "chip" || club == "wedge");
  const bool accurate = acc >= kApproachOnGreenAccuracy;

  if (accurate && p >= 0.70F) {
    // Ball lands on the green close to pin
    m_distanceToPin = chipShot ? 1.5F : 3.0F;
    m_phase = GolfHolePhase::kGreen;
    m_onGreen = true;
  } else if (accurate) {
    m_distanceToPin = chipShot ? 4.0F : 7.0F;
    m_phase = GolfHolePhase::kGreen;
    m_onGreen = true;
  } else {
    // Miss the green — need another approach
    m_distanceToPin = 15.0F;
    // Stay in kFairway for one more chip
  }

  nlohmann::json payload = stateJson();
  payload["approach"] = {
      {"power", p},
      {"accuracy", acc},
      {"club", std::string(club)},
      {"on_green", m_onGreen},
      {"distance_to_pin", m_distanceToPin},
  };
  payload["agent_envelope"] = {
      {"command", "fel.golf.approach"},
      {"club", std::string(club)},
      {"on_green", m_onGreen},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto GolfClosestPinMode::putt(float power, float line) -> Result<nlohmann::json> {
  if (m_phase == GolfHolePhase::kRoundOver) {
    return Result<nlohmann::json>::err("round already over");
  }
  if (m_phase != GolfHolePhase::kGreen) {
    return Result<nlohmann::json>::err("not on the green");
  }

  const float p = std::clamp(power, 0.0F, 1.0F);
  const float l = std::clamp(line, -1.0F, 1.0F);
  ++m_holeStrokes;
  ++m_totalStrokes;

  const bool goodLine = std::abs(l) <= kPuttLineTolerance;
  const bool goodPower = p >= kPuttSinkPowerMin && p <= kPuttSinkPowerMax;
  const bool closePutt = m_distanceToPin <= 2.0F;

  bool holed = false;
  if (goodLine && goodPower) {
    holed = true;
  } else if (closePutt && goodLine) {
    // Tap-in — always sinks
    holed = true;
  }

  if (holed) {
    m_distanceToPin = 0.0F;
    m_phase = GolfHolePhase::kHoleOut;
    const ShotGrade grade = gradeHole(m_holeStrokes);
    if (grade == ShotGrade::kBirdie || grade == ShotGrade::kHoleInOne) {
      ++m_birdies;
    } else if (grade == ShotGrade::kPar) {
      ++m_pars;
    } else {
      ++m_bogeys;
    }
    // Opponent takes regulation par + small variance
    m_opponentStrokes += opponentStrokesForHole();
    advanceHole();
  } else {
    // Missed — ball closer to pin on miss
    m_distanceToPin = std::max(0.5F, m_distanceToPin * 0.5F);
  }

  nlohmann::json payload = stateJson();
  payload["putt"] = {
      {"power", p},
      {"line", l},
      {"holed", holed},
      {"distance_to_pin", m_distanceToPin},
  };
  payload["agent_envelope"] = {
      {"command", "fel.golf.putt"},
      {"holed", holed},
      {"total_strokes", m_totalStrokes},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

void GolfClosestPinMode::advanceHole() {
  ++m_holesCompleted;
  m_holeStrokes = 0;
  m_onGreen = false;
  m_distanceToPin = 100.0F;
  if (m_holesCompleted >= kTotalHoles) {
    m_phase = GolfHolePhase::kRoundOver;
  } else {
    ++m_currentHole;
    m_phase = GolfHolePhase::kTeeBox;
  }
}

auto GolfClosestPinMode::gradeHole(int32_t holeStrokes) const -> ShotGrade {
  if (holeStrokes == 1) {
    return ShotGrade::kHoleInOne;
  }
  if (holeStrokes <= kParPerHole - 1) {
    return ShotGrade::kBirdie;
  }
  if (holeStrokes == kParPerHole) {
    return ShotGrade::kPar;
  }
  if (holeStrokes == kParPerHole + 1) {
    return ShotGrade::kBogey;
  }
  return ShotGrade::kDoubleBogey;
}

auto GolfClosestPinMode::opponentStrokesForHole() const -> int32_t {
  // Opponent plays to par with occasional birdie driven by hole number parity
  return (m_currentHole % 3 == 0) ? kParPerHole - 1 : kParPerHole;
}

auto GolfClosestPinMode::stateJson() const -> nlohmann::json {
  return {
      {"phase", static_cast<int>(m_phase)},
      {"current_hole", m_currentHole},
      {"holes_completed", m_holesCompleted},
      {"total_strokes", m_totalStrokes},
      {"hole_strokes", m_holeStrokes},
      {"course_par", kCoursePar},
      {"score_vs_par", m_totalStrokes - (m_holesCompleted * kParPerHole)},
      {"opponent_strokes", m_opponentStrokes},
      {"birdies", m_birdies},
      {"pars", m_pars},
      {"bogeys", m_bogeys},
      {"on_green", m_onGreen},
      {"distance_to_pin", m_distanceToPin},
      {"round_over", isRoundOver()},
      {"victory", isVictory()},
      {"release_state", "validate_only"},
  };
}

} // namespace nexus::gameplay
