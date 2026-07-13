import { GameModeInterface, ModePhase } from '../GameModeInterface.js';
import { InputSystem } from '../../input/InputSystem.js';
import { GolfScene } from './GolfScene.js';

let sharedSystemsModulePromise = null;

async function loadSharedSystems() {
  if (!sharedSystemsModulePromise) sharedSystemsModulePromise = import('../../systems/index.js');
  return sharedSystemsModulePromise;
}

const HOLE_DISTANCES = [150, 132, 168, 144, 158, 126, 174, 139, 161];
const HOLE_WORLD_START = { x: 0, y: 0.72, z: 15.3 };
const PIN_WORLD_POSITION = { x: 0, y: 0.82, z: -14 };
const CHARGE_DURATION_MS = 2000;
const AIM_LIMIT_DEGREES = 15;

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function round(value, digits = 1) {
  const factor = 10 ** digits;
  return Math.round((Number(value) || 0) * factor) / factor;
}

function winnerFromScore(score) {
  return score >= 12 ? 'Player' : score >= 0 ? 'Clubhouse Leader' : 'Course';
}

export class GolfMode extends GameModeInterface {
  constructor(modeIdOrCanvas, maybeCanvas, container) {
    const hasExplicitModeId = typeof modeIdOrCanvas === 'string';
    const modeId = hasExplicitModeId ? modeIdOrCanvas : 'golf';
    const canvas = hasExplicitModeId ? maybeCanvas : modeIdOrCanvas;
    super(modeId, canvas);

    this.container = container ?? null;
    this.scene = null;
    this.systems = null;
    this.input = null;
    this.state = this._createInitialState();
    this._timers = new Set();
    this._chargeTicker = null;
    this._chargeStartedAt = 0;
    this._previousChargeDepth = 0;
    this._awaitingNextHole = false;
    this._shotInFlight = false;
    this._aimAngle = 0;
    this._selectedShot = 'full';
    this._selectedShotMultiplier = 1;
    this._perfectTap = false;
    this._holeDistance = HOLE_DISTANCES[0];
    this._ballWorldPosition = { ...HOLE_WORLD_START };
    this._wind = this._rollWind();
  }

  _createInitialState() {
    return {
      phase: ModePhase.WARMUP,
      score: 0,
      prq: 50,
      hole: 1,
      totalHoles: 9,
      par: 3,
      strokes: 0,
      distanceToPin: 150,
      lastShotDistance: 0,
      lastShotAccuracy: 0,
      lastResult: '',
      swingCharging: false,
      swingPower: 0,
      winner: null,
    };
  }

  async start(container) {
    this.dispose();
    this.container = container ?? this.container;

    const { createSharedSystems } = await loadSharedSystems();
    this.systems = createSharedSystems(this.container);
    this.systems.scoreSystem = this.systems.score;
    this.systems.prqSystem = this.systems.prq;
    this.systems.hudStateSystem = this.systems.hudState;

    this.scene = new GolfScene(this.canvas, this.systems);
    await this.scene.init(this.canvas);
    this.scene.setCameraAngle('tee');

    this.input = new InputSystem('golf');
    this.input.onEvent = (event) => this.update(event);

    this._setupHole(1, false);
    this.state.phase = ModePhase.ACTIVE;
    this.state.prq = this.systems?.prq?.getProfile?.().prq ?? 50;
    this.systems?.audio?.playEvent?.('whistle');
    this.systems?.audio?.playEvent?.('crowd_swell');
    this._syncHudState();
    return this.getState();
  }

  update(inputEvent = {}) {
    const { type, payload = {} } = inputEvent;

    if (this.state.phase === ModePhase.FINISHED) {
      if (type === 'swing' && payload.club === 'driver') {
        this.start(this.container);
      }
      return this.getState();
    }

    if (type === 'move' && payload.leftStick) {
      this._applyAimDelta((payload.leftStick.x ?? 0) * 1.4);
    }

    if (type === 'aim') {
      if (payload.rightStick) this._applyAimDelta((payload.rightStick.x ?? 0) * 1.8);
      if (payload.direction === 'left') this._applyAimDelta(-(payload.delta ?? 5) / 5);
      if (payload.direction === 'right') this._applyAimDelta((payload.delta ?? 5) / 5);
    }

    if (type === 'charge') this._handleCharge(payload.depth ?? 0);
    if (type === 'swing') this._handleSwingInput(payload.club ?? 'driver');

    this._syncHudState();
    return this.getState();
  }

