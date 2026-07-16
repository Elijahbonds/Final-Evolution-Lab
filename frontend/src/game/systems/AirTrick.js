/**
 * AirTrick — mode-agnostic mid-air rotation + landing evaluator
 * (gymnastics flips, big-air spins, future board tricks).
 *
 * While airborne: each trick tap adds half a rotation. On touchdown the
 * landing is judged by rotation completeness + the stick-tap window:
 *   stuck   — rotation within `cleanTolerance` of a half-turn AND a stick
 *             tap landed within `stickWindowMs` before touchdown
 *   clean   — rotation complete, no stick tap
 *   sketchy — rotation off by less than half a turn
 *   crash   — mid-rotation at touchdown
 */
export class AirTrick {
  /**
   * @param {{ perTapRotation?: number, cleanTolerance?: number,
   *           stickWindowMs?: number, now?: () => number }} [opts]
   */
  constructor({ perTapRotation = 0.5, cleanTolerance = 0.13, stickWindowMs = 160, now } = {}) {
    this.perTapRotation = perTapRotation;   // turns per tap
    this.cleanTolerance = cleanTolerance;   // turns
    this.stickWindowMs = stickWindowMs;
    this._now = now ?? (() => (typeof performance !== 'undefined' ? performance.now() : Date.now()));
    this.reset();
  }

  reset() {
    this.rotation = 0;
    this.taps = 0;
    this._stickAt = 0;
  }

  /** Mid-air trick tap. */
  trick() {
    this.taps += 1;
    this.rotation += this.perTapRotation;
  }

  /** Stick-the-landing tap (press just before touchdown). */
  stick() {
    this._stickAt = this._now();
  }

  /**
   * Judge at touchdown.
   * @returns {{ grade: 'stuck'|'clean'|'sketchy'|'crash', rotations: number, stuck: boolean }}
   */
  land() {
    const nearestHalf = Math.round(this.rotation * 2) / 2;
    const err = Math.abs(this.rotation - nearestHalf);
    const stuck = this._now() - this._stickAt <= this.stickWindowMs;
    let grade;
    if (err <= this.cleanTolerance) grade = stuck ? 'stuck' : 'clean';
    else if (err <= 0.25) grade = 'sketchy';
    else grade = 'crash';
    const out = { grade, rotations: this.rotation, stuck: grade === 'stuck' };
    this.reset();
    return out;
  }
}

export default AirTrick;
