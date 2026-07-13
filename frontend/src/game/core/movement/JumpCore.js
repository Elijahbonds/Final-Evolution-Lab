export class JumpCore {
  /**
   * @param {{ jumpForce?: number, gravity?: number, maxAirTime?: number }} [config]
   */
  constructor(config = {}) {
    // TODO: wire to Babylon.js TransformNode in the mode skin layer
    this.jumpForce = config.jumpForce ?? 8.5;
    this.gravity = config.gravity ?? 24;
    this.maxAirTime = config.maxAirTime ?? 1.4;
    this.reset();
  }

  /**
   * Starts a jump if the actor is grounded.
   * @returns {boolean}
   */
  jump() {
    if (this.isAirborne) {
      return false;
    }

    this.isAirborne = true;
    this.yVelocity = this.jumpForce;
    this.airTime = 0;
    this.hasReachedApex = false;
    this.pendingApexReached = false;
    this.pendingLandingDetected = false;

    return true;
  }

  /**
   * Advances airborne physics and transient event flags.
   * @param {number} deltaTime
   * @returns {{ yVelocity: number, isAirborne: boolean, apexReached: boolean, landingDetected: boolean }}
   */
  update(deltaTime = 0) {
    const safeDeltaTime = Math.max(0, Number(deltaTime) || 0);
    let apexReached = this.pendingApexReached;
    const landingDetected = this.pendingLandingDetected;

    this.pendingApexReached = false;
    this.pendingLandingDetected = false;

    if (this.isAirborne) {
      const previousVelocity = this.yVelocity;

      this.airTime += safeDeltaTime;
      this.yVelocity -= this.gravity * safeDeltaTime;

      if (this.airTime >= this.maxAirTime && this.yVelocity > 0) {
        this.yVelocity = 0;
      }

      if (!this.hasReachedApex && previousVelocity > 0 && this.yVelocity <= 0) {
        this.hasReachedApex = true;
        apexReached = true;
      }
    }

    return {
      yVelocity: this.yVelocity,
      isAirborne: this.isAirborne,
      apexReached,
      landingDetected,
    };
  }

  /**
   * Ends the airborne state when collision or ground contact is detected.
   */
  land() {
    if (!this.isAirborne && this.yVelocity === 0) {
      return;
    }

    this.isAirborne = false;
    this.yVelocity = 0;
    this.airTime = 0;
    this.hasReachedApex = false;
    this.pendingLandingDetected = true;
  }

  /**
   * Restores jump state to its grounded default.
   */
  reset() {
    this.yVelocity = 0;
    this.isAirborne = false;
    this.airTime = 0;
    this.hasReachedApex = false;
    this.pendingApexReached = false;
    this.pendingLandingDetected = false;
  }
}

export default JumpCore;
