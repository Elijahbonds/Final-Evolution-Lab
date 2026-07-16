import { InputSystem } from '../../input/InputSystem.js';
import { GameModeInterface, ModePhase } from '../GameModeInterface.js';
import { SensoryBus } from '../../systems/SensoryBus.js';
import { feelConfig } from '../../systems/feelConfig.js';
import VolleyballScene from './VolleyballScene.js';

const SET_POINT = 25;
const SETS_TO_WIN = 2;
const PLAYER_SIDE = 'player';
const OPPONENT_SIDE = 'opponent';
const PLAYER_BACKCOURT_Z = 5.8;
const PLAYER_NET_Z = 1.2;

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, Number(value) || 0));
}

function randomBetween(min, max) {
  return min + Math.random() * (max - min);
}

function formatResultLabel(result = '') {
  return String(result || '').trim().toUpperCase();
}

export class VolleyballMode extends GameModeInterface {
  constructor(modeIdOrCanvas, maybeCanvas, container) {
    const hasExplicitModeId = typeof modeIdOrCanvas === 'string';
    const modeId = hasExplicitModeId ? modeIdOrCanvas : 'volleyball';
    const canvas = hasExplicitModeId ? maybeCanvas : modeIdOrCanvas;
    super(modeId, canvas);

    this.container = container ?? null;
    this._sensory = null;
    this._disposed = false;
    this.scene = null;
    this.systems = null;
    this.input = null;
    this.playerPosition = { x: 0, y: 0, z: PLAYER_BACKCOURT_Z };
    this._timers = new Set();
    this._rallyCount = 0;
    this._aiDifficulty = 0.55;
    this._server = PLAYER_SIDE;
    this._pendingQTE = null;
    this._currentBallTarget = { x: 0, y: 2.6, z: 2.5 };
    this.state = this._createInitialState();
  }

  _createInitialState() {
    return {
      phase: ModePhase.WARMUP,
      score: 0,
      prq: 50,
      playerPoints: 0,
      opponentPoints: 0,
      sets: [0, 0],
      inRally: false,
      lastResult: '',
      isSpiking: false,
      serveReady: true,
      winner: null,
    };
  }

  async start(container) {
    this.dispose();
    this._disposed = false;
    this.container = container ?? this.container;

    const { createSharedSystems } = await import('../../systems/index.js');
    this.systems = createSharedSystems(this.container);
    this.systems.scoreSystem = this.systems.score;
    this.systems.prqSystem = this.systems.prq;
    this.systems.hudStateSystem = this.systems.hudState;

    this.scene = new VolleyballScene(this.canvas, this.systems);
    await this.scene.init();

    // Disposed while init awaited (StrictMode remount) — bail cleanly.
    if (this._disposed) {
      this.scene.dispose();
      this.scene = null;
      return this.getState();
    }
    this._sensory = new SensoryBus({
      camera: this.scene && !this.scene.isFallback ? this.scene : null,
      sfx: {
        impact: '/audio/sfx_punch_impact.mp3',
        swoosh: '/audio/sfx_basketball_swoosh.mp3',
        crowd:  '/audio/sfx_crowd_cheer.mp3',
      },
    });
    this.scene.setCameraAngle('serve');

    this.input = new InputSystem('volleyball');
    this.input.onEvent = (ev) => this.update(ev);

    this.playerPosition = { x: 0, y: 0, z: PLAYER_BACKCOURT_Z };
    this._server = PLAYER_SIDE;
    this._rallyCount = 0;
    this._pendingQTE = null;
    this._currentBallTarget = { x: 0, y: 2.6, z: 2.5 };
    this.state = { ...this._createInitialState(), phase: ModePhase.ACTIVE };

    this.systems.audio?.playEvent('crowd_swell', { intensity: 0.18 });
    this._syncHudState();
    return this.getState();
  }

  update(inputEvent = {}) {
    if (this.state.phase !== ModePhase.ACTIVE) return this.getState();

    const { type, payload = {} } = inputEvent;

    if (type === 'move') {
      this._applyMovement(payload);
    }

    if (type === 'action') {
      this._handleAction(payload.rally_type, payload);
    }

    return this.getState();
  }

