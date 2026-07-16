import { GameModeInterface, ModePhase } from '../GameModeInterface.js';
import { feelConfig } from '../../systems/feelConfig.js';
import { FixedStepLoop } from '../../core/FixedStepLoop.js';
import { InputBuffer } from '../../systems/InputBuffer.js';
import { StateMachine } from '../../systems/StateMachine.js';
import { SensoryBus } from '../../systems/SensoryBus.js';
import { ArcDrive } from '../../systems/ArcDrive.js';
import SkateScene from './SkateScene.js';

/** Ride/carve phases. */
export const SkatePhase = Object.freeze({
  CRUISE: 'Cruise',
  AIR:    'Air',
  GRIND:  'Grind',
});

function clampValue(v, min, max) { return v < min ? min : v > max ? max : v; }

/**
 * Skateboarding — the ride/carve archetype on the shared feel systems:
 * fixed-step cruise with pump/brake, ollie on the variable-gravity curve,
 * GRIND LOCK-ON via ArcDrive (the dunk drive interface, reused as specced),
 * SensoryBus lands/grind-hits, endless Venice strip. Placeholder assets
 * per the feel gate; every number // TUNE(elijah) in feelConfig.skate.
 */
export class SkateMode extends GameModeInterface {
  constructor(modeIdOrCanvas, maybeCanvas, container) {
    const hasExplicitModeId = typeof modeIdOrCanvas === 'string';
    const modeId = hasExplicitModeId ? modeIdOrCanvas : 'skateboarding';
    const canvas = hasExplicitModeId ? maybeCanvas : modeIdOrCanvas;
    super(modeId, canvas);

    this.container = container ?? null;
    this.scene = null;
    this._disposed = false;
    this._loop = null;
    this._rafId = null;
    this._lastRafTs = 0;
    this._sensory = null;
    this._inputBuffer = new InputBuffer({ windowMs: feelConfig.input.bufferMs });

    // Sim state (preallocated)
    this.playerPosition = { x: 0, y: 0, z: 0 };
    this._speed = feelConfig.skate.cruiseSpeed;
    this._verticalVelocity = 0;
    this._stick = { x: 0, y: 0, magnitude: 0 };
    this._prevPos = { x: 0, y: 0, z: 0 };
    this._renderPos = { x: 0, y: 0, z: 0 };
    this._grindDrive = new ArcDrive();
    this._grindT = 0; // progress along the rail while grinding

    this._fsm = new StateMachine({
      initial: SkatePhase.CRUISE,
      states: {
        [SkatePhase.CRUISE]: {},
        [SkatePhase.AIR]: {},
        [SkatePhase.GRIND]: {},
      },
    });

    this.state = this._createInitialState();
  }

  _createInitialState() {
    return {
      phase: ModePhase.WARMUP,
      score: 0,
      combo: 0,
      bestGrindMs: 0,
      lastTrick: '',
      distanceM: 0,
    };
  }

  async start(container) {
    this.dispose();
    this._disposed = false;
    this.container = container ?? this.container;

    this.scene = new SkateScene(this.canvas, {});
    await this.scene.init();
    if (this._disposed) {
      this.scene.dispose();
      this.scene = null;
      return this.getState();
    }

    this.playerPosition.x = 0; this.playerPosition.y = 0; this.playerPosition.z = 0;
    this._speed = feelConfig.skate.cruiseSpeed;
    this._verticalVelocity = 0;
    this._grindDrive.cancel();
    this._inputBuffer.clear();
    this._fsm.transition(SkatePhase.CRUISE);
    this.state = { ...this._createInitialState(), phase: ModePhase.ACTIVE };

    this._loop = new FixedStepLoop({
      hz: feelConfig.timestepHz,
      maxAccumulatedMs: feelConfig.maxAccumulatedMs,
      update: (dt) => this._fixedUpdate(dt),
      render: (alpha) => this._renderInterpolate(alpha),
    });
    this._loop.start();
    if (this.scene && !this.scene.isFallback && this.scene.setFrameCallback) {
      this.scene.setFrameCallback((dtMs) => this._loop.tick(dtMs));
    } else {
      this._startFallbackDriver();
    }

    this._sensory = new SensoryBus({
      camera: this.scene && !this.scene.isFallback ? this.scene : null,
      loop: this._loop,
      sfx: {
        impact: '/audio/sfx_punch_impact.mp3',
        swoosh: '/audio/sfx_basketball_swoosh.mp3',
      },
    });

    return this.getState();
  }

