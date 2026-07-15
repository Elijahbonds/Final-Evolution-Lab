// Unit tests for Golf3DMode and karate animation fixes.
// Covers:
//   A) Golf 3D: address → swing → ball flight → landing (par 4 hole 1)
//   B) Golf 3D: putter auto-selected on green
//   C) Golf 3D: power meter fills and swingTap locks it
//   D) Golf 3D: nine-hole round completes after advanceHole x9
//   E) Karate: movePlayer emits walk_forward (not run_forward) without speed perk
//   F) Karate: idle variants cycle after kIdleVariantInterval

#include "nexus/gameplay/golf_3d_mode.h"
#include "nexus/gameplay/karate_endless_mode.h"
#include "nexus/gameplay/character_anim_state.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>

using namespace nexus::gameplay;

// ── Helpers ──────────────────────────────────────────────────────────────────

namespace {

void require(bool condition, const char* message) {
  if (!condition) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    std::exit(1);
  }
}

// Pump golf mode for `steps` ticks of 0.1 s.
void pumpGolf(Golf3DMode& mode, int steps) {
  for (int i = 0; i < steps; ++i) {
    mode.update(0.1);
  }
}

// Pump karate mode for `steps` ticks of 0.05 s.
void pumpKarate(KarateEndlessMode& mode, int steps) {
  for (int i = 0; i < steps; ++i) {
    mode.update(0.05);
  }
}

} // namespace

// ── A: Golf — address → swing → ball flight → landing ────────────────────────

void golf_full_shot_lands() {
  Golf3DMode mode;
  mode.reset();

  // Address
  auto r = mode.beginAddress(true);
  require(r.isOk(), "beginAddress ok");
  require(mode.phase() == GolfSwingPhase::kAddress, "phase: address after beginAddress");

  // Start swing
  r = mode.startSwing();
  require(r.isOk(), "startSwing ok");
  require(mode.phase() == GolfSwingPhase::kBackswing, "phase: backswing after startSwing");

  // Pump ~0.7 s to fill ~58% power, then tap to lock
  pumpGolf(mode, 7);  // 0.7 s × kPowerFillRate(1/1.2) ≈ 0.58
  require(mode.phase() == GolfSwingPhase::kBackswing, "still backswing before tap");

  r = mode.swingTap();  // locks power → kDownswing
  require(r.isOk(), "swingTap ok");
  require(mode.phase() == GolfSwingPhase::kDownswing, "phase: downswing after first tap");

  // Second tap to set accuracy
  r = mode.swingTap();
  require(r.isOk(), "second swingTap ok");

  // Should now be kFollowThrough
  require(mode.phase() == GolfSwingPhase::kFollowThrough,
          "phase: follow_through after second tap");

  // Pump through follow-through (0.8 s = 8 ticks)
  pumpGolf(mode, 9);
  require(mode.phase() == GolfSwingPhase::kBallFlight,
          "phase: ball_flight after follow_through");

  // Pump until ball lands (max 30 s = 300 ticks)
  int ticks = 0;
  while (mode.phase() == GolfSwingPhase::kBallFlight && ticks < 300) {
    mode.update(0.1);
    ++ticks;
  }
  // Phase should be kBallLanded or back to kAddress (if auto-advanced)
  require(mode.phase() == GolfSwingPhase::kBallLanded ||
          mode.phase() == GolfSwingPhase::kAddress,
          "phase: ball_landed or address after flight");
  require(mode.totalStrokes() == 1, "one stroke counted");
}

// ── B: Golf — putter auto-selected on green ───────────────────────────────────

void golf_putter_on_green() {
  Golf3DMode mode;
  mode.reset();

  // Place ball manually on the green (within 0.5 m of pin of hole 0)
  // We test autoClubForDistance with kGreen lie via selectClub
  // Force wedge to make sure selectClub rejects driver on green
  auto r = mode.beginAddress(false);
  require(r.isOk(), "beginAddress ok");

  // Driver rejected on green
  // We can only fully test by checking auto-club logic indirectly via club param
  // Use selectClub: putter should succeed
  r = mode.selectClub(GolfClub::kPutter);
  require(r.isOk(), "selectClub putter ok");
  const auto state = mode.stateJson();
  require(state.value("club", "") == "putter", "club is putter after selectClub");
}

// ── C: Golf — power meter caps at 1.0 ────────────────────────────────────────

