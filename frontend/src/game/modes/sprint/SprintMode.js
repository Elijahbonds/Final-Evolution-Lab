import { GameModeInterface, ModePhase } from '../GameModeInterface.js';
import { feelConfig } from '../../systems/feelConfig.js';
import { FixedStepLoop } from '../../core/FixedStepLoop.js';
import { StateMachine } from '../../systems/StateMachine.js';
import { RhythmCadence } from '../../systems/RhythmCadence.js';
import { SensoryBus } from '../../systems/SensoryBus.js';
import SprintScene from './SprintScene.js';

/** Race flow: false starts are real — a tap before GO restarts the race. */
export const SprintPhase = Object.freeze({
  READY:  'Ready',
  SET:    'Set',
  GO:     'Go',
  RUN:    'Run',
  FINISH: 'Finish',
});

function clampValue(v, min, max) { return v < min ? min : v > max ? max : v; }

/**
 * Sprint — 100m dash on the rhythm/UI archetype: alternating footstrike
 * taps (□=left, ○=right) evaluated by RhythmCadence; consistent cadence at
 * the target tempo builds speed, stumbles bleed it. READY→SET→GO gate with
 * false-start restarts. All numbers feelConfig.sprint TUNE(elijah).
 */
export class SprintMode extends GameModeInterface {
  constructor(modeIdOrCanvas, maybeCanvas, container) {
    const hasExplicitModeId = typeof modeIdOrCanvas === 'string';
    const modeId = hasExplicitModeId ? modeIdOrCanvas : 'sprint';
    const canvas = hasExplicitModeId ? maybeCanvas : modeIdOrCanvas;
    super(modeId, canvas);

    this.container = container ?? null;
    this.scene = null;
    this._disposed = false;
    this._loop = null;
    this._rafId = null;
    this._lastRafTs = 0;
    this._sensory = null;
    this._cadence = new RhythmCadence({
      targetIntervalMs: feelConfig.sprint.targetIntervalMs,
      perfectMs: feelConfig.sprint.perfectWindowMs,
      goodMs: feelConfig.sprint.goodWindowMs,
    });

    this.playerPosition = { x: 0, y: 0, z: 0 };
    this._speed = 0;
    this._prevZ = 0;
    this._renderPos = { x: 0, y: 0, z: 0 };
    this._raceClockS = 0;
    this._falseStarts = 0;

    this._fsm = new StateMachine({
      initial: SprintPhase.READY,
      states: {
        [SprintPhase.READY]: {},
        [SprintPhase.SET]: {},
        [SprintPhase.GO]: {
          enter: () => {
            this.systems?.audio?.playEvent?.('whistle');
            this._sensory?.emit({ sfx: 'impact', volume: 0.6 }); // the gun
          },
        },
        [SprintPhase.RUN]: {},
        [SprintPhase.FINISH]: {},
      },
    });

    this.state = this._createInitialState();
  }

  _createInitialState() {
    return {
      phase: ModePhase.WARMUP,
      timeS: 0,
      distanceM: 0,
      topSpeed: 0,
      lastStep: '',
      falseStarts: this._falseStarts ?? 0,
      finishTimeS: null,
    };
  }