  getState() {
    return {
      modeId: this.getModeId(),
      ...this.state,
    };
  }

  getGamepadProps() {
    return this.input?.getGamepadProps() ?? {};
  }

  end() {
    this._clearTimers();
    this._pendingQTE = null;
    this.state.phase = ModePhase.FINISHED;
    this.state.inRally = false;
    this.state.serveReady = false;
    this.systems?.audio?.playEvent('crowd_swell', { intensity: 0.28, state: 'end' });
    this._syncHudState();
    return this.getState();
  }

  dispose() {
    this._disposed = true;
    this._sensory?.dispose();
    this._sensory = null;
    this._clearTimers();
    this._pendingQTE = null;
    this.scene?.dispose?.();
    this.scene = null;
    this.systems?.scoreSystem?.reset?.();
    this.systems?.prqSystem?.reset?.();
    this.systems?.hudStateSystem?.reset?.();
    this.systems?.analytics?.reset?.();
    this.systems?.skillLab?.reset?.();
    this.systems?.audio?.dispose?.();
    this.systems?.vfx?.dispose?.();
    this.systems = null;
    this.input = null;
    this.playerPosition = { x: 0, y: 0, z: PLAYER_BACKCOURT_Z };
    this._rallyCount = 0;
    this._aiDifficulty = 0.55;
    this._server = PLAYER_SIDE;
    this._currentBallTarget = { x: 0, y: 2.6, z: 2.5 };
    this.state = this._createInitialState();
  }

  _applyMovement(payload = {}) {
    const stick = payload.leftStick ?? {};
    const x = clamp((this.playerPosition.x ?? 0) + (stick.x ?? 0) * 0.55, -3.8, 3.8);
    const zBase = this.playerPosition.z ?? PLAYER_BACKCOURT_Z;
    const z = clamp(zBase - (stick.y ?? 0) * 0.55, 0.8, 7.2);
    this.playerPosition = { x, y: 0, z };

    if (this.scene?.assets?.player) {
      this.scene.assets.player.position.x = x;
      this.scene.assets.player.position.z = z;
    }
  }

  _handleAction(rallyType, payload = {}) {
    if (this.state.winner) return;

    if (!this.state.inRally) {
      if (this._server === PLAYER_SIDE && this.state.serveReady && (rallyType === 'serve' || rallyType === 'ace_serve')) {
        this._startPlayerServe(rallyType === 'ace_serve', payload.power ?? 0.6);
      }
      return;
    }

    if (!this._pendingQTE) return;

    const actionMap = {
      serve: 'serve',
      ace_serve: 'serve',
      dig: 'dig',
      set: 'set',
      spike: 'spike',
      block_jump: 'block',
    };

    const action = actionMap[rallyType] ?? rallyType;
    this._resolvePlayerQTE(action, payload);
  }

  _startPlayerServe(isPowerServe, power = 0.6) {
    this._clearTimers();
    this._pendingQTE = null;
    this._rallyCount = 1;
    this._server = PLAYER_SIDE;
    this.state.inRally = true;
    this.state.serveReady = false;
    this.state.lastResult = isPowerServe ? 'ACE' : 'SERVE';
    this._updateDifficulty();

    const powerFactor = clamp(power, 0.25, 1);
    const apex = isPowerServe ? 5.8 : 5.2;
    this.scene?.setCameraAngle('serve');
    this.scene?.animateBallArc({ x: this.playerPosition.x, y: 2.5, z: this.playerPosition.z - 0.5 }, { x: 0, y: 2.4, z: -5.2 }, apex);
    this.systems.audio?.playEvent('bounce');

    const aceChance = (isPowerServe ? 0.28 + powerFactor * 0.24 : 0.08) - this._aiDifficulty * 0.12;
    if (Math.random() < aceChance) {
      this.systems.audio?.playEvent('spike');
      this.systems.audio?.playEvent('score');
      this.systems.vfx?.trigger('spike', { kind: 'ace_serve' });
      this.scene?.triggerAce?.();
      this._awardPoint(PLAYER_SIDE, 'ACE', { prqType: 'combo', prqQuality: 'perfect' });
      return;
    }

    this._queueTimer(() => {
      this.systems.audio?.playEvent('bounce');
      this._queueOpponentReturn('serve_receive');
    }, 560);

    this._syncHudState();
  }

