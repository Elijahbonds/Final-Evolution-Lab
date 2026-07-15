/**
 * feelConfig — shared, mode-agnostic feel tunables (Nexus Working Context).
 * Every number here is gameplay feel; all values // TUNE(elijah).
 * Modes read from this object; they never redefine these locally.
 */
export const feelConfig = {
  // Fixed-timestep simulation (Hz). Render is decoupled and interpolated.
  timestepHz: 60,            // TUNE(elijah)
  // Spiral-of-death clamp: never simulate more than this per render tick.
  maxAccumulatedMs: 250,     // TUNE(elijah)

  input: {
    bufferMs: 150,           // TUNE(elijah) — buffered-press window (landing jumps feel best ≥150)
  },

  movement: {
    runSpeed: 6.0,           // TUNE(elijah) — m/s at full stick deflection
    accel: 30.0,             // TUNE(elijah) — m/s² toward target velocity
    decel: 24.0,             // TUNE(elijah) — m/s² when stick released
  },

  jump: {
    impulse: 4.6,            // TUNE(elijah) — m/s vertical at takeoff (~1.2m apex)
    prepMs: 90,              // TUNE(elijah) — JumpPrep crouch before takeoff
    landingMs: 140,          // TUNE(elijah) — Landing recovery before next action
    approachSpeed: 1.5,      // TUNE(elijah) — grounded speed that reads as "approach"
  },

  // Variable gravity curve — velocity-driven (ascent light, peak hangs,
  // descent slams). This is the anti-floaty fix.
  gravity: {
    base: 9.81,
    ascentScale: 0.8,        // TUNE(elijah) — light rise
    peakScale: 0.35,         // TUNE(elijah) — ≈0 = hang-time; EXACTLY 0 never falls
    descentScale: 2.0,       // TUNE(elijah) — snaps down
    peakVelocityWindow: 0.9, // TUNE(elijah) — |vy| below this = "peak" (hang ≈ 0.5s at these values)
  },

  // Dunk arc drive (hybrid anim↔physics blend — commit 4).
  dunkArc: {
    lockOnRadius: 4.5,       // TUNE(elijah) — max distance to hoop for a mid-air dunk lock-on
    rimApproachY: 1.35,      // TUNE(elijah) — feet height at rim contact (slam point)
    apexBoostM: 0.4,         // TUNE(elijah) — extra apex height above the higher endpoint
    durationMs: 620,         // TUNE(elijah) — drive time from trigger to rim
    rimStandoff: 0.55,       // TUNE(elijah) — stop this far in front of the rim center
  },

  // Court bounds for free movement (Venice court, matches HOOP_POSITION space).
  court: {
    minX: -7, maxX: 7,
    minZ: -13.5, maxZ: 13,
  },
};

export default feelConfig;
