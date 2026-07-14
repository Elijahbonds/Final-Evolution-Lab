// Direct unit tests for DunkContestMode.
// Tests drive the mode in isolation — no GameplayApplication or
// PhysicsWorld needed — covering:
//   A) scoring path (miss → 0, positive tap → > 0)
//   B) combo multiplier (chains and resets)
//   C) ghost difficulty (Easy vs Hard scoring pace)

#include "nexus/gameplay/dunk_contest_mode.h"

#include <cstdio>
#include <cstdlib>

using namespace nexus::gameplay;

// ── Helpers ──────────────────────────────────────────────────────────────────

namespace {

void require(bool condition, const char* message) {
  if (!condition) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    std::exit(1);
  }
}

// Advance the mode by `steps` ticks of 0.05 s.
void pump(DunkContestMode& mode, const ArcadePhysicsParams& physics, int steps) {
  for (int i = 0; i < steps; ++i) {
    mode.update(0.05, physics);
  }
}

// Drive one full dunk cycle from kFreeDribble back to kFreeDribble.
//
// tapAtAirborneStep: if >= 0, call onApexTap() after that many kAirborne
//   update ticks. With power=1.0 and default physics the QTE window center
//   is near tick 8 (≈ 0.40 s, well inside the Perfect zone).
//   Pass -1 to skip the tap entirely (guaranteed kMiss).
void doFullDunk(DunkContestMode& mode, const ArcadePhysicsParams& physics,
                int tapAtAirborneStep = -1) {
  (void)mode.onChargeBegin();
  (void)mode.onChargeRelease(1.0F);

  // Reach kAirborne: kLaunch needs >= 0.15 s; 4 ticks × 0.05 s = 0.20 s.
  pump(mode, physics, 4);

  // Drive through kAirborne.  kPhaseTimer timeout is 1.2 s (24 ticks).
  // Air time with power=1.0 is ~2.2 s, so the timer fires first.
  bool tapped = false;
  for (int step = 0; step < 30; ++step) {
    if (mode.phase() != DunkPhase::kAirborne) break;
    if (!tapped && tapAtAirborneStep >= 0 && step == tapAtAirborneStep) {
      (void)mode.onApexTap();
      tapped = true;
    }
    mode.update(0.05, physics);
  }

  // Settle through kScored (0.5 s) back to kFreeDribble.
  pump(mode, physics, 12);
}

} // namespace

// ── A: Scoring path ──────────────────────────────────────────────────────────

// A1: Completing an airborne phase without tapping (kMiss) must score 0.
void dunk_miss_scores_zero() {
  DunkContestMode mode;
  ArcadePhysicsParams physics;
  mode.reset();

  doFullDunk(mode, physics, /*tapAtAirborneStep=*/-1);

  require(mode.playerScore() == 0, "miss: player score remains 0");
  require(mode.comboCount()  == 0, "miss: combo count remains 0");
  require(mode.comboMultiplier() == 1.0F, "miss: multiplier remains 1.0");
  require(!mode.dunkHistory().empty(), "miss: dunk recorded in history");
  require(mode.dunkHistory().back().points == 0, "miss: dunk history entry has 0 points");
}

// A2: Tapping near the QTE window centre must produce a positive score.
// With power=1.0 and default physics, tick 8 from entering kAirborne
// lands within the Perfect zone (delta ≈ 0.021 < 0.10 threshold).
void dunk_perfect_tap_scores_positive() {
  DunkContestMode mode;
  ArcadePhysicsParams physics;
  mode.reset();

  doFullDunk(mode, physics, /*tapAtAirborneStep=*/8);

  require(mode.playerScore() > 0,  "perfect tap: positive score");
  require(!mode.dunkHistory().empty(), "perfect tap: dunk recorded");
  require(mode.dunkHistory().back().points > 0, "perfect tap: history entry > 0");
}

// A3: A miss after a scoring dunk does not subtract from the running total.
void dunk_miss_does_not_subtract_score() {
  DunkContestMode mode;
  ArcadePhysicsParams physics;
  mode.reset();

  doFullDunk(mode, physics, /*tapAtAirborneStep=*/8);  // score something
  const int scoreAfterFirst = mode.playerScore();
  require(scoreAfterFirst > 0, "first dunk scored");

  doFullDunk(mode, physics, /*tapAtAirborneStep=*/-1); // miss
  require(mode.playerScore() == scoreAfterFirst, "miss does not reduce score");
}

// ── B: Combo multiplier ───────────────────────────────────────────────────────

// B1: Two consecutive perfect dunks grow the combo count and multiplier.
void combo_grows_on_consecutive_perfect_dunks() {
  DunkContestMode mode;
  ArcadePhysicsParams physics;
  mode.reset();

  doFullDunk(mode, physics, 8);
  require(mode.comboCount() == 1, "combo count 1 after first perfect");
  require(mode.comboMultiplier() > 1.0F, "multiplier > 1 after first perfect");

  doFullDunk(mode, physics, 8);
  require(mode.comboCount() == 2, "combo count 2 after second perfect");
  require(mode.comboMultiplier() > 1.0F + 0.20F, "multiplier grows after second perfect");
}

// B2: A miss after a combo chain resets both count and multiplier.
void combo_resets_after_miss() {
  DunkContestMode mode;
  ArcadePhysicsParams physics;
  mode.reset();

  doFullDunk(mode, physics, 8);
  doFullDunk(mode, physics, 8);
  require(mode.comboCount() >= 2, "combo built before miss");

  doFullDunk(mode, physics, /*tapAtAirborneStep=*/-1); // miss
  require(mode.comboCount()      == 0,   "miss resets combo count to 0");
  require(mode.comboMultiplier() == 1.0F, "miss resets multiplier to 1.0");
}

