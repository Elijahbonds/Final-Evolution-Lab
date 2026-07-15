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
    bufferMs: 120,           // TUNE(elijah) — consumed by commit 2 (input buffer)
  },

  movement: {
    runSpeed: 6.0,           // TUNE(elijah) — m/s at full stick deflection
    accel: 30.0,             // TUNE(elijah) — m/s² toward target velocity
    decel: 24.0,             // TUNE(elijah) — m/s² when stick released
  },

  // Variable gravity curve (consumed by commit 3 — jump controller).
  gravity: {
    base: 9.81,
    ascentScale: 0.8,        // TUNE(elijah)
    peakScale: 0.0,          // TUNE(elijah) — hang-time
    descentScale: 2.0,       // TUNE(elijah)
    peakVelocityWindow: 1.2, // TUNE(elijah) — |vy| below this = "peak"
  },

  // Court bounds for free movement (Venice court, matches HOOP_POSITION space).
  court: {
    minX: -7, maxX: 7,
    minZ: -13.5, maxZ: 13,
  },
};

export default feelConfig;
