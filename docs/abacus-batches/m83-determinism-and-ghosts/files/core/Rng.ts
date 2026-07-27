// Rng — seeded randomness, because Math.random() cannot be replayed.
//
// Every mode currently calls Math.random() directly: dunk judge variance,
// karate wave composition, opponent decisions, quiz shuffles, wave generation
// in Surf. None of it can be reproduced, which means:
//
//   · A GHOST IS NOT THE SAME MATCH. Replay the winner's inputs and the AI
//     makes different choices, the judges score differently, the waves come in
//     differently. The recording is of a match that can never happen again.
//   · A BUG REPORT IS UNACTIONABLE. "The defender teleported" has no repro.
//   · CASH ARENA CANNOT BE AUDITED. A prize-pool match whose outcome depends
//     on unrecorded randomness is not verifiable by anyone, including you.
//     That is a product blocker, not a code-quality preference.
//
// This is mulberry32: 32-bit state, one multiply-xor-shift round, passes the
// usual smoke tests for game use, and — the property that matters — its entire
// state is ONE NUMBER, so a replay header can carry it and a desync can be
// diagnosed by comparing it.
//
// NOT for anything security-bearing. Prize-pool INTEGRITY comes from the
// server re-simulating a recorded match, not from the client's PRNG being
// unguessable.

export class Rng {
  private state: number;
  public readonly seed: number;
  /** How many numbers have been drawn. Two runs that diverge here diverged
   *  somewhere upstream, and the count localises it fast. */
  public draws = 0;

  constructor(seed: number = Rng.freshSeed()) {
    this.seed = seed >>> 0;
    this.state = this.seed;
  }

  /** A seed for a NEW session. The one legitimate use of Math.random here:
   *  choosing what to record, which is then fixed forever after. */
  static freshSeed(): number {
    return (Math.random() * 0x100000000) >>> 0;
  }

  /** Restore mid-stream state — for resuming a replay from a checkpoint. */
  static restore(seed: number, state: number, draws: number): Rng {
    const r = new Rng(seed);
    r.state = state >>> 0;
    r.draws = draws;
    return r;
  }

  /** Serialisable snapshot. */
  snapshot(): { seed: number; state: number; draws: number } {
    return { seed: this.seed, state: this.state, draws: this.draws };
  }

  /** Next float in [0, 1). Drop-in for Math.random(). */
  next(): number {
    this.draws++;
    this.state = (this.state + 0x6d2b79f5) >>> 0;
    let t = this.state;
    t = Math.imul(t ^ (t >>> 15), t | 1) >>> 0;
    t = (t ^ (t + Math.imul(t ^ (t >>> 7), t | 61))) >>> 0;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }

  /** Float in [min, max). */
  range(min: number, max: number): number {
    return min + this.next() * (max - min);
  }

  /** Integer in [min, max] INCLUSIVE — matches Swift's `Int.random(in:)`, and
   *  the off-by-one between the two conventions is a classic. */
  int(min: number, max: number): number {
    if (max < min) return min;
    return min + Math.floor(this.next() * (max - min + 1));
  }

  /** True with probability p. */
  chance(p: number): boolean { return this.next() < p; }

  /** Uniform pick. Returns undefined for an empty array rather than throwing —
   *  an empty content pack should degrade, not crash a match. */
  pick<T>(items: readonly T[]): T | undefined {
    return items.length ? items[this.int(0, items.length - 1)] : undefined;
  }

  /**
   * Fisher-Yates, returning a NEW array.
   *
   * Deliberately not in-place: shuffling a shared content pack in place makes
   * the next match depend on the last one, which is a determinism leak that
   * survives a correct seed.
   */
  shuffle<T>(items: readonly T[]): T[] {
    const a = [...items];
    for (let i = a.length - 1; i > 0; i--) {
      const j = this.int(0, i);
      [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
  }

  /**
   * A named sub-stream.
   *
   * Different systems must not share a draw counter. If the AI and the crowd
   * animation pull from one stream, adding a crowd effect silently changes
   * every AI decision after it — and every existing replay breaks. Deriving a
   * stream per system means new visual features cannot invalidate old
   * recordings.
   */
  fork(name: string): Rng {
    let h = this.seed >>> 0;
    for (let i = 0; i < name.length; i++) {
      h ^= name.charCodeAt(i);
      h = Math.imul(h, 0x01000193) >>> 0;
    }
    return new Rng(h);
  }
}

/**
 * The session RNG.
 *
 * A module-level default so a mode can migrate off Math.random() by changing
 * one call, not by threading an Rng through every function. `reseed()` is
 * called once when a match starts.
 */
let sessionRng = new Rng();

export function reseedSession(seed: number = Rng.freshSeed()): Rng {
  sessionRng = new Rng(seed);
  console.info(`[FEL-RNG] session seed ${sessionRng.seed} — replays of this match are exact.`);
  return sessionRng;
}

export function rng(): Rng { return sessionRng; }

/**
 * Find the Math.random() calls this module is meant to replace.
 *
 * Runtime detection is deliberate. A grep finds them in source; this finds
 * them in whatever actually shipped, including inside a dependency or a
 * bundled helper. Call it in dev with `?probe=1`.
 */
export function detectRawRandom(): () => void {
  const original = Math.random;
  const sites = new Map<string, number>();
  Math.random = function patched(): number {
    const site = (new Error().stack ?? '').split('\n')[2]?.trim() ?? 'unknown';
    sites.set(site, (sites.get(site) ?? 0) + 1);
    return original.call(Math);
  };
  return () => {
    Math.random = original;
    if (!sites.size) { console.info('[FEL-RNG] no raw Math.random() during that window.'); return; }
    console.warn(`[FEL-RNG] ${sites.size} call site(s) still using Math.random() — `
      + 'these make the match unreplayable:');
    for (const [site, n] of [...sites].sort((a, b) => b[1] - a[1])) {
      console.warn(`  ${n}x  ${site}`);
    }
  };
}
