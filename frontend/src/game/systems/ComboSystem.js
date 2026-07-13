/**
 * Tracks combo chains, timing windows, and break conditions.
 */
export class ComboSystem {
  /**
   * Creates a combo system.
   *
   * @param {{ windowMs?: number, maxChain?: number }} [config]
   */
  constructor(config = {}) {
    this.windowMs = Number.isFinite(config.windowMs) ? config.windowMs : 800;
    this.maxChain = Number.isFinite(config.maxChain) ? config.maxChain : 12;
    this.reset();
  }

  /**
   * Registers a successful hit in the active combo window.
   *
   * @param {'perfect'|'good'|'ok'} [quality='ok']
   * @returns {{ chain: number, multiplier: number, windowOpen: boolean, quality: string }}
   */
  registerHit(quality = 'ok') {
    this.chain = Math.min(this.chain + 1, this.maxChain);
    this.elapsedMs = 0;
    this.windowOpen = true;
    this.lastQuality = quality;
    this.lastBreakReason = null;

    return {
      chain: this.chain,
      multiplier: this.getMultiplier(),
      windowOpen: this.windowOpen,
      quality: this.lastQuality,
    };
  }

  /**
   * Advances the combo timer.
   *
   * @param {number} deltaTime
   * @returns {{ chain: number, multiplier: number, windowOpen: boolean }}
   */
  update(deltaTime) {
    const delta = Number.isFinite(deltaTime) ? Math.max(0, deltaTime) : 0;

    if (this.windowOpen) {
      this.elapsedMs += delta;

      if (this.elapsedMs >= this.windowMs) {
        this.breakCombo('window-expired');
      }
    }

    return {
      chain: this.chain,
      multiplier: this.getMultiplier(),
      windowOpen: this.windowOpen,
    };
  }

  /**
   * Breaks the current combo chain.
   *
   * @param {string} reason
   * @returns {{ chain: number, multiplier: number, windowOpen: boolean, reason: string }}
   */
  breakCombo(reason) {
    this.chain = 0;
    this.elapsedMs = 0;
    this.windowOpen = false;
    this.lastBreakReason = reason || 'manual-break';

    return {
      chain: this.chain,
      multiplier: this.getMultiplier(),
      windowOpen: this.windowOpen,
      reason: this.lastBreakReason,
    };
  }

  /**
   * Resets combo tracking.
   *
   * @returns {void}
   */
  reset() {
    this.chain = 0;
    this.elapsedMs = 0;
    this.windowOpen = false;
    this.lastQuality = null;
    this.lastBreakReason = null;
  }

  /**
   * @private
   * @returns {number}
   */
  getMultiplier() {
    if (this.chain >= 10) {
      return 4;
    }

    if (this.chain >= 7) {
      return 3;
    }

    if (this.chain >= 4) {
      return 2;
    }

    return 1;
  }
}

export default ComboSystem;
