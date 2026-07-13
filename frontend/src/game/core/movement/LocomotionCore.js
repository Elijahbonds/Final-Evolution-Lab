const EPSILON = 1e-4;

function cloneVector(vector) {
  return { x: vector.x, y: vector.y, z: vector.z };
}

function createVector(x = 0, y = 0, z = 0) {
  return { x, y, z };
}

function getGroundMagnitude(vector) {
  return Math.hypot(vector.x, vector.z);
}

function normalizeGroundVector(vector) {
  const x = Number(vector?.x) || 0;
  const z = Number(vector?.z) || 0;
  const magnitude = Math.hypot(x, z);

  if (magnitude <= EPSILON) {
    return createVector();
  }

  return createVector(x / magnitude, 0, z / magnitude);
}

function moveTowards(current, target, maxDelta) {
  if (Math.abs(target - current) <= maxDelta) {
    return target;
  }

  return current + Math.sign(target - current) * maxDelta;
}

export class LocomotionCore {
  /**
   * @param {{ maxSpeed?: number, acceleration?: number, friction?: number }} [config]
   */
  constructor(config = {}) {
    // TODO: wire to Babylon.js TransformNode in the mode skin layer
    this.maxSpeed = config.maxSpeed ?? 7;
    this.acceleration = config.acceleration ?? 30;
    this.friction = config.friction ?? 18;
    this.reset();
  }

  /**
   * Advances ground movement using the current input direction.
   * @param {{ x?: number, y?: number, z?: number }} [inputVector]
   * @param {number} deltaTime
   * @returns {{ velocity: { x: number, y: number, z: number }, position: { x: number, y: number, z: number }, isMoving: boolean }}
   */
  update(inputVector = {}, deltaTime = 0) {
    const direction = normalizeGroundVector(inputVector);
    const safeDeltaTime = Math.max(0, Number(deltaTime) || 0);

    this.direction = direction;

    if (getGroundMagnitude(direction) > EPSILON) {
      const targetVelocityX = direction.x * this.maxSpeed;
      const targetVelocityZ = direction.z * this.maxSpeed;
      const maxDelta = this.acceleration * safeDeltaTime;

      this.velocity.x = moveTowards(this.velocity.x, targetVelocityX, maxDelta);
      this.velocity.z = moveTowards(this.velocity.z, targetVelocityZ, maxDelta);
    } else {
      this.applyFriction(safeDeltaTime);
    }

    this.position.x += this.velocity.x * safeDeltaTime;
    this.position.z += this.velocity.z * safeDeltaTime;
    this.isMoving = getGroundMagnitude(this.velocity) > EPSILON;

    return {
      velocity: cloneVector(this.velocity),
      position: cloneVector(this.position),
      isMoving: this.isMoving,
    };
  }

  /**
   * Applies horizontal deceleration when no movement input is present.
   * @param {number} deltaTime
   */
  applyFriction(deltaTime = 0) {
    const safeDeltaTime = Math.max(0, Number(deltaTime) || 0);
    const maxDelta = this.friction * safeDeltaTime;

    this.velocity.x = moveTowards(this.velocity.x, 0, maxDelta);
    this.velocity.z = moveTowards(this.velocity.z, 0, maxDelta);

    if (Math.abs(this.velocity.x) <= EPSILON) {
      this.velocity.x = 0;
    }

    if (Math.abs(this.velocity.z) <= EPSILON) {
      this.velocity.z = 0;
    }
  }

  /**
   * Restores locomotion state to its initial values.
   */
  reset() {
    this.velocity = createVector();
    this.position = createVector();
    this.direction = createVector();
    this.isMoving = false;
  }
}

export default LocomotionCore;
