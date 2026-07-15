/**
 * ArcDrive — hybrid animation↔physics blend (mode-agnostic).
 *
 * Drives a body along an idealized parametric arc (dunk drive, grind
 * lock-on, spike approach) and hands control back to physics at the end
 * WITHOUT a jerk: position is continuous by construction (arc end = sim
 * position) and the caller receives the arc-end vertical velocity to seed
 * the physics handback.
 *
 * Zero-alloc: begin() copies into preallocated vectors; evaluate() writes
 * into a caller-provided out vector.
 */
export class ArcDrive {
  constructor() {
    this.active = false;
    this.t = 0;
    this._durationSec = 0;
    this._start = { x: 0, y: 0, z: 0 };
    this._target = { x: 0, y: 0, z: 0 };
    this._apexY = 0;
  }

  /**
   * @param {{ start: {x,y,z}, target: {x,y,z}, apexY: number, durationMs: number }} opts
   *   apexY — absolute peak height of the arc (must be ≥ max(start.y, target.y)).
   */
  begin({ start, target, apexY, durationMs }) {
    this._start.x = start.x; this._start.y = start.y; this._start.z = start.z;
    this._target.x = target.x; this._target.y = target.y; this._target.z = target.z;
    this._apexY = Math.max(apexY, start.y, target.y);
    this._durationSec = Math.max(0.05, durationMs / 1000);
    this.t = 0;
    this.active = true;
  }

  cancel() { this.active = false; this.t = 0; }

  /**
   * Advance by dt and write the arc position into `out`.
   * @param {number} dt — fixed step seconds
   * @param {{x,y,z}} out — written in place
   * @returns {boolean} true when the arc completed on this step
   */
  advance(dt, out) {
    if (!this.active) return false;
    this.t = Math.min(1, this.t + dt / this._durationSec);
    const t = this.t;

    // Horizontal: smoothstep-eased lerp (committed, weighty approach).
    const e = t * t * (3 - 2 * t);
    out.x = this._start.x + (this._target.x - this._start.x) * e;
    out.z = this._start.z + (this._target.z - this._start.z) * e;

    // Vertical: piecewise parabola through the apex at t=0.5.
    out.y = this._verticalAt(t);

    if (t >= 1) { this.active = false; return true; }
    return false;
  }

  /** Vertical velocity (m/s) at the arc end — seeds the physics handback. */
  endVerticalVelocity() {
    const dt = 0.016;
    return (this._verticalAt(1) - this._verticalAt(1 - dt / this._durationSec)) / dt;
  }

  /** @private */
  _verticalAt(t) {
    const s = this._start.y, a = this._apexY, g = this._target.y;
    if (t < 0.5) {
      const u = t / 0.5;               // rise half: parabola s → apex
      return s + (a - s) * (1 - (1 - u) * (1 - u));
    }
    const u = (t - 0.5) / 0.5;         // fall half: parabola apex → target
    return a - (a - g) * u * u;
  }
}

export default ArcDrive;