  /** Gamepad wiring (self-contained — ride/carve has its own contract). */
  getGamepadProps() {
    return {
      onLeftStick: (vec) => {
        this._stick.x = vec.x ?? 0;
        this._stick.y = vec.y ?? 0;
        this._stick.magnitude = Math.min(1, Math.hypot(this._stick.x, this._stick.y));
      },
      onFaceButton: (id) => {
        if (id === 'cross') this.update({ type: 'ollie' });
        if (id === 'triangle') this.update({ type: 'grind' });
      },
    };
  }

  update(inputEvent = {}) {
    if (this.state.phase !== ModePhase.ACTIVE) return this.getState();
    const { type, payload = {} } = inputEvent;

    if (payload.position && typeof payload.position === 'object') {
      this.playerPosition = { ...this.playerPosition, ...payload.position };
    }
    if (payload.stick) {
      this._stick.x = payload.stick.x ?? 0;
      this._stick.y = payload.stick.y ?? 0;
      this._stick.magnitude = Math.min(1, Math.hypot(this._stick.x, this._stick.y));
    }

    if (type === 'ollie') this._inputBuffer.press('ollie');
    if (type === 'grind') this._inputBuffer.press('grind');

    return this.getState();
  }

  /** @private — one fixed step */
  _fixedUpdate(dt) {
    if (this.state.phase !== ModePhase.ACTIVE) return;
    const k = feelConfig.skate;
    const g = feelConfig.gravity;

    this._prevPos.x = this.playerPosition.x;
    this._prevPos.y = this.playerPosition.y;
    this._prevPos.z = this.playerPosition.z;

    this._fsm.update(dt);

    switch (this._fsm.current) {
      case SkatePhase.CRUISE: {
        // Pump/brake + steer
        this._speed = clampValue(
          this._speed + (-this._stick.y) * k.pumpAccel * dt * (this._stick.y < 0 ? 1 : k.brakeDecel / k.pumpAccel),
          k.minSpeed, k.maxSpeed
        );
        this.playerPosition.x = clampValue(
          this.playerPosition.x + this._stick.x * k.steerSpeed * dt,
          -k.laneHalfWidth, k.laneHalfWidth
        );
        this.playerPosition.z -= this._speed * dt;
        this.state.distanceM += this._speed * dt;

        if (this._inputBuffer.consume('ollie')) {
          this._verticalVelocity = k.ollieImpulse;
          this.state.score += k.olliePoints;
          this.state.combo += 1;
          this.state.lastTrick = 'OLLIE';
          this._sensory?.emit({ sfx: 'swoosh', volume: 0.5 });
          this._fsm.transition(SkatePhase.AIR);
        }
        break;
      }

      case SkatePhase.AIR: {
        // Keep carrying forward + steer slightly
        this.playerPosition.x = clampValue(
          this.playerPosition.x + this._stick.x * k.steerSpeed * 0.5 * dt,
          -k.laneHalfWidth, k.laneHalfWidth
        );
        this.playerPosition.z -= this._speed * dt;
        this.state.distanceM += this._speed * dt;

        // Variable gravity curve (shared feel)
        const scale = this._verticalVelocity > g.peakVelocityWindow ? g.ascentScale
          : this._verticalVelocity >= -g.peakVelocityWindow ? g.peakScale
          : g.descentScale;
        this._verticalVelocity -= g.base * scale * dt;
        this.playerPosition.y += this._verticalVelocity * dt;

        // Grind lock-on: airborne, near the rail, grind pressed
        if (this._inputBuffer.consume('grind') && this._nearRail()) {
          this._beginGrind();
          break;
        }

        if (this.playerPosition.y <= 0 && this._verticalVelocity < 0) {
          this.playerPosition.y = 0;
          const hard = this._verticalVelocity < -feelConfig.sensory.bigLandingVy;
          this._verticalVelocity = 0;
          this._sensory?.emit({
            sfx: 'impact',
            volume: hard ? 0.9 : 0.4,
            shake: hard ? feelConfig.sensory.slamShake * 0.6 : feelConfig.sensory.landShake,
            hitStopMs: hard ? feelConfig.sensory.bigLandHitStopMs : 0,
          });
          this._fsm.transition(SkatePhase.CRUISE);
        }
        break;
      }

      case SkatePhase.GRIND: {
        // ArcDrive carried us onto the rail; slide along it
        if (this._grindDrive.active) {
          this._grindDrive.advance(dt, this.playerPosition);
          break;
        }
        this._grindT += (k.rail.grindSpeed * dt) / Math.abs(k.rail.zEnd - k.rail.zStart);
        this.playerPosition.x = k.rail.x;
        this.playerPosition.y = k.rail.y;
        this.playerPosition.z = k.rail.zStart + (k.rail.zEnd - k.rail.zStart) * Math.min(1, this._grindT);
        this.state.score += k.rail.pointsPerSec * dt;
        this.state.bestGrindMs = Math.max(this.state.bestGrindMs, this._fsm.timeInState * 1000);

        // Dismount: end of rail, or ollie off early
        const done = this._grindT >= 1;
        if (done || this._inputBuffer.consume('ollie')) {
          this._verticalVelocity = k.ollieImpulse * 0.7;
          this.state.combo += 1;
          this.state.lastTrick = done ? 'FULL RAIL' : 'GRIND POP';
          this._sensory?.emit({ sfx: 'swoosh', volume: 0.6, shake: 0.05 });
          this._fsm.transition(SkatePhase.AIR);
        }
        break;
      }

      default:
        break;
    }

    // Endless strip: wrap the world
    if (this.playerPosition.z < -feelConfig.skate.stripLength) {
      this.playerPosition.z += feelConfig.skate.stripLength;
      this._prevPos.z += feelConfig.skate.stripLength;
    }
  }

