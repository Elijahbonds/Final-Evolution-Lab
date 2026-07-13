const createDefaultState = () => ({
  score: {
    total: 0,
    sessionHigh: 0,
    streak: 0,
  },
  prq: {
    prq: 50,
    tier: 'Silver',
    recentEvents: [],
  },
  combo: {
    chain: 0,
    multiplier: 1,
    windowOpen: false,
    lastBreakReason: null,
  },
  timer: {
    elapsedMs: 0,
    remainingMs: null,
  },
  wearable: {
    available: false,
    heartRate: null,
    metrics: null,
  },
});

/**
 * Centralised HUD state store with pub/sub.
 */
export class HUDStateSystem {
  /**
   * Creates the HUD state store.
   */
  constructor() {
    this.listeners = new Set();
    this.reset();
  }

  /**
   * Merges partial state into the current HUD snapshot.
   *
   * @param {Partial<{ score: object, prq: object, combo: object, timer: object, wearable: object }>} updates
   * @returns {{ score: object, prq: object, combo: object, timer: object, wearable: object }}
   */
  setState(updates = {}) {
    const nextState = { ...this.state };

    Object.keys(updates).forEach((key) => {
      const currentValue = this.state[key];
      const incomingValue = updates[key];

      if (this.isMergeableObject(currentValue) && this.isMergeableObject(incomingValue)) {
        nextState[key] = {
          ...currentValue,
          ...incomingValue,
        };
        return;
      }

      nextState[key] = incomingValue;
    });

    this.state = nextState;
    const snapshot = this.getState();
    this.listeners.forEach((listener) => listener(snapshot));
    return snapshot;
  }

  /**
   * Returns the full HUD snapshot.
   *
   * @returns {{ score: object, prq: object, combo: object, timer: object, wearable: object }}
   */
  getState() {
    return {
      score: { ...this.state.score },
      prq: {
        ...this.state.prq,
        recentEvents: this.state.prq.recentEvents.slice(),
      },
      combo: { ...this.state.combo },
      timer: { ...this.state.timer },
      wearable: { ...this.state.wearable },
    };
  }

  /**
   * Subscribes to state updates.
   *
   * @param {(state: { score: object, prq: object, combo: object, timer: object, wearable: object }) => void} listener
   * @returns {() => void}
   */
  subscribe(listener) {
    this.listeners.add(listener);

    return () => {
      this.listeners.delete(listener);
    };
  }

  /**
   * Resets the HUD state to defaults.
   *
   * @returns {void}
   */
  reset() {
    this.state = createDefaultState();
  }

  /**
   * @private
   * @param {*} value
   * @returns {boolean}
   */
  isMergeableObject(value) {
    return Boolean(value) && typeof value === 'object' && !Array.isArray(value);
  }
}

export default HUDStateSystem;