  _startOpponentServe() {
    this._clearTimers();
    this._pendingQTE = null;
    this._rallyCount = 1;
    this.state.inRally = true;
    this.state.serveReady = false;
    this.state.lastResult = 'RECEIVE';
    this._updateDifficulty();

    this.scene?.setCameraAngle('serve');
    this.scene?.animateBallArc({ x: randomBetween(-2.6, 2.6), y: 2.4, z: -6.2 }, { x: randomBetween(-2.2, 2.2), y: 1.9, z: 4.7 }, 5.2);
    this.systems.audio?.playEvent('bounce');
    this._queuePlayerWindow('dig', 440, 980, 'SAVE');
  }

  _queueOpponentReturn(source) {
    const failChance = clamp(0.3 - this._aiDifficulty * 0.18 - this._rallyCount * 0.015, 0.04, 0.28);
    this._queueTimer(() => {
      if (this.state.phase !== ModePhase.ACTIVE || !this.state.inRally) return;

      if (Math.random() < failChance) {
        this.systems.audio?.playEvent('score');
        this.systems.vfx?.trigger('score_pop', { source });
        this._awardPoint(PLAYER_SIDE, this.state.isSpiking ? 'SPIKE' : 'POINT', {
          prqType: 'hit',
          prqQuality: this.state.isSpiking ? 'excellent' : 'good',
        });
        return;
      }

      this._rallyCount += 1;
      const targetAction = this._rallyCount % 3 === 0 ? 'block' : this._rallyCount % 2 === 0 ? 'set' : 'dig';
      const resultLabel = targetAction === 'block' ? 'BLOCK' : targetAction === 'set' ? 'SET' : 'SAVE';
      const ballEnd = {
        x: randomBetween(-2.6, 2.6),
        y: targetAction === 'block' ? 2.8 : 2.1,
        z: targetAction === 'block' ? 1.2 : 4.8,
      };
      this._currentBallTarget = ballEnd;
      this.scene?.animateBallArc({ x: randomBetween(-2.2, 2.2), y: 2.6, z: -2.6 }, ballEnd, targetAction === 'block' ? 4.8 : 4.4);
      this.systems.audio?.playEvent('bounce');
      this._queuePlayerWindow(targetAction, 420, 960 - this._difficultyWindowPenalty(), resultLabel);
    }, 450 + Math.round(this._difficultyWindowPenalty() * 0.25));
  }

  _queuePlayerWindow(expectedAction, openDelayMs, windowMs, label) {
    this._pendingQTE = null;
    this._queueTimer(() => {
      if (this.state.phase !== ModePhase.ACTIVE || !this.state.inRally) return;
      const now = Date.now();
      this._pendingQTE = {
        expectedAction,
        label,
        openAt: now,
        perfectAt: now + Math.max(140, windowMs * 0.45),
        closeAt: now + Math.max(260, windowMs),
      };
      this.state.lastResult = label;
      this._syncHudState();

      this._queueTimer(() => {
        if (this._pendingQTE?.expectedAction === expectedAction && Date.now() >= this._pendingQTE.closeAt) {
          this._missWindow();
        }
      }, Math.max(280, windowMs) + 12);
    }, openDelayMs);
  }

