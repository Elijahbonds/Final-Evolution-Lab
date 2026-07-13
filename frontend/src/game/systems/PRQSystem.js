const DEFAULT_PRQ = 50;
const WINDOW_MS = 60000;
const MAX_EVENTS = 25;

const TYPE_WEIGHTS = {
  hit: 8,
  miss: -12,
  dodge: 6,
  combo: 10,
};

const QUALITY_WEIGHTS = {
  perfect: 1,
  excellent: 0.95,
  great: 0.85,
  good: 0.75,
  ok: 0.6,
  clean: 0.7,
  weak: 0.4,
  poor: 0.25,
};

/**
 * Performance Profile/Quality loop.
 */
export class PRQSystem {
  /**
   * Initialises the PRQ system.
   */
  constructor() {
    this.reset();
  }

  /**
   * Records a performance event.
   *
   * @param {{ type: 'hit'|'miss'|'dodge'|'combo', quality?: string|number, timestamp?: number }} event
   * @returns {number} The current PRQ score.
   */
  recordEvent({ type, quality, timestamp = Date.now() }) {
    if (!TYPE_WEIGHTS[type]) {
      return this.computePRQ();
    }

    this.events.push({
      type,
      quality,
      timestamp,
    });

    this.pruneEvents(timestamp);

    if (this.events.length > MAX_EVENTS) {
      this.events = this.events.slice(-MAX_EVENTS);
    }

    this.prq = this.computePRQ();
    return this.prq;
  }

  /**
   * Computes the current PRQ score from the rolling event window.
   *
   * @returns {number} Current PRQ score on a 0-100 scale.
   */
  computePRQ() {
    this.pruneEvents(Date.now());

    if (this.events.length === 0) {
      this.prq = DEFAULT_PRQ;
      return this.prq;
    }

    const totalDelta = this.events.reduce((sum, event) => {
      const typeWeight = TYPE_WEIGHTS[event.type] || 0;
      return sum + typeWeight * this.resolveQualityWeight(event.quality, event.type);
    }, 0);

    const normalisedDelta = totalDelta / Math.max(this.events.length, 1);
    this.prq = this.clamp(DEFAULT_PRQ + normalisedDelta * 4, 0, 100);
    return this.prq;
  }

  /**
   * Gets the current performance profile.
   *
   * @returns {{ prq: number, tier: 'Bronze'|'Silver'|'Gold'|'Elite', recentEvents: Array<{ type: string, quality?: string|number, timestamp: number }> }}
   */
  getProfile() {
    const prq = this.computePRQ();

    return {
      prq,
      tier: this.resolveTier(prq),
      recentEvents: this.events.slice(),
    };
  }

  /**
   * Resets the PRQ state.
   *
   * @returns {void}
   */
  reset() {
    this.prq = DEFAULT_PRQ;
    this.events = [];
  }

  /**
   * @private
   * @param {number} now
   * @returns {void}
   */
  pruneEvents(now) {
    this.events = this.events.filter((event) => now - event.timestamp <= WINDOW_MS);
  }

  /**
   * @private
   * @param {string|number|undefined} quality
   * @param {string} type
   * @returns {number}
   */
  resolveQualityWeight(quality, type) {
    if (typeof quality === 'number' && Number.isFinite(quality)) {
      if (quality <= 1) {
        return this.clamp(quality, 0, 1);
      }

      return this.clamp(quality / 100, 0, 1);
    }

    if (typeof quality === 'string' && QUALITY_WEIGHTS[quality.toLowerCase()] !== undefined) {
      return QUALITY_WEIGHTS[quality.toLowerCase()];
    }

    return type === 'miss' ? 1 : 0.7;
  }

  /**
   * @private
   * @param {number} prq
   * @returns {'Bronze'|'Silver'|'Gold'|'Elite'}
   */
  resolveTier(prq) {
    if (prq >= 85) {
      return 'Elite';
    }

    if (prq >= 70) {
      return 'Gold';
    }

    if (prq >= 45) {
      return 'Silver';
    }

    return 'Bronze';
  }

  /**
   * @private
   * @param {number} value
   * @param {number} min
   * @param {number} max
   * @returns {number}
   */
  clamp(value, min, max) {
    return Math.min(max, Math.max(min, Number(value) || 0));
  }
}

export default PRQSystem;