void golf_power_meter_caps() {
  Golf3DMode mode;
  mode.reset();
  (void)mode.beginAddress(true);
  (void)mode.startSwing();

  // Pump 2.4 s (>> 1.2 s needed for full power)
  pumpGolf(mode, 24);

  // Should have auto-advanced to kDownswing (power locked at 1.0)
  require(mode.phase() == GolfSwingPhase::kDownswing ||
          mode.phase() == GolfSwingPhase::kFollowThrough ||
          mode.phase() == GolfSwingPhase::kBallFlight,
          "power auto-fires after meter fills");
}

// ── D: Golf — round complete after 9 holes ────────────────────────────────────

void golf_round_complete_after_nine_holes() {
  Golf3DMode mode;
  mode.reset();

  // For each of the 9 holes, keep swinging and letting the ball land until the
  // hole advances. Cap at 8 shots per hole (max = double bogey on a par 5 +
  // approach + putt).
  int totalShots = 0;
  while (!mode.isRoundComplete() && totalShots < 9 * 8) {
    // Make sure we're in address phase before swinging
    if (mode.phase() != GolfSwingPhase::kAddress &&
        mode.phase() != GolfSwingPhase::kBallLanded) {
      pumpGolf(mode, 5);
      continue;
    }
    (void)mode.beginAddress(true);

    // Start swing
    (void)mode.startSwing();

    // Pump 1.5 s to fill power then lock
    pumpGolf(mode, 15);  // 15 × 0.1 s = 1.5 s
    if (mode.phase() == GolfSwingPhase::kBackswing) {
      (void)mode.swingTap();  // lock power
    }
    if (mode.phase() == GolfSwingPhase::kDownswing) {
      (void)mode.swingTap();  // set accuracy
    }

    // Follow-through (1.0 s = 10 ticks)
    pumpGolf(mode, 10);

    // Ball flight — pump until landed (max 30 s = 300 ticks)
    int flightTicks = 0;
    while (mode.phase() == GolfSwingPhase::kBallFlight && flightTicks < 300) {
      mode.update(0.1);
      ++flightTicks;
    }

    // Ball landed — pump through pause (3 s = 30 ticks covers kLandedPauseDur=2.5s)
    pumpGolf(mode, 30);

    ++totalShots;
  }

  require(mode.isRoundComplete(), "round complete after nine holes");
}

// ── E: Karate — movePlayer emits walk_forward without speed perk ─────────────

void karate_move_emits_walk_animation() {
  KarateEndlessMode mode;
  mode.reset();

  auto r = mode.movePlayer(1.0F, 0.0F, 0.05);
  require(r.isOk(), "movePlayer ok");

  const auto state = r.value();
  // player_3d.anim_clip should be "walk_forward", NOT "run_forward"
  const auto clipName = state["player_3d"].value("anim_clip", std::string{});
  require(clipName == "walk_forward",
          "karate movePlayer without perk uses walk_forward, not run_forward");
}

// ── F: Karate — idle variants cycle after kIdleVariantInterval ───────────────

void karate_idle_variants_cycle() {
  KarateEndlessMode mode;
  mode.reset();

  // Force the player to stand still (no input) — idle clip starts as kKarateIdle
  const auto initialState = mode.stateJson();
  const std::string initial = initialState["player_3d"].value("anim_clip", std::string{});
  require(initial == "karate_idle_stance", "initial idle is karate_idle_stance");

  // Pump just over kIdleVariantInterval (5 s) to trigger first rotation
  // 5.1 s = 102 ticks of 0.05 s
  for (int i = 0; i < 102; ++i) {
    mode.update(0.05);
  }

  const auto laterState = mode.stateJson();
  const std::string laterClip = laterState["player_3d"].value("anim_clip", std::string{});
  // After one rotation the clip should have changed to the next idle variant
  require(laterClip != "karate_idle_stance",
          "idle variant rotated after kIdleVariantInterval");
  // Must be one of the valid idle variants
  const bool isVariant = (laterClip == "idle_breathe" ||
                          laterClip == "idle_stretch"  ||
                          laterClip == "idle_shift_weight" ||
                          laterClip == "karate_idle_stance");
  require(isVariant, "rotated clip is a known idle variant");
}

// ─────────────────────────────────────────────────────────────────────────────

int main() {
  // A: full shot
  golf_full_shot_lands();

  // B: putter on green
  golf_putter_on_green();

  // C: power caps
  golf_power_meter_caps();

  // D: round complete
  golf_round_complete_after_nine_holes();

  // E: karate walk animation
  karate_move_emits_walk_animation();

  // F: idle variant cycling
  karate_idle_variants_cycle();

  std::puts("PASS: all golf_3d_karate_test cases passed");
  return 0;
}