  _resolvePlayerQTE(action, payload = {}) {
    const qte = this._pendingQTE;
    if (!qte) return;

    const now = Date.now();
    const actionMatches = action === qte.expectedAction || (qte.expectedAction === 'block' && action === 'spike');
    const nearNet = (this.playerPosition.z ?? PLAYER_BACKCOURT_Z) <= 2.1;

    if (qte.expectedAction === 'block' && action === 'block' && !nearNet) {
      this.state.lastResult = 'TOO DEEP';
      this._syncHudState();
      return;
    }

    if (!actionMatches) {
      this.state.lastResult = 'WRONG READ';
      this.systems.audio?.playEvent('bounce');
      this.systems.vfx?.trigger('camera_shake', { intensity: 0.2 });
      this._awardPoint(OPPONENT_SIDE, 'MISREAD', { prqType: 'miss', prqQuality: 'poor' });
      return;
    }

    if (now > qte.closeAt) {
      this.state.lastResult = 'LATE - NET';
      this._awardPoint(OPPONENT_SIDE, 'NET', { prqType: 'miss', prqQuality: 'poor' });
      return;
    }

    const timingDelta = Math.abs(now - qte.perfectAt);
    const perfect = timingDelta <= 90;
    const good = timingDelta <= 180;
    this._pendingQTE = null;

    if (action === 'dig') {
      this.scene?.animateDig?.();
      this.systems.audio?.playEvent('bounce');
      this.state.lastResult = 'SAVE';
      this.state.prq = this.systems.prqSystem?.recordEvent({ type: 'dodge', quality: perfect ? 'perfect' : good ? 'good' : 'ok' }) ?? this.state.prq;
      this.systems.vfx?.trigger('score_pop', { label: 'SAVE' });
      this._queuePlayerWindow('set', 260, 720 - this._difficultyWindowPenalty(), 'SET');
      this._syncHudState();
      return;
    }

    if (action === 'set') {
      this.systems.audio?.playEvent('bounce');
      this.state.lastResult = perfect ? 'SET' : 'FLOAT';
      this.state.prq = this.systems.prqSystem?.recordEvent({ type: 'hit', quality: perfect ? 'excellent' : 'good' }) ?? this.state.prq;
      this.scene?.animateBallArc(this._currentBallTarget, { x: this.playerPosition.x, y: 3.9, z: 1.2 }, 5.2);
      this._queuePlayerWindow('spike', 340, 680 - this._difficultyWindowPenalty(), 'SPIKE');
      this._syncHudState();
      return;
    }

    if (action === 'block') {
      this.scene?.setCameraAngle('block');
      this.systems.audio?.playEvent('bounce');
      this.state.lastResult = 'BLOCK';
      this.systems.vfx?.trigger('camera_shake', { intensity: perfect ? 0.45 : 0.28 });
      if (perfect || Math.random() > this._aiDifficulty * 0.72) {
        this._awardPoint(PLAYER_SIDE, 'BLOCK', { prqType: 'combo', prqQuality: perfect ? 'perfect' : 'great' });
      } else {
        this._queueOpponentReturn('blocked_touch');
        this._syncHudState();
      }
      return;
    }

    if (action === 'spike') {
      this.state.isSpiking = true;
      this.scene?.animateSpike?.();
      this.systems.audio?.playEvent('spike');
      this._sensory?.emit({ sfx: 'impact', volume: 0.8, shake: 0.08 }); // TUNE(elijah)
      this.systems.vfx?.trigger('spike', { perfect });
      this.systems.vfx?.trigger('camera_shake', { intensity: perfect ? 0.7 : 0.35 });

      this._queueTimer(() => {
        this.state.isSpiking = false;
        const killChance = perfect ? 0.74 - this._aiDifficulty * 0.16 : good ? 0.52 - this._aiDifficulty * 0.12 : 0.28;
        if (Math.random() < killChance) {
          this.systems.audio?.playEvent('score');
          this._awardPoint(PLAYER_SIDE, 'SPIKE', { prqType: 'combo', prqQuality: perfect ? 'perfect' : good ? 'excellent' : 'good' });
          return;
        }
        this._queueOpponentReturn('spike_return');
        this._syncHudState();
      }, 280);
      this._syncHudState();
    }
  }

  _missWindow() {
    this._pendingQTE = null;
    this.systems.audio?.playEvent('bounce');
    this._awardPoint(OPPONENT_SIDE, 'LATE - NET', { prqType: 'miss', prqQuality: 'poor' });
  }

