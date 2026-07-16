import { GameModeInterface, ModePhase } from '../GameModeInterface.js';
import { feelConfig } from '../../systems/feelConfig.js';
import { FixedStepLoop } from '../../core/FixedStepLoop.js';
import { StateMachine } from '../../systems/StateMachine.js';
import { AirTrick } from '../../systems/AirTrick.js';
import { RhythmCadence } from '../../systems/RhythmCadence.js';
import { SensoryBus } from '../../systems/SensoryBus.js';
import RunwayScene from './RunwayScene.js';

export const AirPhase = Object.freeze({
  RUN:   'Run',
  AIR:   'Air',
  LAND:  'Land',
  DONE:  'Done',
});

const GRADE_POINTS = { stuck: 2.0, clean: 1.0, sketchy: 0.5, crash: 0 }; // TUNE(elijah)

function clampValue(v, min, max) { return v < min ? min : v > max ? max : v; }

/**
 * AirSessionMode — shared base for run-up → launch → tricks → landing modes
 * (gymnastics vault, big-air). Subclasses define the run-up (cadence taps vs
 * carve) via _advanceRun(dt) and the config section (this._cfg).
 * Attempts per round, AirTrick judging, SensoryBus landings.
 */
export class AirSessionMode extends GameModeInterface {
  constructor(modeId, canvas, container, { configKey, theme }) {
    super(modeId, canvas);
    this.container = container ?? null;
    this._cfgKey = configKey;
    this._theme = theme;
    this.scene = null;
    this._disposed = false;
    this._loop = null;
    this._rafId = null;
    this._lastRafTs = 0;
    this._sensory = null;
    this._trick = new AirTrick();
    this._cadence = new RhythmCadence({ targetIntervalMs: 240 }); // TUNE(elijah)

    this.playerPosition = { x: 0, y: 0, z: 0 };
    this._speed = 0;
    this._verticalVelocity = 0;
    this._prevPos = { x: 0, y: 0, z: 0 };
    this._renderPos = { x: 0, y: 0, z: 0 };
    this._spinTurns = 0;
    this._attempt = 0;

    this._fsm = new StateMachine({
      initial: AirPhase.RUN,
      states: {
        [AirPhase.RUN]: {},
        [AirPhase.AIR]: {},
        [AirPhase.LAND]: {},
        [AirPhase.DONE]: {},
      },
    });

    this.state = this._createInitialState();
  }

  get _cfg() { return feelConfig[this._cfgKey]; }

  _createInitialState() {
    return {
      phase: ModePhase.WARMUP,
      score: 0,
      attempt: 0,
      attempts: [],
      lastGrade: '',
      lastRotations: 0,
      launchSpeed: 0,
    };
  }

