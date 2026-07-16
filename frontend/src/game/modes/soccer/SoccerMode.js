import { GameModeInterface, ModePhase } from '../GameModeInterface.js';
import InputSystem from '../../input/InputSystem.js';
import { SensoryBus } from '../../systems/SensoryBus.js';
import { feelConfig } from '../../systems/feelConfig.js';
import SoccerScene from './SoccerScene.js';

const TOTAL_SHOTS = 5;

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function resolveShotZone(x) {
  if (x < -0.33) return 'left';
  if (x > 0.33) return 'right';
  return 'center';
}

export class SoccerMode extends GameModeInterface {
  constructor(modeIdOrCanvas, maybeCanvas, container) {
    const hasExplicitModeId = typeof modeIdOrCanvas === 'string';
    const modeId = hasExplicitModeId ? modeIdOrCanvas : 'soccer';
    const canvas = hasExplicitModeId ? maybeCanvas : modeIdOrCanvas;
    super(modeId, canvas);

    this.container = container ?? null;
    this.scene = null;
    this.systems = null;
    this.input = null;
    this._sensory = null;
    this._disposed = false;
    this._resetTimer = null;
    this._shotLocked = false;
    this._shotPower = 0;
    this._aimX = 0;
    this._sprintHeld = false;
    this.state = this._createInitialState();
  }

  _createInitialState() {
    return {
      phase: ModePhase.WARMUP,
      shotsRemaining: TOTAL_SHOTS,
      goalsScored: 0,
      goalsConceded: 0,
      score: 0,
      prq: 50,
      lastResult: '',
      lastShotPower: 0,
      lastAimX: 0,
      winner: null,
    };
  }

  async start(container) {
    this.dispose();
    this.container = container ?? this.container;

    const { createSharedSystems } = await import('../../systems/index.js');
    this.systems = createSharedSystems(this.container);

    this._disposed = false;
    this.scene = new SoccerScene(this.canvas, this.systems);
    await this.scene.init();

    // Disposed while init awaited (StrictMode remount) — bail cleanly.
    if (this._disposed) {
      this.scene.dispose();
      this.scene = null;
      return this.getState();
    }
    this.scene.setCameraAngle('penalty');

    this._sensory = new SensoryBus({
      camera: this.scene && !this.scene.isFallback ? this.scene : null,
      sfx: {
        impact: '/audio/sfx_punch_impact.mp3',
        crowd:  '/audio/sfx_crowd_cheer.mp3',
        swoosh: '/audio/sfx_basketball_swoosh.mp3',
      },
    });

    this.input = new InputSystem(this.getModeId());
    this.input.onEvent = (event) => this.update(event);

    this._shotLocked = false;
    this._shotPower = 0;
    this._aimX = 0;
    this._sprintHeld = false;
    this.state = { ...this._createInitialState(), phase: ModePhase.ACTIVE };

    this.systems?.audio?.playEvent?.('whistle');
    return this.getState();
  }

  update(inputEvent = {}) {
    if (this.state.phase !== ModePhase.ACTIVE) return this.getState();

    const { type, payload = {} } = inputEvent;

    if (type === 'move') {
      if (payload.leftStick) {
        this._aimX = clamp(payload.leftStick.x ?? this._aimX, -1, 1);
        this.state.lastAimX = this._aimX;
      } else if (payload.direction === 'left') {
        this._aimX = clamp(this._aimX - 0.18, -1, 1);
        this.state.lastAimX = this._aimX;
      } else if (payload.direction === 'right') {
        this._aimX = clamp(this._aimX + 0.18, -1, 1);
        this.state.lastAimX = this._aimX;
      }
    }

    if (type === 'aim' && payload.rightStick) {
      this._aimX = clamp(payload.rightStick.x ?? this._aimX, -1, 1);
      this.state.lastAimX = this._aimX;
    }

    if (type === 'sprint') {
      this._sprintHeld = payload.active ?? true;
    }

    if (type === 'shoot' && typeof payload.power === 'number') {
      this._shotPower = clamp(payload.power, 0, 1);
      this.state.lastShotPower = this._shotPower;
      return this.getState();
    }

    if (type === 'shoot') {
      this._takeShot('driven');
    }

    if (type === 'chip') {
      this._takeShot('chip');
    }

    return this.getState();
  }

