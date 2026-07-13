/**
 * Match score system with combo multipliers.
 */
export class ScoreSystem {
  /**
   * Initialises the score system.
   */
  constructor() {
    this.reset();
  }

  /**
   * Adds points to the running score.
   *
   * @param {number} base
   * @param {number} [multiplier=1]
   * @returns {number} The new total score.
   */
  addPoints(base, multiplier = 1) {
    const safeBase = Number.isFinite(base) ? base : 0;
    const safeMultiplier = Number.isFinite(multiplier) ? multiplier : 1;
    const addedPoints = Math.max(0, Math.round(safeBase * safeMultiplier));

    this.total += addedPoints;
    this.sessionHigh = Math.max(this.sessionHigh, this.total);
    this.streak = addedPoints > 0 ? this.streak + 1 : 0;

    return this.total;
  }

  /**
   * Computes a combo multiplier from the current chain length.
   *
   * @param {number} comboLength
   * @returns {number} Multiplier value from 1x to 4x.
   */
  applyComboMultiplier(comboLength) {
    const length = Math.max(0, Math.floor(Number(comboLength) || 0));

    if (length >= 10) {
      return 4;
    }

    if (length >= 7) {
      return 3;
    }

    if (length >= 4) {
      return 2;
    }

    return 1;
  }

  /**
   * Returns the current score snapshot.
   *
   * @returns {{ total: number, sessionHigh: number, streak: number }}
   */
  getScore() {
    return {
      total: this.total,
      sessionHigh: this.sessionHigh,
      streak: this.streak,
    };
  }

  /**
   * Resets the score state.
   *
   * @returns {void}
   */
  reset() {
    this.total = 0;
    this.sessionHigh = 0;
    this.streak = 0;
  }
}

export default ScoreSystem;