  _queueTimer(callback, delay) {
    const timer = setTimeout(() => {
      this._timers.delete(timer);
      callback?.();
    }, delay);
    this._timers.add(timer);
    return timer;
  }

  _clearTimers() {
    this._timers.forEach((timer) => clearTimeout(timer));
    this._timers.clear();
  }

  _clearChargeTicker() {
    if (this._chargeTicker) {
      clearInterval(this._chargeTicker);
      this._chargeTicker = null;
    }
  }

  _setupHole(hole, preserveScore = true) {
    this._awaitingNextHole = false;
    this._shotInFlight = false;
    this._clearChargeTicker();
    this._chargeStartedAt = 0;
    this._previousChargeDepth = 0;
    this._aimAngle = 0;
    this._selectedShot = 'full';
    this._selectedShotMultiplier = 1;
    this._perfectTap = false;
    this._holeDistance = HOLE_DISTANCES[hole - 1] ?? HOLE_DISTANCES[0];
    this._ballWorldPosition = { ...HOLE_WORLD_START };
    this._wind = this._rollWind();

    const nextScore = preserveScore ? this.state.score : 0;
    const nextPrq = preserveScore ? this.state.prq : 50;
    this.state = {
      ...this.state,
      ...(preserveScore ? {} : this._createInitialState()),
      phase: ModePhase.ACTIVE,
      score: nextScore,
      prq: nextPrq,
      hole,
      totalHoles: 9,
      par: 3,
      strokes: 0,
      distanceToPin: this._holeDistance,
      lastShotDistance: 0,
      lastShotAccuracy: 0,
      lastResult: '',
      swingCharging: false,
      swingPower: 0,
      winner: null,
    };

    if (this.scene?.assets?.ball) {
      this.scene.assets.ball.position.x = this._ballWorldPosition.x;
      this.scene.assets.ball.position.y = this._ballWorldPosition.y;
      this.scene.assets.ball.position.z = this._ballWorldPosition.z;
    }
    if (this.scene?.assets?.golfer) {
      this.scene.assets.golfer.rotation.y = 0;
      this.scene.assets.golfer.position.x = -0.8;
      this.scene.assets.golfer.position.z = 16.2;
    }
    this.scene?.showDistanceMarker?.(this._holeDistance);
    this.scene?.setCameraAngle?.('tee');
  }

  _rollWind() {
    const value = round((Math.random() * 0.4) - 0.2, 2);
    return {
      strength: value,
      direction: value >= 0 ? '→' : '←',
      percentage: Math.round(Math.abs(value) * 100),
    };
  }

  _applyAimDelta(delta) {
    this._aimAngle = clamp(this._aimAngle + delta, -AIM_LIMIT_DEGREES, AIM_LIMIT_DEGREES);
    if (this.scene?.assets?.golfer) {
      this.scene.assets.golfer.rotation.y = (this._aimAngle * Math.PI) / 180;
    }
  }

  _handleCharge(depth) {
    const active = depth > 0.05;

    if (active) {
      if (!this.state.swingCharging && !this._shotInFlight && !this._awaitingNextHole) {
        this.state.swingCharging = true;
        this.state.swingPower = 0;
        this._chargeStartedAt = Date.now();
        this._selectedShot = 'full';
        this._selectedShotMultiplier = 1;
        this._perfectTap = false;
        this.scene?.setCameraAngle?.('tee');
        this._chargeTicker = setInterval(() => {
          if (!this.state.swingCharging) return;
          this.state.swingPower = clamp((Date.now() - this._chargeStartedAt) / CHARGE_DURATION_MS, 0, 1);
          this._syncHudState();
        }, 16);
      }
    } else if (this._previousChargeDepth > 0.05 && this.state.swingCharging) {
      this._releaseShot();
    }

    this._previousChargeDepth = depth;
  }

