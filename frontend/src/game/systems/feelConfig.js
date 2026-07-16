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
    // Over-shoulder locomotion + spacing (CoD-zombies/soulslike spacing feel)
    moveSpeed: 2.6,          // TUNE(elijah) — m/s at full stick
    moveAccel: 18,           // TUNE(elijah)
    moveDecel: 20,           // TUNE(elijah)
    arenaBound: 3.6,         // TUNE(elijah) — tatami half-extent
    strikeRangeM: 1.7,       // TUNE(elijah) — player strikes land within this
    aiRangeM: 2.0,           // TUNE(elijah) — AI attacks land within this
    pursuitSpeed: 1.6,       // TUNE(elijah) — opponent closes distance at this speed
    pursuitStopM: 1.3,       // TUNE(elijah) — opponent settles HERE: inside both strike ranges
  },

  // Skateboard ride/carve archetype (endless Venice strip).
  skate: {
    cruiseSpeed: 6.0,        // TUNE(elijah) — starting forward speed m/s
    minSpeed: 3.0,           // TUNE(elijah)
    maxSpeed: 9.5,           // TUNE(elijah)
    pumpAccel: 3.5,          // TUNE(elijah) — stick-up speed gain /s
    brakeDecel: 5.0,         // TUNE(elijah) — stick-down speed loss /s
    steerSpeed: 4.0,         // TUNE(elijah) — lateral m/s at full stick
    laneHalfWidth: 4.0,      // TUNE(elijah)
    ollieImpulse: 3.4,       // TUNE(elijah) — vertical m/s (gravity curve applies)
    stripLength: 60,         // TUNE(elijah) — loop length before wrap
    rail: {
      x: 2.2, y: 0.55,       // TUNE(elijah) — rail position/height
      zStart: -18, zEnd: -38,
      lockRadius: 1.6,       // TUNE(elijah) — grind lock-on distance (airborne)
      grindSpeed: 7.5,       // TUNE(elijah)
      pointsPerSec: 25,      // TUNE(elijah)
    },
    olliePoints: 10,         // TUNE(elijah)
  },

  // Snowboard skin (ride/carve — steeper, faster, longer rail = a rock ledge).
  snowboard: {
    cruiseSpeed: 8.0, minSpeed: 4.5, maxSpeed: 13.0,          // TUNE(elijah)
    pumpAccel: 4.5, brakeDecel: 6.0, steerSpeed: 5.0,          // TUNE(elijah)
    laneHalfWidth: 5.0, ollieImpulse: 3.8, stripLength: 70,    // TUNE(elijah)
    rail: { x: -2.4, y: 0.5, zStart: -20, zEnd: -46, lockRadius: 1.7, grindSpeed: 9.0, pointsPerSec: 28 },
    olliePoints: 12,
  },

  // Surf skin (ride/carve — slower, wide lane, the "rail" is the wave lip trim line).
  surf: {
    cruiseSpeed: 5.0, minSpeed: 2.5, maxSpeed: 8.0,            // TUNE(elijah)
    pumpAccel: 3.0, brakeDecel: 4.0, steerSpeed: 4.5,           // TUNE(elijah)
    laneHalfWidth: 6.0, ollieImpulse: 3.0, stripLength: 64,     // TUNE(elijah)
    rail: { x: 3.0, y: 0.45, zStart: -16, zEnd: -40, lockRadius: 1.8, grindSpeed: 6.5, pointsPerSec: 22 },
    olliePoints: 10,
  },

  // Sprint — rhythm/UI archetype (alternating footstrike cadence).
  sprint: {
    raceDistanceM: 100,      // TUNE(elijah)
    readyMs: 1000,           // TUNE(elijah)
    setMs: 1400,             // TUNE(elijah) — hold your nerve; tap early = false start
    targetIntervalMs: 220,   // TUNE(elijah) — sweet-spot step cadence
    perfectWindowMs: 40,     // TUNE(elijah)
    goodWindowMs: 90,        // TUNE(elijah)
    perfectImpulse: 0.85,    // TUNE(elijah) — m/s per perfect step
    goodImpulse: 0.55,       // TUNE(elijah)
    offImpulse: 0.2,         // TUNE(elijah)
    stumblePenalty: 0.55,    // TUNE(elijah) — speed multiplier on a same-foot fault
    drag: 2.2,               // TUNE(elijah) — m/s² decay (stop tapping, stop running)
    maxSpeed: 11.5,          // TUNE(elijah) — human-ish ceiling
  },

  // Gymnastics vault (air-session archetype: cadence run → punch → flips → stick).
  gymnastics: {
    attemptsPerRound: 3,     // TUNE(elijah)
    launchZ: -22,            // TUNE(elijah) — vault table position
    maxRunSpeed: 9,          // TUNE(elijah)
    perfectImpulse: 0.9,     // TUNE(elijah)
    goodImpulse: 0.55,       // TUNE(elijah)
    runDrag: 2.0,            // TUNE(elijah)
    baseLaunch: 3.2,         // TUNE(elijah) — vertical m/s minimum
    speedLaunchBonus: 2.6,   // TUNE(elijah) — extra at full run speed
    basePoints: 40,          // TUNE(elijah)
    pointsPerRotation: 60,   // TUNE(elijah)
  },

  // Big-Air (air-session archetype: carve run → kicker → spins → land).
  bigair: {
    attemptsPerRound: 3,     // TUNE(elijah)
    launchZ: -26,            // TUNE(elijah) — kicker position
    maxRunSpeed: 13,         // TUNE(elijah)
    perfectImpulse: 0,       // (carve modes build speed passively)
    goodImpulse: 0,
    runDrag: -4.5,           // TUNE(elijah) — NEGATIVE drag = slope acceleration
    baseLaunch: 3.6,         // TUNE(elijah)
    speedLaunchBonus: 3.2,   // TUNE(elijah)
    basePoints: 50,          // TUNE(elijah)
    pointsPerRotation: 70,   // TUNE(elijah)
  },

  // Story mode (board engine from the C++ donor).
  story: {
    retreatHp: 60,           // TUNE(elijah) — HP after a knockout retreat
    bossFirstAttackS: 2.0,   // TUNE(elijah) — grace before the boss swings
    bossAttackBaseS: 2.2,    // TUNE(elijah) — divided by boss aggression
    bossDmgMin: 8,           // TUNE(elijah)
    bossDmgMax: 16,          // TUNE(elijah)
    strikeCooldownS: 0.45,   // TUNE(elijah) — anti-mash
    strikeMin: 10,           // TUNE(elijah)
    strikeMax: 18,           // TUNE(elijah)
    bossShardBonus: 50,      // TUNE(elijah)
  },

  // Court bounds for free movement (Venice court, matches HOOP_POSITION space).
  court: {
    minX: -7, maxX: 7,
    minZ: -13.5, maxZ: 13,
  },
};

export default feelConfig;
