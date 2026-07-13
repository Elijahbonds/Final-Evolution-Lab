import { InputSystem } from '../../input/InputSystem.js';
import { GameModeInterface, ModePhase } from '../GameModeInterface.js';
import TennisScene from './TennisScene.js';

let sharedSystemsModulePromise = null;

async function loadSharedSystems() {
  if (sharedSystemsModulePromise) return sharedSystemsModulePromise;
  sharedSystemsModulePromise = import('../../systems/index.js');
  return sharedSystemsModulePromise;
}

const DISPLAY_POINTS = ['0', '15', '30', '40'];
const SWING_WINDOW_MS = 450;
const PERFECT_WINDOW_MS = 200;
const BASE_AI_DELAY_MS = 1180;

function cloneScoreArray(values) {
  return Array.isArray(values) ? values.slice(0, 2) : [0, 0];
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function displayPoints(pointState) {
  const points = cloneScoreArray(pointState);
  const [player, opponent] = points;

  if (player >= 3 && opponent >= 3) {
    if (player === opponent) return ['40', '40'];
    if (player === opponent + 1) return ['AD', '40'];
    if (opponent === player + 1) return ['40', 'AD'];
  }

  return [DISPLAY_POINTS[Math.min(player, 3)] ?? '0', DISPLAY_POINTS[Math.min(opponent, 3)] ?? '0'];
}

function sideFromShot(shotType) {
  switch (shotType) {
    case 'backhand': return 'backhand';
    case 'slice': return 'backhand';
    default: return 'forehand';
  }
}

export class TennisMode extends GameModeInterface {
  constructor(modeIdOrCanvas, maybeCanvas, container) {
    const hasExplicitModeId = typeof modeIdOrCanvas === 'string';
    const modeId = hasExplicitModeId ? modeIdOrCanvas : 'tennis';
    const canvas = hasExplicitModeId ? maybeCanvas : modeIdOrCanvas;

    super(modeId, canvas);

    this.container = container ?? null;
    this.scene = null;
    this.systems = null;
    this.input = null;
    this.state = this._createInitialState();
    this._pointState = [0, 0];
    this._pendingShot = null;
    this._expectedSwingAt = null;
    this._aiTimer = null;
    this._swingTimer = null;
    this._chargeStartedAt = 0;
    this._previousPowerDepth = 0;
    this._lastStrokeAt = 0;
    this._rallyHits = 0;
    this._playerSide = { x: 0, y: 1.1, z: 8.4 };
    this._opponentSide = { x: 0, y: 1.1, z: -8.4 };
  }

  _createInitialState() {
    return {
      phase: ModePhase.WARMUP,
      score: 0,
      prq: 50,
      sets: [0, 0],
      games: [0, 0],
      points: ['0', '0'],
      inRally: false,
      lastResult: '',
      serveReady: true,
      currentPower: 0,
      isPowerCharging: false,
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

    this.scene = new TennisScene(this.canvas, this.systems);
    await this.scene.init();
    this.scene.setCameraAngle('serve');

    this.input = new InputSystem('tennis');
    this.input.onEvent = (event) => this.update(event);

    this.state = {
      ...this._createInitialState(),
      phase: ModePhase.ACTIVE,
      score: this.systems.scoreSystem.getScore().total,
      prq: this.systems.prqSystem.getProfile().prq,
    };

    this._pointState = [0, 0];
    this._pendingShot = null;
    this._expectedSwingAt = null;
    this._rallyHits = 0;
    this.systems.audio.playEvent('whistle');
    this.systems.audio.playEvent('crowd_swell');
    this._syncHudState();

    return this.getState();
  }

  update(inputEvent = {}) {
    if (this.state.phase !== ModePhase.ACTIVE || this.state.winner) return this.getState();

    const { type, payload = {} } = inputEvent;

    if (type === 'move' && payload.leftStick) {
      this._playerSide = {
        x: clamp(this._playerSide.x + payload.leftStick.x * 0.45, -3.7, 3.7),
        y: 1.1,
        z: clamp(this._playerSide.z - payload.leftStick.y * 0.35, 4.8, 9.6),
      };
      if (this.scene?.assets?.player) {
        this.scene.assets.player.position.x = this._playerSide.x;
        this.scene.assets.player.position.z = this._playerSide.z;
      }
    }

    if (type === 'serve') this._handleServe();
    if (type === 'power') this._handlePowerInput(payload.depth ?? 0);
    if (type === 'swing') this._handleSwingInput(payload.shot_type ?? 'forehand');

    this._syncHudState();
    return this.getState();
  }

  _handleServe() {
    if (!this.state.serveReady || this.state.inRally || this.state.winner) return;

    if (this.state.isPowerCharging && this.state.currentPower < 0.12) {
      this._awardPoint(1, 'FAULT');
      return;
    }

    if (this.state.currentPower > 0 && this.state.currentPower < 0.18) {
      this._awardPoint(1, 'FAULT');
      return;
    }

    if (Math.random() < 0.08) {
      this.state.lastResult = 'LET';
      this.systems.audio.playEvent('whistle');
      return;
    }

    this.state.serveReady = false;
    this.state.inRally = true;
    this.state.lastResult = '';
    this._rallyHits = 0;
    this.scene?.setCameraAngle('serve');
    this.scene?.animatePlayerSwing('forehand');
    this.scene?.animateBallStroke(this._playerSide, { x: 0, y: 1.05, z: -7.5 }, false);
    this.systems.audio.playEvent('whistle');
    this._lastStrokeAt = Date.now();
    this._queueAiReturn(false);
  }

  _handlePowerInput(depth) {
    const nextDepth = clamp(depth, 0, 1);
    const wasCharging = this.state.isPowerCharging;

    if (nextDepth > 0.05) {
      if (!wasCharging) this._chargeStartedAt = Date.now();
      this.state.isPowerCharging = true;
      this.state.currentPower = nextDepth;
    } else {
      this.state.isPowerCharging = false;
      if (wasCharging && this.state.inRally && this._pendingShot) {
        this._executePlayerStroke(this._pendingShot, true);
      }
      this.state.currentPower = 0;
      this._chargeStartedAt = 0;
    }

    this._previousPowerDepth = nextDepth;
  }

  _handleSwingInput(shotType) {
    this._pendingShot = shotType;
    if (!this.state.inRally) return;
    if (this.state.isPowerCharging) return;
    this._executePlayerStroke(shotType, false);
  }

  _executePlayerStroke(shotType, releasedCharge) {
    if (!this.state.inRally || !this._expectedSwingAt) {
      this._pendingShot = null;
      return;
    }

    const now = Date.now();
    const timingDelta = Math.abs(now - this._expectedSwingAt);
    const powerBonus = this.state.currentPower;
    this._clearSwingTimer();
    this._pendingShot = null;

    if (timingDelta > SWING_WINDOW_MS) {
      this.state.prq = this.systems.prqSystem.recordEvent({ type: 'miss', quality: 'poor' });
      this.systems.audio.playEvent('whistle');
      this.systems.vfx.trigger('camera_shake', { intensity: 0.24, duration: 180 });
      this._awardPoint(1, 'OUT');
      return;
    }

    const perfect = timingDelta < PERFECT_WINDOW_MS;
    const aceChance = perfect ? 0.28 + powerBonus * 0.45 : 0;
    this.state.prq = this.systems.prqSystem.recordEvent({
      type: perfect ? 'combo' : 'hit',
      quality: perfect ? 'perfect' : releasedCharge ? 'great' : 'good',
    });

    this.scene?.setCameraAngle('rally');
    this.scene?.animatePlayerSwing(sideFromShot(shotType));
    this.scene?.animateBallStroke(this._playerSide, this._resolvePlayerTarget(shotType, powerBonus), shotType === 'lob');
    this._lastStrokeAt = now;
    this._expectedSwingAt = null;
    this._rallyHits += 1;

    if (perfect && Math.random() < aceChance) {
      this.scene?.triggerAce();
      this._awardPoint(0, 'ACE', { scoreBonus: 2 });
      return;
    }

    const winnerChance = Math.min(0.16 + this._rallyHits * 0.09 + powerBonus * 0.18, 0.7);
    if (this._rallyHits >= 2 && Math.random() < winnerChance) {
      this._awardPoint(0, 'WINNER');
      return;
    }

    this._queueAiReturn(true);
  }

  _resolvePlayerTarget(shotType, power) {
    const xBias = shotType === 'backhand' ? -2.2 : shotType === 'slice' ? 2.5 : shotType === 'lob' ? 0.4 : 1.8;
    return {
      x: clamp(xBias + (Math.random() - 0.5) * 1.1 + power * 1.6, -3.6, 3.6),
      y: shotType === 'lob' ? 1.8 : 1.05,
      z: clamp(-8.4 - power * 1.5, -10.2, -7.2),
    };
  }

  _queueAiReturn(afterPlayerStroke) {
    this._clearAiTimer();
    const delay = this._computeAiDelay(afterPlayerStroke);
    this._aiTimer = setTimeout(() => this._performAiReturn(), delay);
  }

  _computeAiDelay(afterPlayerStroke) {
    const acceleration = Math.min(this.state.score, 12) * 35;
    const base = afterPlayerStroke ? BASE_AI_DELAY_MS - 180 : BASE_AI_DELAY_MS;
    return Math.max(360, base - acceleration);
  }

  _performAiReturn() {
    if (!this.state.inRally || this.state.winner) return;

    const aggressive = this.state.score >= 3;
    this._opponentSide = {
      x: clamp((Math.random() - 0.5) * 4.8, -3.8, 3.8),
      y: 1.1,
      z: clamp(-8.4 + Math.random() * 1.2, -9.2, -7.4),
    };
    if (this.scene?.assets?.opponent) {
      this.scene.assets.opponent.position.x = this._opponentSide.x;
      this.scene.assets.opponent.position.z = this._opponentSide.z;
    }

    const target = {
      x: clamp((Math.random() - 0.5) * 4.4, -3.3, 3.3),
      y: aggressive ? 1.15 : 1.02,
      z: clamp(7 + Math.random() * 1.8, 6.2, 9.1),
    };

    this.scene?.animatePlayerSwing('opponent');
    this.scene?.animateBallStroke(this._opponentSide, target, !aggressive && Math.random() < 0.28);
    this._expectedSwingAt = Date.now() + Math.max(320, this._computeAiDelay(true) - 120);

    this._swingTimer = setTimeout(() => {
      if (!this.state.inRally || this.state.winner) return;
      this.state.prq = this.systems.prqSystem.recordEvent({ type: 'miss', quality: 'poor' });
      this.systems.audio.playEvent('whistle');
      this._awardPoint(1, 'WINNER');
    }, SWING_WINDOW_MS + Math.max(320, this._computeAiDelay(true) - 120));
  }

  _awardPoint(side, resultLabel, options = {}) {
    this._clearAiTimer();
    this._clearSwingTimer();
    this.state.inRally = false;
    this.state.serveReady = true;
    this.state.lastResult = resultLabel;
    this.state.isPowerCharging = false;
    this.state.currentPower = 0;
    this._expectedSwingAt = null;
    this._pendingShot = null;
    this._rallyHits = 0;

    if (side === 0) {
      this._pointState[0] += 1;
      this.state.score = this.systems.scoreSystem.addPoints(options.scoreBonus ?? 1, resultLabel === 'ACE' ? 2 : 1);
      this.systems.audio.playEvent('score');
      this.systems.vfx.trigger('score_pop', { label: resultLabel || 'POINT' });
      this.systems.vfx.trigger('camera_shake', { intensity: resultLabel === 'ACE' ? 0.45 : 0.22, duration: 220 });
      if (resultLabel === 'ACE') this.systems.vfx.trigger('ace');
    } else {
      this._pointState[1] += 1;
      this.systems.audio.playEvent('whistle');
    }

    this._pointState = this._resolveGameState();
    this.state.points = displayPoints(this._pointState);
    this.state.prq = this.systems.prqSystem.getProfile().prq;
    this.scene?.setCameraAngle('serve');
    this._syncHudState();
  }

  _resolveGameState() {
    const points = cloneScoreArray(this._pointState);
    const [player, opponent] = points;

    if (player >= 4 || opponent >= 4) {
      const diff = Math.abs(player - opponent);
      if (diff >= 2) {
        const winner = player > opponent ? 0 : 1;
        this.state.games[winner] += 1;
        this.systems.audio.playEvent('crowd_swell');
        this._checkSetWin(winner);
        return [0, 0];
      }
    }

    return points;
  }

  _checkSetWin(winnerIndex) {
    const games = this.state.games;
    const loserIndex = winnerIndex === 0 ? 1 : 0;
    const winnerGames = games[winnerIndex];
    const loserGames = games[loserIndex];

    if (winnerGames >= 6 && winnerGames - loserGames >= 2) {
      this.state.sets[winnerIndex] += 1;
      this.state.games = [0, 0];
      if (this.state.sets[winnerIndex] >= 2) {
        this.state.winner = winnerIndex === 0 ? 'player' : 'opponent';
        this.state.phase = ModePhase.FINISHED;
        this.state.lastResult = winnerIndex === 0 ? 'WINNER' : 'OUT';
        this.systems.audio.playEvent('crowd_swell');
      }
    }
  }

  getState() {
    return {
      modeId: this.getModeId(),
      phase: this.state.phase,
      score: this.state.score,
      prq: this.state.prq,
      sets: [...this.state.sets],
      games: [...this.state.games],
      points: [...this.state.points],
      inRally: this.state.inRally,
      lastResult: this.state.lastResult,
      serveReady: this.state.serveReady,
      currentPower: this.state.currentPower,
      powerCharge: this.state.currentPower,
      isPowerCharging: this.state.isPowerCharging,
      winner: this.state.winner,
    };
  }

  getGamepadProps() {
    return this.input?.getGamepadProps() ?? {};
  }

  end() {
    this._clearAiTimer();
    this._clearSwingTimer();
    this.state.phase = ModePhase.FINISHED;
    this._syncHudState();
    return this.getState();
  }

  dispose() {
    this._clearAiTimer();
    this._clearSwingTimer();
    this.scene?.dispose();
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
    this.state = this._createInitialState();
    this._pointState = [0, 0];
    this._pendingShot = null;
    this._expectedSwingAt = null;
    this._chargeStartedAt = 0;
    this._previousPowerDepth = 0;
    this._rallyHits = 0;
  }

  _syncHudState() {
    this.systems?.hudStateSystem?.setState({
      score: { total: this.state.score },
      prq: this.systems?.prqSystem?.getProfile?.() ?? { prq: this.state.prq, tier: 'Silver', recentEvents: [] },
      combo: {
        chain: this.state.inRally ? Math.max(1, Math.min(8, this.state.score + 1)) : 0,
        multiplier: this.state.lastResult === 'ACE' ? 2 : 1,
        windowOpen: this.state.inRally,
      },
      tennis: {
        sets: [...this.state.sets],
        games: [...this.state.games],
        points: [...this.state.points],
        lastResult: this.state.lastResult,
        serveReady: this.state.serveReady,
        inRally: this.state.inRally,
        winner: this.state.winner,
        powerCharge: this.state.currentPower,
      },
    });
  }

  _clearAiTimer() {
    if (this._aiTimer) {
      clearTimeout(this._aiTimer);
      this._aiTimer = null;
    }
  }

  _clearSwingTimer() {
    if (this._swingTimer) {
      clearTimeout(this._swingTimer);
      this._swingTimer = null;
    }
  }
}

export default TennisMode;
