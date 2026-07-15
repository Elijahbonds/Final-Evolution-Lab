/**
 * InputBuffer — reusable, mode-agnostic buffered-input window.
 *
 * Feel DoD: a press is never dropped — if an action can't fire the moment
 * it's pressed (mid-animation, mid-air), it fires the instant it becomes
 * legal, as long as that happens within the buffer window.
 *
 * Zero-alloc in the hot path: timestamps live in a plain object keyed by
 * action name; press/consume touch numbers only.
 */
export class InputBuffer {
  /**
   * @param {{ windowMs?: number, now?: () => number }} [opts]
   */
  constructor({ windowMs = 120, now } = {}) {
    this.windowMs = windowMs;
    this._now = now ?? (() => (typeof performance !== 'undefined' ? performance.now() : Date.now()));
    this._pressedAt = Object.create(null);
  }

  /** Record a press for `action` at the current time. */
  press(action) {
    this._pressedAt[action] = this._now();
  }

  /**
   * True if `action` was pressed within the window. Consumes the press —
   * a single press fires at most once.
   * @param {string} action
   * @returns {boolean}
   */
  consume(action) {
    const t = this._pressedAt[action];
    if (t === undefined) return false;
    const fresh = this._now() - t <= this.windowMs;
    this._pressedAt[action] = undefined;
    return fresh;
  }

  /** Peek without consuming (for tests/HUD). */
  isBuffered(action) {
    const t = this._pressedAt[action];
    return t !== undefined && this._now() - t <= this.windowMs;
  }

  clear() {
    this._pressedAt = Object.create(null);
  }
}

export default InputBuffer;