  _handleSwingInput(club) {
    if (this._awaitingNextHole) {
      if (club === 'driver') this._advanceHole();
      return;
    }

    if (this.state.swingCharging) {
      if (club === 'driver') {
        this._selectedShot = 'full';
        this._selectedShotMultiplier = 1;
        if (this.state.swingPower >= 0.95 && this.state.swingPower <= 1) {
          this._perfectTap = true;
          this.systems?.vfx?.trigger?.('score_pop', { label: 'PERFECT' });
        }
      }
      if (club === 'wedge') {
        this._selectedShot = 'chip';
        this._selectedShotMultiplier = 0.4;
      }
      if (club === 'putt') {
        this._selectedShot = 'putt';
        this._selectedShotMultiplier = 0.2;
      }
      return;
    }

    if (this._shotInFlight) return;

    if (club === 'wedge') {
      this._selectedShot = 'chip';
      this._selectedShotMultiplier = 0.4;
      this._executeShot(1);
    }
    if (club === 'putt') {
      this._selectedShot = 'putt';
      this._selectedShotMultiplier = 0.2;
      this._executeShot(1);
    }
  }

  _releaseShot() {
    this._clearChargeTicker();
    this.state.swingCharging = false;
    this._executeShot(this.state.swingPower || 0.25);
  }

  _executeShot(basePower = 1) {
    if (this._shotInFlight || this._awaitingNextHole || this.state.phase !== ModePhase.ACTIVE) return;

    const shotPower = clamp(basePower * this._selectedShotMultiplier + (this._perfectTap ? 0.12 : 0), 0.05, 1.2);
    const accuracyBase = this._perfectTap
      ? clamp(0.94 + Math.random() * 0.06, 0, 1)
      : 0.5 + Math.random() * 0.5;
    const accuracy = clamp(accuracyBase - (Math.abs(this._aimAngle) / AIM_LIMIT_DEGREES) * 0.08, 0.35, 1);
    const windFactor = 1 + this._wind.strength;
    const shotDistance = round(this.state.distanceToPin * shotPower * windFactor, 1);
    const nextDistance = round(Math.abs(this.state.distanceToPin - shotDistance) * (1 - accuracy), 1);
    const aimedEnd = this._worldEndForShot(shotDistance, accuracy);

    this._shotInFlight = true;
    this.state.strokes += 1;
    this.state.lastShotDistance = shotDistance;
    this.state.lastShotAccuracy = round(accuracy, 2);
    this.state.lastResult = this._selectedShot === 'putt' ? 'Putt away' : this._selectedShot === 'chip' ? 'Checking spin' : 'Tracking flight';
    this.systems?.audio?.playEvent?.('bounce');
    this.systems?.prq?.recordEvent?.({
      type: this._perfectTap ? 'combo' : 'hit',
      quality: this._perfectTap ? 'perfect' : accuracy >= 0.75 ? 'good' : 'poor',
    });
    this.state.prq = this.systems?.prq?.getProfile?.().prq ?? this.state.prq;

    this.scene?.animateGolferSwing?.(shotPower);
    this.scene?.setCameraAngle?.('flight');
    Promise.resolve(
      this.scene?.animateBallFlight?.(this._ballWorldPosition, aimedEnd, 7 + shotPower * 7, 920 + shotPower * 620)
    )
      .then(() => {
        this._ballWorldPosition = { ...aimedEnd };
        this.state.distanceToPin = nextDistance;
        this.state.lastResult = `${shotDistance} yds • ${Math.round(accuracy * 100)}% accuracy`;
        this.scene?.showDistanceMarker?.(nextDistance);
        this.systems?.vfx?.trigger?.('camera_shake', { intensity: 0.18 + shotPower * 0.2, duration: 180 });
        this._shotInFlight = false;

        if (nextDistance < 5) {
          this._finishHole();
          return;
        }

        this._perfectTap = false;
        this._selectedShot = 'full';
        this._selectedShotMultiplier = 1;
        this.state.swingPower = 0;
        this._wind = this._rollWind();
        this._syncHudState();
      });
  }

  _worldEndForShot(shotDistance, accuracy) {
    const toPinX = PIN_WORLD_POSITION.x - this._ballWorldPosition.x;
    const toPinZ = PIN_WORLD_POSITION.z - this._ballWorldPosition.z;
    const straightDistance = Math.sqrt((toPinX * toPinX) + (toPinZ * toPinZ)) || 1;
    const scale = clamp(shotDistance / Math.max(this.state.distanceToPin, 1), 0, 1.28);
    const angleRad = (this._aimAngle * Math.PI) / 180;
    const sideOffset = Math.sin(angleRad) * (1.8 + (1 - accuracy) * 6.5) * scale;
    const overshoot = Math.max(0, scale - 1);
    const x = this._ballWorldPosition.x + (toPinX / straightDistance) * straightDistance * scale + sideOffset;
    const z = this._ballWorldPosition.z + (toPinZ / straightDistance) * straightDistance * scale - overshoot * 4.5;
    return {
      x: clamp(x, -10.5, 10.5),
      y: 0.72,
      z: clamp(z, -18.8, 16),
    };
  }