  _takeShot(shotType) {
    if (this._shotLocked || this.state.shotsRemaining <= 0) return;

    const power = clamp(
      shotType === 'chip' ? Math.max(0.28, this._shotPower * 0.88) : Math.max(0.18, this._shotPower),
      0,
      1
    );
    const aimX = clamp(this._aimX, -1, 1);
    const pressurePenalty = this._sprintHeld ? 0.08 : 0;
    const powerPenalty = Math.abs(power - 0.76) * 0.62;
    const aimPenalty = Math.abs(aimX) * 0.18;
    const accuracy = clamp(1 - powerPenalty - aimPenalty - pressurePenalty, 0.2, 0.97);
    const spray = (1 - accuracy) * (0.42 + Math.random() * 0.55);
    const actualAimX = aimX + (Math.random() * 2 - 1) * spray;
    const keeperZone = this._pickGoalkeeperZone(aimX);
    const shotZone = resolveShotZone(actualAimX);
    const missChance = Math.max(0, Math.abs(actualAimX) - 1) + Math.max(0, 0.22 - power) * 0.7;
    const didMiss = missChance > 0.22 || (power > 0.94 && Math.random() < 0.18);
    const isGoal = !didMiss && shotZone !== keeperZone;
    const result = didMiss ? 'MISS' : isGoal ? 'GOAL' : 'SAVE';

    this._shotLocked = true;
    this.state.shotsRemaining = Math.max(0, this.state.shotsRemaining - 1);
    this.state.lastShotPower = power;
    this.state.lastAimX = aimX;
    this.state.lastResult = result;

    // Kick thud on the strike frame
    this._sensory?.emit({ sfx: 'impact', volume: 0.5 + power * 0.5, shake: 0.05 + power * 0.06 });

    this.scene?.animateGoalkeeperDive?.(keeperZone);
    this.scene?.animateBallKick?.(
      {
        x: clamp(actualAimX * 4.1, -5.2, 5.2),
        y: shotType === 'chip' ? 1.0 + power * 0.8 : 0.35 + power * 0.65,
        z: didMiss ? -24.2 : -28.3,
        shotType,
      },
      power
    );

    if (isGoal) {
      this.state.goalsScored += 1;
      this.state.score += Math.round(110 + power * 120 + accuracy * 70);
      this.state.prq = clamp(this.state.prq + 8, 0, 100);
      this.systems?.audio?.playEvent?.('goal');
      this.systems?.audio?.playEvent?.('crowd_swell');
      this._sensory?.emit({
        sfx: 'crowd',
        volume: feelConfig.sensory.crowdVolume,
        shake: 0.2, // TUNE(elijah)
        rumbleMs: feelConfig.sensory.rumbleMs,
      });
      this.systems?.vfx?.trigger?.('goal', { points: 1 });
      this.systems?.vfx?.trigger?.('camera_shake', { intensity: 0.65, duration: 280 });
      this.scene?.setCameraAngle?.('goalkeeper');
      this.scene?.triggerGoalCelebration?.();
    } else {
      this.state.goalsConceded += 1;
      this.state.prq = clamp(this.state.prq - (didMiss ? 6 : 4), 0, 100);
      this.systems?.audio?.playEvent?.('bounce');
      this.systems?.vfx?.trigger?.('miss', { result });
      this.systems?.vfx?.trigger?.('camera_shake', { intensity: didMiss ? 0.45 : 0.35, duration: 180 });
      this.scene?.setCameraAngle?.('goalkeeper');
    }

    if (this._resetTimer) {
      clearTimeout(this._resetTimer);
      this._resetTimer = null;
    }

    this._resetTimer = setTimeout(() => {
      this._resetTimer = null;
      if (this.state.shotsRemaining <= 0) {
        this.end();
        return;
      }
      this._shotLocked = false;
      this._shotPower = 0;
      this._sprintHeld = false;
      this.scene?.setCameraAngle?.('penalty');
      this.systems?.audio?.playEvent?.('whistle');
    }, 1250);
  }

  _pickGoalkeeperZone(aimX) {
    const roll = Math.random();
    if (aimX < -0.24) {
      return roll < 0.58 ? 'left' : roll < 0.82 ? 'center' : 'right';
    }
    if (aimX > 0.24) {
      return roll < 0.58 ? 'right' : roll < 0.82 ? 'center' : 'left';
    }
    return roll < 0.5 ? 'center' : roll < 0.75 ? 'left' : 'right';
  }

  getState() {
    return {
      modeId: this.getModeId(),
      phase: this.state.phase,
      shotsRemaining: this.state.shotsRemaining,
      goalsScored: this.state.goalsScored,
      goalsConceded: this.state.goalsConceded,
      score: this.state.score,
      prq: this.state.prq,
      lastResult: this.state.lastResult,
      lastShotPower: this.state.lastShotPower,
      lastAimX: this.state.lastAimX,
      winner: this.state.winner,
    };
  }

  getGamepadProps() {
    return this.input?.getGamepadProps() ?? {};
  }

  end() {
    if (this._resetTimer) {
      clearTimeout(this._resetTimer);
      this._resetTimer = null;
    }
    this._shotLocked = true;
    this.state.phase = ModePhase.FINISHED;
    this.state.winner =
      this.state.goalsScored > this.state.goalsConceded
        ? 'player'
        : this.state.goalsScored < this.state.goalsConceded
          ? 'opponent'
          : 'draw';
    this.systems?.audio?.playEvent?.('whistle');
    return this.getState();
  }

  dispose() {
    this._disposed = true;
    if (this._resetTimer) {
      clearTimeout(this._resetTimer);
      this._resetTimer = null;
    }
    this._sensory?.dispose();
    this._sensory = null;
    this.scene?.dispose?.();
    this.scene = null;
    this.systems?.score?.reset?.();
    this.systems?.combo?.reset?.();
    this.systems?.prq?.reset?.();
    this.systems?.hudState?.reset?.();
    this.systems?.analytics?.reset?.();
    this.systems?.skillLab?.reset?.();
    this.systems?.audio?.dispose?.();
    this.systems?.vfx?.dispose?.();
    this.systems = null;
    this.input = null;
    this._shotLocked = false;
    this._shotPower = 0;
    this._aimX = 0;
    this._sprintHeld = false;
    this.state = this._createInitialState();
  }
}

export default SoccerMode;
