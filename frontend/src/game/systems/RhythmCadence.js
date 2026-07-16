/**
 * RhythmCadence — mode-agnostic alternating-tap rhythm evaluator
 * (sprint footsteps, dance beats, paddle strokes).
 *
 * Feed it taps tagged with a side ('L'/'R'); it scores each against the
 * target cadence and alternation rule:
 *   perfect — alternated, interval within ±perfectMs of target
 *   good    — alternated, interval within ±goodMs
 *   off     — alternated but badly timed
 *   fault   — same side twice (stumble)
 * Zero-alloc in the hot path.
 */
export class RhythmCadence {
  /**
   * @param {{ targetIntervalMs?: number, perfectMs?: number, goodMs?: number,
   *           now?: () => number }} [opts]
   */
  constructor({ targetIntervalMs = 220, perfectMs = 40, goodMs = 90, now } = {}) {
    this.targetIntervalMs = targetIntervalMs;
    this.perfectMs = perfectMs;
    this.goodMs = goodMs;
    this._now = now ?? (() => (typeof performance !== 'undefined' ? performance.now() : Date.now()));
    this._lastSide = null;
    this._lastAt = 0;
    this.stats = { perfect: 0, good: 0, off: 0, fault: 0 };
  }

  reset() {
    this._lastSide = null;
    this._lastAt = 0;
    this.stats.perfect = 0; this.stats.good = 0; this.stats.off = 0; this.stats.fault = 0;
  }

  /**
   * @param {'L'|'R'} side
   * @returns {'first'|'perfect'|'good'|'off'|'fault'}
   */
  tap(side) {
    const t = this._now();
    if (side === this._lastSide) {
      this.stats.fault++;
      this._lastSide = side;
      this._lastAt = t;
      return 'fault';
    }
    const first = this._lastSide === null;
    const interval = t - this._lastAt;
    this._lastSide = side;
    this._lastAt = t;
    if (first) return 'first';
    const err = Math.abs(interval - this.targetIntervalMs);
    if (err <= this.perfectMs) { this.stats.perfect++; return 'perfect'; }
    if (err <= this.goodMs)    { this.stats.good++;    return 'good'; }
    this.stats.off++;
    return 'off';
  }
}

export default RhythmCadence;