  /** @private */
  _nearRail() {
    const r = feelConfig.skate.rail;
    const withinZ = this.playerPosition.z <= r.zStart + r.lockRadius && this.playerPosition.z >= r.zEnd;
    const dx = Math.abs(this.playerPosition.x - r.x);
    return withinZ && dx <= r.lockRadius;
  }

  /** @private — ArcDrive lock-on to the rail entry point (no jerk). */
  _beginGrind() {
    const r = feelConfig.skate.rail;
    const entryZ = Math.min(r.zStart, Math.max(r.zEnd, this.playerPosition.z - 0.5));
    this._grindDrive.begin({
      start: this.playerPosition,
      target: { x: r.x, y: r.y, z: entryZ },
      apexY: Math.max(this.playerPosition.y, r.y) + 0.15,
      durationMs: 200, // TUNE(elijah) — snap-to-rail time
    });
    this._grindT = Math.abs(entryZ - r.zStart) / Math.abs(r.zEnd - r.zStart);
    this._verticalVelocity = 0;
    this.state.combo += 1;
    this.state.lastTrick = 'GRIND';
    this._sensory?.emit({ sfx: 'impact', volume: 0.5, shake: 0.06 });
    this._fsm.transition(SkatePhase.GRIND);
  }

  /** @private */
  _renderInterpolate(alpha) {
    const p = this._prevPos, c = this.playerPosition, r = this._renderPos;
    r.x = p.x + (c.x - p.x) * alpha;
    r.y = p.y + (c.y - p.y) * alpha;
    r.z = p.z + (c.z - p.z) * alpha;
    this.scene?.updatePlayerTransform?.(r);
  }

  /** @private */
  _startFallbackDriver() {
    if (typeof window === 'undefined' || !window.requestAnimationFrame) return;
    this._lastRafTs = 0;
    const step = (ts) => {
      if (!this._loop || !this._loop.running) return;
      const dtMs = this._lastRafTs ? ts - this._lastRafTs : 1000 / feelConfig.timestepHz;
      this._lastRafTs = ts;
      this._loop.tick(dtMs);
      this._rafId = window.requestAnimationFrame(step);
    };
    this._rafId = window.requestAnimationFrame(step);
  }

  getState() {
    return {
      modeId: this.getModeId(),
      phase: this.state.phase,
      skatePhase: this._fsm.current,
      score: Math.round(this.state.score),
      combo: this.state.combo,
      bestGrindMs: Math.round(this.state.bestGrindMs),
      lastTrick: this.state.lastTrick,
      distanceM: Math.round(this.state.distanceM),
      speed: Math.round(this._speed * 10) / 10,
      height: Math.round(this.playerPosition.y * 100) / 100,
    };
  }

  end() {
    this.state.phase = ModePhase.FINISHED;
    return this.getState();
  }

  dispose() {
    this._disposed = true;
    if (this._loop) { this._loop.stop(); this._loop = null; }
    if (this._rafId !== null && typeof window !== 'undefined') {
      window.cancelAnimationFrame(this._rafId);
      this._rafId = null;
    }
    this._sensory?.dispose();
    this._sensory = null;
    this._inputBuffer.clear();
    this._grindDrive.cancel();
    this.scene?.setFrameCallback?.(null);
    this.scene?.dispose();
    this.scene = null;
    this._fsm.transition(SkatePhase.CRUISE);
    this.playerPosition = { x: 0, y: 0, z: 0 };
    this._speed = feelConfig.skate.cruiseSpeed;
    this._verticalVelocity = 0;
    this.state = this._createInitialState();
  }
}

export default SkateMode;