  _awardPoint(side, result, { prqType = 'hit', prqQuality = 'good' } = {}) {
    this._clearTimers();
    this._pendingQTE = null;
    this.state.inRally = false;
    this.state.isSpiking = false;
    this.state.lastResult = formatResultLabel(result);
    this.state.prq = this.systems.prqSystem?.recordEvent({ type: prqType, quality: prqQuality }) ?? this.state.prq;
    this.state.score = this.systems.scoreSystem?.addPoints(1, side === PLAYER_SIDE ? 1 : 0) ?? this.state.score;

    if (side === PLAYER_SIDE) {
      this.state.playerPoints += 1;
    } else {
      this.state.opponentPoints += 1;
    }

    this._server = side;
    this.state.serveReady = this._server === PLAYER_SIDE;

    if (this.state.lastResult === 'ACE') {
      this.scene?.triggerAce?.();
    }
    if (['SPIKE', 'BLOCK', 'ACE'].includes(this.state.lastResult)) {
      this.systems.vfx?.trigger('score_pop', { label: this.state.lastResult });
    }

    this.systems.audio?.playEvent('score');
    this.systems.audio?.playEvent('crowd_swell', { intensity: side === PLAYER_SIDE ? 0.52 : 0.3 });

    if (this._checkSetWin()) {
      this._syncHudState();
      return;
    }

    this._syncHudState();
    this._queueNextServe();
  }

  _checkSetWin() {
    const playerReached = this.state.playerPoints >= SET_POINT;
    const opponentReached = this.state.opponentPoints >= SET_POINT;
    const lead = Math.abs(this.state.playerPoints - this.state.opponentPoints);

    if (!(lead >= 2 && (playerReached || opponentReached))) {
      return false;
    }

    const setWinner = this.state.playerPoints > this.state.opponentPoints ? PLAYER_SIDE : OPPONENT_SIDE;
    const sets = [...this.state.sets];
    if (setWinner === PLAYER_SIDE) {
      sets[0] += 1;
    } else {
      sets[1] += 1;
    }
    this.state.sets = sets;
    this.state.playerPoints = 0;
    this.state.opponentPoints = 0;
    this.state.lastResult = 'SET WIN';
    this.systems.audio?.playEvent('crowd_swell', { intensity: 0.9 });
    this.scene?.triggerSetWin?.();

    if (sets[0] >= SETS_TO_WIN || sets[1] >= SETS_TO_WIN) {
      this.state.winner = sets[0] >= SETS_TO_WIN ? 'PLAYER' : 'OPPONENT';
      this.end();
      return true;
    }

    this.state.serveReady = setWinner === PLAYER_SIDE;
    this._server = setWinner;
    this._queueNextServe(950);
    return true;
  }

  _queueNextServe(delay = 720) {
    this._queueTimer(() => {
      if (this.state.phase !== ModePhase.ACTIVE || this.state.winner) return;
      if (this._server === PLAYER_SIDE) {
        this.state.serveReady = true;
        this.state.lastResult = 'SERVE READY';
        this.scene?.setCameraAngle('serve');
        this._syncHudState();
      } else {
        this._startOpponentServe();
      }
    }, delay);
  }

  _difficultyWindowPenalty() {
    return Math.round((this._aiDifficulty + this._rallyCount * 0.05) * 220);
  }

  _updateDifficulty() {
    const setsPressure = this.state.sets[1] * 0.12 + this.state.playerPoints * 0.004;
    const rallyPressure = this._rallyCount * 0.03;
    this._aiDifficulty = clamp(0.56 + setsPressure + rallyPressure, 0.48, 0.92);
  }

  _syncHudState() {
    this.systems?.hudStateSystem?.setState({
      score: {
        total: this.state.score,
        sessionHigh: Math.max(this.state.score, this.state.playerPoints),
        streak: this.state.playerPoints,
      },
      prq: this.systems?.prqSystem?.getProfile?.() ?? { prq: this.state.prq, tier: 'Silver', recentEvents: [] },
      combo: {
        chain: this._rallyCount,
        multiplier: this.state.isSpiking ? 2 : 1,
        windowOpen: Boolean(this._pendingQTE),
        lastBreakReason: this.state.lastResult,
      },
      timer: {
        elapsedMs: this.state.playerPoints + this.state.opponentPoints,
        remainingMs: null,
      },
    });
  }

  _queueTimer(callback, delay) {
    const id = setTimeout(() => {
      this._timers.delete(id);
      callback();
    }, delay);
    this._timers.add(id);
    return id;
  }

  _clearTimers() {
    this._timers.forEach((id) => clearTimeout(id));
    this._timers.clear();
  }
}

export default VolleyballMode;
