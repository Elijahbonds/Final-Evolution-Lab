/**
 * HealthKit / wearable integration stub.
 */
export class WearableSystem {
  /**
   * Creates the wearable integration stub.
   */
  constructor() {
    this.available = false;
  }

  /**
   * Requests wearable permissions.
   *
   * @returns {Promise<{ granted: false, reason: 'stub' }>}
   */
  async requestPermissions() {
    return {
      granted: false,
      reason: 'stub',
    };
  }

  /**
   * Reads the latest heart rate value.
   *
   * @returns {Promise<{ bpm: null, source: 'stub' }>}
   */
  async getHeartRate() {
    return {
      bpm: null,
      source: 'stub',
    };
  }

  /**
   * Reads workout metrics from the wearable provider.
   *
   * @returns {Promise<{ calories: null, steps: null, source: 'stub' }>}
   */
  async getWorkoutMetrics() {
    return {
      calories: null,
      steps: null,
      source: 'stub',
    };
  }

  /**
   * Reports whether wearable APIs are available.
   *
   * @returns {boolean}
   */
  isAvailable() {
    return this.available;
  }
}

// TODO: implement real HealthKit bridge when running in WKWebView/native context

export default WearableSystem;
