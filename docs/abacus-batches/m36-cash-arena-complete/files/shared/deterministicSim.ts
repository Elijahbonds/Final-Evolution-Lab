// deterministicSim — THE one dunk simulator. The client records raw inputs,
// runs THIS function to produce its telemetry; the server re-runs THIS SAME
// function on the same inputs to verify. Same code ⇒ same numbers ⇒ cheating
// requires beating math, not packet-editing. Pure, seeded, no Date/Math.random.

import type { DunkRunTelemetry } from './arenaContracts';

// ── Seeded RNG (xmur3 → mulberry32) ────────────────────────────────────────
export function seededRng(seed: string): () => number {
  let h = 1779033703 ^ seed.length;
  for (let i = 0; i < seed.length; i++) {
    h = Math.imul(h ^ seed.charCodeAt(i), 3432918353);
    h = (h << 13) | (h >>> 19);
  }
  let a = (h ^= h >>> 16) >>> 0;
  return () => {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ── Input stream codec ─────────────────────────────────────────────────────
// Events: s=stick(x,y) · t=trigger(v) · a=slam tap · y=style(0|1|2)
export interface SimEvent { tMs: number; k: 's' | 't' | 'a' | 'y'; a?: number; b?: number }

const q = (n: number) => Math.round(n * 1000) / 1000;

export function encodeStream(events: SimEvent[]): string {
  return events.map((e) =>
    e.k === 's' ? `${e.tMs}s${q(e.a!)},${q(e.b!)}` :
    e.k === 't' ? `${e.tMs}t${q(e.a!)}` :
    e.k === 'y' ? `${e.tMs}y${e.a}` : `${e.tMs}a`).join(';');
}

export function decodeStream(stream: string): SimEvent[] {
  if (!stream) return [];
  return stream.split(';').map((tok) => {
    const m = /^(\d+)([stay])(.*)$/.exec(tok);
    if (!m) throw new Error(`bad stream token: ${tok}`);
    const tMs = +m[1], k = m[2] as SimEvent['k'];
    if (k === 's') { const [a, b] = m[3].split(',').map(Number); return { tMs, k, a, b }; }
    if (k === 't' || k === 'y') return { tMs, k, a: +m[3] };
    return { tMs, k };
  });
}

// ── The simulation ─────────────────────────────────────────────────────────
// Physics constants FROZEN — changing any of these invalidates open contests.
export const SIM = {
  stepMs: 1000 / 120,          // fixed 120 Hz integration
  maxMs: 30_000,
  startZ: 8.5, gatherZ: 2.2,
  runSpeed: 5,                 // m/s at full stick
  airBase: 0.9, airPerCharge: 0.5,        // airtime seconds
  apexBase: 1.05, apexPerCharge: 0.55,    // meters
  extendFrac: 0.55,            // rim-arrival beat as a fraction of airtime
  cleanWindowMs: 140,          // |slam − rim| ≤ this = clean release
  windMax: 0.04,               // seeded contest conditions (± on apex)
} as const;

const STYLES = ['power', 'flashy', 'sig'] as const;

/** Deterministic replay: (seed, inputs) → telemetry. Client AND server. */
export function simulateDunkRun(seed: string, inputStream: string): DunkRunTelemetry {
  const rng = seededRng(seed);
  const wind = (rng() * 2 - 1) * SIM.windMax;            // per-contest condition
  const events = decodeStream(inputStream);

  let z = SIM.startZ, stickX = 0, stickY = 0, trigger = 0;
  let style = 0;
  let charging = false, charge = 0;
  let launchedAtMs = -1, slamDeltaMs = Number.POSITIVE_INFINITY;
  const speedSamples: number[] = [];
  let ei = 0;

  for (let tMs = 0; tMs <= SIM.maxMs; tMs += SIM.stepMs) {
    while (ei < events.length && events[ei].tMs <= tMs) {
      const e = events[ei++];
      if (e.k === 's') { stickX = e.a!; stickY = e.b!; }
      if (e.k === 'y') style = Math.max(0, Math.min(2, e.a! | 0));
      if (e.k === 't') {
        trigger = e.a!;
        if (trigger > 0.02 && launchedAtMs < 0) charging = true;
        if (charging) charge = Math.max(charge, trigger);
        if (charging && trigger === 0 && launchedAtMs < 0) launchedAtMs = tMs;
      }
      if (e.k === 'a' && launchedAtMs >= 0) {
        const airMs = (SIM.airBase + charge * SIM.airPerCharge) * 1000;
        const rimMs = launchedAtMs + airMs * SIM.extendFrac;
        slamDeltaMs = Math.min(slamDeltaMs, Math.abs(e.tMs - rimMs));
      }
    }
    if (launchedAtMs < 0 && !charging) {
      const vz = -Math.max(0, -stickY) * SIM.runSpeed - 2;
      z = Math.max(SIM.gatherZ, z + vz * (SIM.stepMs / 1000));
      speedSamples.push(Math.hypot(stickX * 4, vz));
    }
    if (launchedAtMs >= 0 && tMs > launchedAtMs + (SIM.airBase + charge * SIM.airPerCharge) * 1000 + 500) break;
  }

  const airSec = SIM.airBase + charge * SIM.airPerCharge;
  const tail = speedSamples.slice(-120);                 // last second of approach
  const approachSpeed = tail.length ? q(tail.reduce((a, b) => a + b, 0) / tail.length) : 0;
  const qteDeltaMs = Number.isFinite(slamDeltaMs) ? Math.round(slamDeltaMs) : 999;

  return {
    seed,
    style: STYLES[style],
    approachSpeed,
    chargeLevel: q(charge),
    qteDeltaMs,
    apexHeight: q(SIM.apexBase + charge * SIM.apexPerCharge + wind),
    hangTimeMs: launchedAtMs >= 0 ? Math.round(airSec * 1000) : 0,
    cleanRelease: qteDeltaMs <= SIM.cleanWindowMs,
    inputStream,
  };
}

/** Server-side verification (drop-in for cashArenaApi's Simulator seam). */
export const deterministicSimulator = {
  simulate: async (seed: string, inputStream: string) => simulateDunkRun(seed, inputStream),
};