  async start(container) {
    this.dispose();
    this._disposed = false;
    this.container = container ?? this.container;

    this.scene = new RunwayScene(this.canvas, this._theme);
    await this.scene.init();
    if (this._disposed) {
      this.scene.dispose();
      this.scene = null;
      return this.getState();
    }

    this._resetAttempt(true);
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

  _resetAttempt(first = false) {
    this.playerPosition.x = 0; this.playerPosition.y = 0; this.playerPosition.z = 0;
    this._speed = 0;
    this._verticalVelocity = 0;
    this._spinTurns = 0;
    this._trick.reset();
    this._cadence.reset();
    if (!first) this._attempt = this.state.attempt;
    this._fsm.transition(AirPhase.RUN);
  }

  getGamepadProps() {
    return {
      onFaceButton: (id) => {
        if (id === 'square') this.update({ type: 'step', payload: { side: 'L' } });
        if (id === 'circle') this.update({ type: 'step', payload: { side: 'R' } });
        if (id === 'triangle') this.update({ type: 'trick' });
        if (id === 'cross') this.update({ type: 'stick' });
      },
    };
  }

  update(inputEvent = {}) {
    if (this.state.phase !== ModePhase.ACTIVE) return this.getState();
    const { type, payload = {} } = inputEvent;
    const phase = this._fsm.current;

    if (type === 'step' && phase === AirPhase.RUN) this._onRunTap(payload.side === 'R' ? 'R' : 'L');
    if (type === 'trick' && phase === AirPhase.AIR) {
      this._trick.trick();
      this._spinTurns = this._trick.rotation;
      this._sensory?.emit({ sfx: 'swoosh', volume: 0.4 });
    }
    if (type === 'stick' && phase === AirPhase.AIR) this._trick.stick();
    return this.getState();
  }

  /** Subclass hook: a run-phase tap. Default: cadence builds speed. */
  _onRunTap(side) {
    const q = this._cadence.tap(side);
    const k = this._cfg;
    if (q === 'perfect') this._speed = clampValue(this._speed + k.perfectImpulse, 0, k.maxRunSpeed);
    else if (q === 'good' || q === 'first') this._speed = clampValue(this._speed + k.goodImpulse, 0, k.maxRunSpeed);
    else if (q === 'fault') this._speed *= 0.7;
  }

  /** Subclass hook: passive run-phase speed change per fixed step.
   *  Negative runDrag = slope acceleration (big-air); clamped to maxRunSpeed. */
  _runDrift(dt) {
    this._speed = clampValue(this._speed - this._cfg.runDrag * dt, 0, this._cfg.maxRunSpeed);
  }

  _fixedUpdate(dt) {
    if (this.state.phase !== ModePhase.ACTIVE) return;
    const k = this._cfg;
    const g = feelConfig.gravity;

    this._prevPos.x = this.playerPosition.x;
    this._prevPos.y = this.playerPosition.y;
    this._prevPos.z = this.playerPosition.z;
    this._fsm.update(dt);

    switch (this._fsm.current) {
      case AirPhase.RUN: {
        this._runDrift(dt);
        this.playerPosition.z -= this._speed * dt;
        if (-this.playerPosition.z >= -k.launchZ) {
          // Launch: impulse scales with run speed (weak run = weak air)
          this._verticalVelocity = k.baseLaunch + (this._speed / k.maxRunSpeed) * k.speedLaunchBonus;
          this.state.launchSpeed = Math.round(this._speed * 10) / 10;
          this._sensory?.emit({ sfx: 'impact', volume: 0.6, shake: 0.06 });
          this._fsm.transition(AirPhase.AIR);
        }
        break;
      }
      case AirPhase.AIR: {
        this.playerPosition.z -= Math.max(2.0, this._speed * 0.8) * dt;
        const scale = this._verticalVelocity > g.peakVelocityWindow ? g.ascentScale
          : this._verticalVelocity >= -g.peakVelocityWindow ? g.peakScale
          : g.descentScale;
        this._verticalVelocity -= g.base * scale * dt;
        this.playerPosition.y += this._verticalVelocity * dt;
        if (this.playerPosition.y <= 0 && this._verticalVelocity < 0) {
          this.playerPosition.y = 0;
          this._verticalVelocity = 0;
          const judge = this._trick.land();
          this._spinTurns = 0;
          const pts = Math.round(
            (k.basePoints + judge.rotations * k.pointsPerRotation) * GRADE_POINTS[judge.grade]
          );
          this.state.score += pts;
          this.state.lastGrade = judge.grade.toUpperCase();
          this.state.lastRotations = judge.rotations;
          this.state.attempt += 1;
          this.state.attempts = [...this.state.attempts, { grade: judge.grade, rotations: judge.rotations, pts }];
          this._sensory?.emit({
            sfx: judge.grade === 'crash' ? 'impact' : judge.grade === 'stuck' ? 'crowd' : 'impact',
            volume: judge.grade === 'crash' ? 1 : 0.7,
            shake: judge.grade === 'crash' ? 0.25 : judge.grade === 'stuck' ? 0.18 : 0.1,
            hitStopMs: judge.grade === 'stuck' || judge.grade === 'crash' ? 90 : 0,
          });
          this._fsm.transition(AirPhase.LAND);
        }
        break;
      }
      case AirPhase.LAND: {
        if (this._fsm.timeInState * 1000 >= 900) { // TUNE(elijah) — beat between attempts
          if (this.state.attempt >= k.attemptsPerRound) {
            this._fsm.transition(AirPhase.DONE);
            this.end();
          } else {
            this._resetAttempt();
          }
        }
        break;
      }
      default:
        break;
    }
  }

  _renderInterpolate(alpha) {
    const p = this._prevPos, c = this.playerPosition, r = this._renderPos;
    r.x = p.x + (c.x - p.x) * alpha;
    r.y = p.y + (c.y - p.y) * alpha;
    r.z = p.z + (c.z - p.z) * alpha;
    this.scene?.updatePlayerTransform?.(r, this._spinTurns);
  }

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
      airPhase: this._fsm.current,
      score: this.state.score,
      attempt: this.state.attempt,
      attemptsPerRound: this._cfg.attemptsPerRound,
      attempts: this.state.attempts,
      lastGrade: this.state.lastGrade,
      lastRotations: this.state.lastRotations,
      launchSpeed: this.state.launchSpeed,
      speed: Math.round(this._speed * 10) / 10,
      height: Math.round(this.playerPosition.y * 100) / 100,
      spinTurns: this._spinTurns,
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
    this._trick.reset();
    this._cadence.reset();
    this.scene?.setFrameCallback?.(null);
    this.scene?.dispose();
    this.scene = null;
    this._fsm.transition(AirPhase.RUN);
    this.playerPosition = { x: 0, y: 0, z: 0 };
    this._speed = 0;
    this.state = this._createInitialState();
  }
}

export default AirSessionMode;
