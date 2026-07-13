function cloneCombo(combo) {
  return combo.slice();
}

function createStrikeTypes(strikeTypes = {}) {
  return {
    light: {
      durationMs: 240,
      hitWindowStartMs: 50,
      hitWindowEndMs: 140,
      comboValue: 1,
      ...(strikeTypes.light || {}),
    },
    heavy: {
      durationMs: 420,
      hitWindowStartMs: 110,
      hitWindowEndMs: 260,
      comboValue: 1.5,
      ...(strikeTypes.heavy || {}),
    },
    special: {
      durationMs: 520,
      hitWindowStartMs: 140,
      hitWindowEndMs: 320,
      comboValue: 2,
      ...(strikeTypes.special || {}),
    },
    ...Object.fromEntries(
      Object.entries(strikeTypes).filter(([type]) => !["light", "heavy", "special"].includes(type)),
    ),
  };
}

export class StrikeCore {
  /**
   * @param {{ strikeTypes?: Record<string, { durationMs?: number, hitWindowStartMs?: number, hitWindowEndMs?: number, comboValue?: number }>, comboWindowMs?: number, maxComboLength?: number }} [config]
   */
  constructor(config = {}) {
    // TODO: wire to Babylon.js TransformNode in the mode skin layer
    this.strikeTypes = createStrikeTypes(config.strikeTypes);
    this.comboWindowMs = config.comboWindowMs ?? 400;
    this.maxComboLength = config.maxComboLength ?? 4;
    this.reset();
  }

  /**
   * Queues a strike into the current combo sequence.
   * @param {string} type
   * @returns {boolean}
   */
  registerStrike(type) {
    if (!this.strikeTypes[type]) {
      return false;
    }

    if (this.comboSequence.length >= this.maxComboLength) {
      return false;
    }

    if (!this.currentStrike && this.comboSequence.length > 0 && this.comboTimerRemainingMs <= 0) {
      this.clearCombo();
    }

    this.comboSequence.push(type);
    this.comboTimerRemainingMs = this.comboWindowMs;

    if (!this.currentStrike) {
      this.startStrike(type);
      this.executionIndex = 1;
    }

    return true;
  }

  /**
   * Advances strike timing, combo decay, and hit window state.
   * @param {number} deltaTime
   * @returns {{ activeCombo: string[], comboMultiplier: number, strikeResolved: boolean, hitWindow: { isOpen: boolean, type: string | null, elapsedMs: number, startMs: number, endMs: number } }}
   */
  update(deltaTime = 0) {
    const safeDeltaTimeMs = Math.max(0, Number(deltaTime) || 0) * 1000;
    let strikeResolved = false;

    if (this.currentStrike) {
      this.currentStrike.elapsedMs += safeDeltaTimeMs;
      this.comboTimerRemainingMs = this.comboWindowMs;

      if (this.currentStrike.elapsedMs >= this.currentStrike.durationMs) {
        strikeResolved = true;
        this.currentStrike = null;

        if (this.executionIndex < this.comboSequence.length) {
          const nextType = this.comboSequence[this.executionIndex];
          this.startStrike(nextType);
          this.executionIndex += 1;
        }
      }
    } else if (this.comboSequence.length > 0) {
      this.comboTimerRemainingMs = Math.max(0, this.comboTimerRemainingMs - safeDeltaTimeMs);

      if (this.comboTimerRemainingMs === 0) {
        this.clearCombo();
      }
    }

    return {
      activeCombo: cloneCombo(this.comboSequence),
      comboMultiplier: this.getComboMultiplier(),
      strikeResolved,
      hitWindow: this.getHitWindow(),
    };
  }

  /**
   * Clears the current combo sequence and any queued strikes.
   */
  clearCombo() {
    this.comboSequence = [];
    this.currentStrike = null;
    this.comboTimerRemainingMs = 0;
    this.executionIndex = 0;
  }

  /**
   * Restores strike state to its default idle values.
   */
  reset() {
    this.comboSequence = [];
    this.currentStrike = null;
    this.comboTimerRemainingMs = 0;
    this.executionIndex = 0;
  }

  /**
   * Starts the active strike state for a queued combo step.
   * @param {string} type
   */
  startStrike(type) {
    const strikeType = this.strikeTypes[type];

    this.currentStrike = {
      type,
      elapsedMs: 0,
      durationMs: strikeType.durationMs ?? 0,
      hitWindowStartMs: strikeType.hitWindowStartMs ?? 0,
      hitWindowEndMs: strikeType.hitWindowEndMs ?? strikeType.durationMs ?? 0,
    };
  }

  /**
   * Calculates the current combo multiplier from the queued strike sequence.
   * @returns {number}
   */
  getComboMultiplier() {
    if (this.comboSequence.length === 0) {
      return 1;
    }

    const comboValue = this.comboSequence.reduce((total, type) => {
      return total + (this.strikeTypes[type]?.comboValue ?? 1);
    }, 0);

    return Number((comboValue / this.comboSequence.length).toFixed(2));
  }

  /**
   * Returns the current strike hit window state.
   * @returns {{ isOpen: boolean, type: string | null, elapsedMs: number, startMs: number, endMs: number }}
   */
  getHitWindow() {
    if (!this.currentStrike) {
      return {
        isOpen: false,
        type: null,
        elapsedMs: 0,
        startMs: 0,
        endMs: 0,
      };
    }

    return {
      isOpen:
        this.currentStrike.elapsedMs >= this.currentStrike.hitWindowStartMs &&
        this.currentStrike.elapsedMs <= this.currentStrike.hitWindowEndMs,
      type: this.currentStrike.type,
      elapsedMs: this.currentStrike.elapsedMs,
      startMs: this.currentStrike.hitWindowStartMs,
      endMs: this.currentStrike.hitWindowEndMs,
    };
  }
}

export default StrikeCore;