// B3: Multiplier is capped at ArcadePhysicsParams::maxComboMultiplier.
void combo_multiplier_caps_at_max() {
  DunkContestMode mode;
  ArcadePhysicsParams physics; // maxComboMultiplier default = 2.0
  mode.reset();

  // Enough perfect dunks to saturate the cap (ceil((2.0-1.0)/0.25) = 4).
  for (int i = 0; i < 10; ++i) {
    if (mode.isMatchComplete()) break;
    doFullDunk(mode, physics, 8);
  }

  require(mode.comboMultiplier() <= physics.maxComboMultiplier,
          "multiplier never exceeds maxComboMultiplier");
}

// B4: Combo state is cleared by reset().
void combo_state_clears_on_reset() {
  DunkContestMode mode;
  ArcadePhysicsParams physics;
  mode.reset();

  doFullDunk(mode, physics, 8);
  require(mode.comboCount() > 0, "combo built before reset");

  mode.reset();
  require(mode.comboCount()      == 0,   "reset clears combo count");
  require(mode.comboMultiplier() == 1.0F, "reset clears combo multiplier");
}

// ── C: Ghost difficulty ────────────────────────────────────────────────────────

// C1: Hard ghost accumulates more points than Easy ghost over the same time.
void ghost_hard_scores_faster_than_easy() {
  ArcadePhysicsParams physics;

  DunkContestMode modeEasy;
  modeEasy.reset();
  modeEasy.setGhostDifficulty(GhostDifficulty::kEasy);

  DunkContestMode modeHard;
  modeHard.reset();
  modeHard.setGhostDifficulty(GhostDifficulty::kHard);

  // Pump through 5 ghost-dunk intervals (kGhostDunkInterval = 7 s each).
  // 35 s / 0.05 s per tick = 700 ticks.
  for (int i = 0; i < 700; ++i) {
    modeEasy.update(0.05, physics);
    modeHard.update(0.05, physics);
  }

  require(modeHard.opponentScore() > modeEasy.opponentScore(),
          "hard ghost accumulates more points than easy ghost");
}

// C2: Normal ghost scores somewhere between Easy and Hard.
void ghost_normal_is_between_easy_and_hard() {
  ArcadePhysicsParams physics;

  DunkContestMode easy, normal, hard;
  easy.reset();   easy.setGhostDifficulty(GhostDifficulty::kEasy);
  normal.reset(); normal.setGhostDifficulty(GhostDifficulty::kNormal);
  hard.reset();   hard.setGhostDifficulty(GhostDifficulty::kHard);

  for (int i = 0; i < 700; ++i) {
    easy.update(0.05, physics);
    normal.update(0.05, physics);
    hard.update(0.05, physics);
  }

  require(easy.opponentScore()   <= normal.opponentScore(),
          "easy ghost score <= normal ghost score");
  require(normal.opponentScore() <= hard.opponentScore(),
          "normal ghost score <= hard ghost score");
}

// C3: Ghost is suppressed when a remote opponent is registered.
void ghost_disabled_when_remote_opponent_set() {
  ArcadePhysicsParams physics;

  RemotePlayerState remote;
  remote.dunkScore = 5;

  DunkContestMode mode;
  mode.reset();
  mode.setRemoteOpponent(&remote);

  // Pump 5 ghost intervals (5 × 7 s = 35 s = 700 ticks).
  // Each ghost tick syncs m_opponentScore from remote.dunkScore.
  for (int i = 0; i < 700; ++i) mode.update(0.05, physics);

  require(mode.opponentScore() == 5,
          "opponent score mirrors remote state, not ghost AI");

  // Update remote score and pump past the next ghost interval (≤ 7 s) to sync.
  // After 700 ticks the ghost timer was last reset near t=35 s; at most
  // 7 s = 140 ticks are needed for the next fire.
  remote.dunkScore = 12;
  for (int i = 0; i < 150; ++i) mode.update(0.05, physics);

  require(mode.opponentScore() == 12,
          "opponent score updates when remote state changes");
}

// ── Off-board Windmill outscores auto-selected Signature ─────────────────────

// Same power and timing — only style multiplier differs
// (kOffBackboardWindmill = 2.2×, kSignature = 1.5×).
void windmill_outscores_auto_signature_style() {
  ArcadePhysicsParams physics;

  auto runDunk = [&](bool preSelectWindmill) -> int {
    DunkContestMode mode;
    mode.reset();
    if (preSelectWindmill) {
      (void)mode.selectSignatureDunk(DunkStyle::kOffBackboardWindmill);
    }
    doFullDunk(mode, physics, 8);
    return mode.playerScore();
  };

  const int autoSignatureScore = runDunk(false); // kSignature (1.5×) via power=1.0
  const int windmillScore      = runDunk(true);  // kOffBackboardWindmill (2.2×)

  require(windmillScore > autoSignatureScore,
          "off-board windmill (2.2x) outscores auto-selected signature (1.5x)");
}

// ── main ──────────────────────────────────────────────────────────────────────

int main() {
  // A: Scoring path
  dunk_miss_scores_zero();
  dunk_perfect_tap_scores_positive();
  dunk_miss_does_not_subtract_score();

  // B: Combo multiplier
  combo_grows_on_consecutive_perfect_dunks();
  combo_resets_after_miss();
  combo_multiplier_caps_at_max();
  combo_state_clears_on_reset();

  // C: Ghost difficulty
  ghost_hard_scores_faster_than_easy();
  ghost_normal_is_between_easy_and_hard();
  ghost_disabled_when_remote_opponent_set();

  // Style ordering
  windmill_outscores_auto_signature_style();

  std::puts("PASS: all dunk_contest_test cases passed");
  return 0;
}