  async start(container) {
    this.dispose();
    this._disposed = false;
    this.container = container ?? this.container;
    this.systems = {}; // sprint uses the sensory bus only

    this.scene = new SprintScene(this.canvas, {});
    await this.scene.init();
    if (this._disposed) {
      this.scene.dispose();
      this.scene = null;
      return this.getState();
    }

    this.playerPosition.x = 0; this.playerPosition.y = 0; this.playerPosition.z = 0;
    this._speed = 0;
    this._raceClockS = 0;
    this._cadence.reset();
    this._fsm.transition(SprintPhase.READY);
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
        crowd:  '/audio/sfx_crowd_cheer.mp3',
      },
    });

    return this.getState();
  }

  getGamepadProps() {
    return {
      onFaceButton: (id) => {
        if (id === 'square') this.update({ type: 'step', payload: { side: 'L' } });
        if (id === 'circle') this.update({ type: 'step', payload: { side: 'R' } });
      },
    };
  }

  update(inputEvent = {}) {
    if (this.state.phase !== ModePhase.ACTIVE) return this.getState();
    const { type, payload = {} } = inputEvent;
    if (type !== 'step') return this.getState();

    const phase = this._fsm.current;
    if (phase === SprintPhase.READY || phase === SprintPhase.SET) {
      // FALSE START — back to the blocks.
      this._falseStarts += 1;
      this.state.falseStarts = this._falseStarts;
      this.state.lastStep = 'FALSE START';
      this._sensory?.emit({ sfx: 'impact', volume: 0.9, shake: 0.12 });
      this._fsm.transition(SprintPhase.READY);
      return this.getState();
    }
    if (phase === SprintPhase.FINISH) return this.getState();

    if (phase === SprintPhase.GO) this._fsm.transition(SprintPhase.RUN);

    const k = feelConfig.sprint;
    const quality = this._cadence.tap(payload.side === 'R' ? 'R' : 'L');
    let impulse = 0;
    if (quality === 'perfect') impulse = k.perfectImpulse;
    else if (quality === 'good' || quality === 'first') impulse = k.goodImpulse;
    else if (quality === 'off') impulse = k.offImpulse;
    else { // fault — stumble
      this._speed *= k.stumblePenalty;
      this.state.lastStep = 'STUMBLE';
      this._sensory?.emit({ sfx: 'impact', volume: 0.5, shake: 0.08 });
      return this.getState();
    }
    this._speed = clampValue(this._speed + impulse, 0, k.maxSpeed);
    this.state.lastStep = quality.toUpperCase();
    if (quality === 'perfect') this._sensory?.emit({ sfx: 'swoosh', volume: 0.35 });
    return this.getState();
  }

  /** @private */
  _fixedUpdate(dt) {
    if (this.state.phase !== ModePhase.ACTIVE) return;
    const k = feelConfig.sprint;
    this._fsm.update(dt);

    switch (this._fsm.current) {
      case SprintPhase.READY:
        if (this._fsm.timeInState * 1000 >= k.readyMs) this._fsm.transition(SprintPhase.SET);
        break;
      case SprintPhase.SET:
        if (this._fsm.timeInState * 1000 >= k.setMs) this._fsm.transition(SprintPhase.GO);
        break;
      case SprintPhase.GO:
      case SprintPhase.RUN: {
        this._raceClockS += dt;
        this._prevZ = this.playerPosition.z;
        this._speed = Math.max(0, this._speed - k.drag * dt);
        this.playerPosition.z -= this._speed * dt;
        this.state.timeS = Math.round(this._raceClockS * 100) / 100;
        this.state.distanceM = Math.min(k.raceDistanceM, Math.round(-this.playerPosition.z * 10) / 10);
        this.state.topSpeed = Math.max(this.state.topSpeed, Math.round(this._speed * 10) / 10);
        if (-this.playerPosition.z >= k.raceDistanceM) {
          this.state.finishTimeS = this.state.timeS;
          this._sensory?.emit({
            sfx: 'crowd', volume: feelConfig.sensory.crowdVolume,
            shake: 0.15, hitStopMs: 80, rumbleMs: feelConfig.sensory.rumbleMs,
          });
          this._fsm.transition(SprintPhase.FINISH);
          this.end();
        }
        break;
      }
      default:
        break;
    }
  }

  /** @private */
  _renderInterpolate(alpha) {
    const r = this._renderPos;
    r.x = this.playerPosition.x;
    r.y = this.playerPosition.y;
    r.z = this._prevZ + (this.playerPosition.z - this._prevZ) * alpha;
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
      racePhase: this._fsm.current,
      timeS: this.state.timeS,
      distanceM: this.state.distanceM,
      speed: Math.round(this._speed * 10) / 10,
      topSpeed: this.state.topSpeed,
      lastStep: this.state.lastStep,
      falseStarts: this.state.falseStarts,
      finishTimeS: this.state.finishTimeS,
      cadence: { ...this._cadence.stats },
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
    this._cadence.reset();
    this.scene?.setFrameCallback?.(null);
    this.scene?.dispose();
    this.scene = null;
    this._fsm.transition(SprintPhase.READY);
    this.playerPosition = { x: 0, y: 0, z: 0 };
    this._speed = 0;
    this.state = this._createInitialState();
  }
}

export default SprintMode;
