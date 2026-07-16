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

  // Dynamic camera (commit 6) — the viewport directs attention.
  camera: {
    followWeight: 0.45,      // TUNE(elijah) — how far the target tracks the player (0=center court, 1=lock)
    followLerp: 0.06,        // TUNE(elijah) — target smoothing per frame
    baseTargetY: 1.2,        // TUNE(elijah) — resting look height
    airborneLift: 0.55,      // TUNE(elijah) — extra target lift per meter of jump height (apex follow)
    fovStretchMax: 0.12,     // TUNE(elijah) — +12% FOV at full sprint
    fovLerp: 0.05,           // TUNE(elijah) — FOV smoothing per frame
  },

  // Sensory event bus (commit 5) — the synchronized "thud".
  sensory: {
    bigLandingVy: 3.5,       // TUNE(elijah) — |vy| at impact that counts as a BIG landing
    landShake: 0.12,         // TUNE(elijah) — camera shake intensity, normal landing
    slamShake: 0.35,         // TUNE(elijah) — camera shake intensity, dunk slam
    slamHitStopMs: 100,      // TUNE(elijah) — presentation freeze on the slam
    bigLandHitStopMs: 70,    // TUNE(elijah) — presentation freeze on big landings
    rumbleMs: 120,           // TUNE(elijah) — gamepad rumble duration
    crowdVolume: 0.7,        // TUNE(elijah)
  },

  // Dunk arc drive (hybrid anim↔physics blend — commit 4).
  dunkArc: {
    lockOnRadius: 4.5,       // TUNE(elijah) — max distance to hoop for a mid-air dunk lock-on
    rimApproachY: 1.35,      // TUNE(elijah) — feet height at rim contact (slam point)
    apexBoostM: 0.4,         // TUNE(elijah) — extra apex height above the higher endpoint
    durationMs: 620,         // TUNE(elijah) — drive time from trigger to rim
    rimStandoff: 0.55,       // TUNE(elijah) — stop this far in front of the rim center
  },

  // Karate match flow + impact feel.
  karate: {
    readyMs: 800,            // TUNE(elijah) — READY hold before countdown
    countdownMs: 3000,       // TUNE(elijah) — 3-2-1 before FIGHT
    koHitStopMs: 300,        // TUNE(elijah) — freeze on the KO hit (felt before announced)
    hitShake: 0.05,          // TUNE(elijah)
    heavyShake: 0.14,        // TUNE(elijah)
    koShake: 0.3,            // TUNE(elijah)
  },

  // Court bounds for free movement (Venice court, matches HOOP_POSITION space).
  court: {
    minX: -7, maxX: 7,
    minZ: -13.5, maxZ: 13,
  },
};

export default feelConfig;
