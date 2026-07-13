const EPSILON = 1e-4;

function createVector(x = 0, y = 0, z = 0) {
  return { x, y, z };
}

function cloneVector(vector) {
  return { x: vector.x, y: vector.y, z: vector.z };
}

function normalizeVector(vector) {
  const x = Number(vector?.x) || 0;
  const y = Number(vector?.y) || 0;
  const z = Number(vector?.z) || 0;
  const magnitude = Math.hypot(x, y, z);

  if (magnitude <= EPSILON) {
    return createVector();
  }

  return createVector(x / magnitude, y / magnitude, z / magnitude);
}

export class DodgeCore {
  /**
   * @param {{ dashSpeed?: number, dashDuration?: number, cooldown?: number, iFrameDuration?: number }} [config]
   */
  constructor(config = {}) {
    // TODO: wire to Babylon.js TransformNode in the mode skin layer
    this.dashSpeed = config.dashSpeed ?? 14;
    this.dashDuration = config.dashDuration ?? 0.18;
    this.cooldown = config.cooldown ?? 0.9;
    this.iFrameDuration = config.iFrameDuration ?? 0.12;
    this.reset();
  }

  /**
   * Starts a dodge in the supplied direction when the cooldown has expired.
   * @param {{ x?: number, y?: number, z?: number }} [directionVector]
   * @returns {boolean}
   */
  dodge(directionVector = {}) {
    if (this.cooldownRemaining > 0 || this.isDodging) {
      return false;
    }

    const normalizedDirection = normalizeVector(directionVector);

    if (Math.hypot(normalizedDirection.x, normalizedDirection.y, normalizedDirection.z) <= EPSILON) {
      return false;
    }

    this.direction = normalizedDirection;
    this.isDodging = true;
    this.dashTimeRemaining = this.dashDuration;
    this.cooldownRemaining = this.cooldown;
    this.iFrameRemaining = this.iFrameDuration;
    this.velocity = createVector(
      this.direction.x * this.dashSpeed,
      this.direction.y * this.dashSpeed,
      this.direction.z * this.dashSpeed,
    );

    return true;
  }

  /**
   * Advances dodge timing, cooldown state, and invincibility frames.
   * @param {number} deltaTime
   * @returns {{ isDodging: boolean, isInvincible: boolean, cooldownRemaining: number, velocity: { x: number, y: number, z: number } }}
   */
  update(deltaTime = 0) {
    const safeDeltaTime = Math.max(0, Number(deltaTime) || 0);

    this.cooldownRemaining = Math.max(0, this.cooldownRemaining - safeDeltaTime);
    this.iFrameRemaining = Math.max(0, this.iFrameRemaining - safeDeltaTime);

    if (this.isDodging) {
      this.dashTimeRemaining = Math.max(0, this.dashTimeRemaining - safeDeltaTime);

      if (this.dashTimeRemaining === 0) {
        this.isDodging = false;
        this.velocity = createVector();
      } else {
        this.velocity = createVector(
          this.direction.x * this.dashSpeed,
          this.direction.y * this.dashSpeed,
          this.direction.z * this.dashSpeed,
        );
      }
    }

    return {
      isDodging: this.isDodging,
      isInvincible: this.iFrameRemaining > 0,
      cooldownRemaining: this.cooldownRemaining,
      velocity: cloneVector(this.velocity),
    };
  }

  /**
   * Restores dodge state and clears active cooldowns.
   */
  reset() {
    this.direction = createVector();
    this.velocity = createVector();
    this.isDodging = false;
    this.dashTimeRemaining = 0;
    this.cooldownRemaining = 0;
    this.iFrameRemaining = 0;
  }
}

export default DodgeCore;