  _finishHole() {
    const scoreDelta = this._scoreDeltaForHole(this.state.strokes);
    const holedInOne = this.state.strokes === 1;
    const resultLabel = holedInOne
      ? 'HOLE IN ONE'
      : this.state.strokes === 2
      ? 'BIRDIE'
      : this.state.strokes === 3
      ? 'PAR'
      : 'BOGEY';

    this.state.score += scoreDelta;
    this.state.distanceToPin = 0;
    this.state.swingPower = 0;
    this.state.lastResult = resultLabel;
    this.systems?.audio?.playEvent?.('score');
    this.systems?.audio?.playEvent?.('crowd_swell');
    this.systems?.vfx?.trigger?.('score_pop', { label: resultLabel });
    this.systems?.prq?.recordEvent?.({ type: 'score', quality: holedInOne ? 'perfect' : scoreDelta >= 0 ? 'good' : 'poor' });
    this.state.prq = this.systems?.prq?.getProfile?.().prq ?? this.state.prq;

    if (holedInOne) {
      this.systems?.vfx?.trigger?.('hole_in_one');
      this.scene?.triggerHoleInOne?.();
    }

    this._awaitingNextHole = true;
    if (this.state.hole >= this.state.totalHoles) {
      this.end(winnerFromScore(this.state.score));
      return;
    }

    this._queueTimer(() => this._advanceHole(), 1800);
    this._syncHudState();
  }

  _scoreDeltaForHole(strokes) {
    if (strokes <= 1) return 5;
    if (strokes === 2) return 2;
    if (strokes === 3) return 0;
    return -(strokes - 3);
  }

  _advanceHole() {
    if (!this._awaitingNextHole || this.state.phase === ModePhase.FINISHED) return;
    this._setupHole(this.state.hole + 1);
    this._syncHudState();
  }

  _syncHudState() {
    this.systems?.hudStateSystem?.setState?.({
      score: { total: this.state.score },
      prq: this.systems?.prq?.getProfile?.() ?? { prq: this.state.prq, tier: 'Silver' },
      combo: {
        chain: this.state.hole,
        multiplier: this._perfectTap ? 2 : 1,
        windowOpen: this.state.swingCharging,
        lastBreakReason: this.state.lastResult,
      },
      timer: {
        elapsedMs: this.state.strokes * 1000,
        remainingMs: this._awaitingNextHole ? 1800 : null,
      },
    });
  }

  getState() {
    return {
      modeId: this.getModeId(),
      ...this.state,
      aimAngle: round(this._aimAngle, 1),
      windDirection: this._wind.direction,
      windStrength: this._wind.percentage,
    };
  }

  getGamepadProps() {
    return this.input?.getGamepadProps() ?? {};
  }

  end(winner = this.state.winner) {
    this._clearChargeTicker();
    this._clearTimers();
    this.state.phase = ModePhase.FINISHED;
    this._awaitingNextHole = false;
    this.state.swingCharging = false;
    this.state.winner = winner ?? winnerFromScore(this.state.score);
    this.systems?.audio?.playEvent?.('score');
    this.systems?.audio?.playEvent?.('crowd_swell');
    this._syncHudState();
    return this.getState();
  }

  dispose() {
    this._clearChargeTicker();
    this._clearTimers();
    this.scene?.dispose?.();
    this.scene = null;
    if (this.input) this.input.onEvent = () => {};
    this.input = null;
    this.systems?.score?.reset?.();
    this.systems?.prq?.reset?.();
    this.systems?.hudState?.reset?.();
    this.systems?.analytics?.reset?.();
    this.systems?.audio?.dispose?.();
    this.systems?.vfx?.dispose?.();
    this.systems = null;
    this._awaitingNextHole = false;
    this._shotInFlight = false;
    this._aimAngle = 0;
    this._selectedShot = 'full';
    this._selectedShotMultiplier = 1;
    this._perfectTap = false;
    this._ballWorldPosition = { ...HOLE_WORLD_START };
    this._wind = this._rollWind();
    this.state = this._createInitialState();
  }
}

export default GolfMode;
