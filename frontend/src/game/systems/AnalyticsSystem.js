/**
 * Lightweight in-memory analytics event queue.
 */
export class AnalyticsSystem {
  /**
   * Creates the analytics queue.
   */
  constructor() {
    this.reset();
  }

  /**
   * Tracks an analytics event.
   *
   * @param {string} eventName
   * @param {Record<string, *>} [properties={}]
   * @returns {{ eventName: string, properties: Record<string, *>, timestamp: number }}
   */
  track(eventName, properties = {}) {
    const timestamp = Date.now();
    const event = {
      eventName,
      properties: { ...properties },
      timestamp,
    };

    this.events.push(event);
    this.counts[eventName] = (this.counts[eventName] || 0) + 1;
    this.totalEvents += 1;
    this.firstEventAt = this.firstEventAt || timestamp;
    this.lastEventAt = timestamp;
    return event;
  }

  /**
   * Flushes and clears queued analytics events.
   *
   * @returns {Array<{ eventName: string, properties: Record<string, *>, timestamp: number }>}
   */
  flush() {
    const queuedEvents = this.events.slice();
    this.events = [];
    return queuedEvents;
  }

  /**
   * Returns an aggregate summary for the current session.
   *
   * @returns {{ totalEvents: number, uniqueEvents: number, counts: Record<string, number>, firstEventAt: number|null, lastEventAt: number|null, sessionDurationMs: number }}
   */
  getSessionSummary() {
    return {
      totalEvents: this.totalEvents,
      uniqueEvents: Object.keys(this.counts).length,
      counts: { ...this.counts },
      firstEventAt: this.firstEventAt,
      lastEventAt: this.lastEventAt,
      sessionDurationMs: this.firstEventAt && this.lastEventAt ? this.lastEventAt - this.firstEventAt : 0,
    };
  }

  /**
   * Resets the analytics session.
   *
   * @returns {void}
   */
  reset() {
    this.events = [];
    this.counts = {};
    this.totalEvents = 0;
    this.firstEventAt = null;
    this.lastEventAt = null;
  }
}

// TODO: wire flush() to Abacus analytics endpoint when online

export default AnalyticsSystem;
