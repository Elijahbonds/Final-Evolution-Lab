/**
 * FixedStepLoop — fixed-timestep accumulator decoupled from render.
 *
 * update(fixedDtSeconds) runs zero or more times per tick at exactly
 * 1/hz; render(alpha) runs once per tick with the interpolation factor
 * [0..1) between the previous and current simulation states.
 *
 * Contract (feel DoD): same input ⇒ same simulation at 30/60/144 fps.
 * The tick path allocates nothing.
 */
export class FixedStepLoop {
  /**
   * @param {{ hz?: number, maxAccumulatedMs?: number,
   *           update: (dt: number) => void,
   *           render?: (alpha: number) => void }} opts
   */
  constructor({ hz = 60, maxAccumulatedMs = 250, update, render }) {
    this.stepMs = 1000 / hz;
    this.stepSeconds = 1 / hz;
    this.maxAccumulatedMs = maxAccumulatedMs;
    this.update = update;
    this.render = render ?? null;
    this.accumulatedMs = 0;
    this.running = false;
    this.stepCount = 0;
    this.alpha = 0;
  }

  start() { this.running = true; this.accumulatedMs = 0; }
  stop()  { this.running = false; this.accumulatedMs = 0; }

  /**
   * Advance simulation by real elapsed milliseconds.
   * @param {number} dtMs — real time since last tick
   */
  tick(dtMs) {
    if (!this.running) return;
    // Clamp to avoid the spiral of death after tab-sleep or long frames.
    this.accumulatedMs += Math.min(dtMs, this.maxAccumulatedMs);
    while (this.accumulatedMs >= this.stepMs) {
      this.update(this.stepSeconds);
      this.accumulatedMs -= this.stepMs;
      this.stepCount++;
    }
    this.alpha = this.accumulatedMs / this.stepMs;
    if (this.render) this.render(this.alpha);
  }
}

export default FixedStepLoop;
