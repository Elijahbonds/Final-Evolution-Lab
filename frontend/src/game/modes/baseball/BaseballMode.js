import { GameModeInterface, ModePhase } from '../GameModeInterface.js';
import { SensoryBus } from '../../systems/SensoryBus.js';
import { feelConfig } from '../../systems/feelConfig.js';
import { InputSystem } from '../../input/InputSystem.js';
import { BaseballScene } from './BaseballScene.js';

const PITCH_DELAY_MS = 1000;
const SWING_WINDOW_MS = 800;
const PERFECT_WINDOW_MS = 120;
const GOOD_WINDOW_MS = 350;
const POWER_WINDOW_BONUS_MS = 50;

let sharedSystemsModulePromise = null;

async function loadSharedSystems() {
  if (!sharedSystemsModulePromise) {
    sharedSystemsModulePromise = import('../../systems/index.js');
  }
  return sharedSystemsModulePromise;
}

function randomPitchType() {
  const pitches = ['fastball', 'curveball', 'changeup'];
  return pitches[Math.floor(Math.random() * pitches.length)] || 'fastball';
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

export class BaseballMode extends GameModeInterface {
  constructor(modeIdOrCanvas, maybeCanvas, container) {
    const hasExplicitModeId = typeof modeIdOrCanvas === 'string';
    const modeId = hasExplicitModeId ? modeIdOrCanvas : 'baseball';
    const canvas = hasExplicitModeId ? maybeCanvas : modeIdOrCanvas;

    super(modeId, canvas);

    this.container = container ?? null;
    this._sensory = null;
    this._disposed = false;
    this.scene = null;
    this.systems = null;
    this.input = null;
    this.state = this._createInitialState();
    this._timers = new Set();
    this._pitchResolveTimer = null;
    this._currentPitch = null;
    this._powerDepth = 0;
    this._plateAtBatCounted = false;
  }

  _createInitialState() {
    return {
      phase: ModePhase.WARMUP,
      score: 0,
      prq: 50,
      atBats: 0,
      hits: 0,
      homeRuns: 0,
      strikes: 0,
      balls: 0,
      outs: 0,
      inning: 1,
      lastResult: '',
      pitchInFlight: false,
      pitchStartTime: 0,
      winner: null,
    };
  }

  async start(container) {
    this.dispose();
    this._disposed = false;

    this.container = container ?? this.container;
    const { createSharedSystems } = await loadSharedSystems();
    this.systems = createSharedSystems(this.container);
    this.systems.scoreSystem = this.systems.score;
    this.systems.prqSystem = this.systems.prq;
    this.systems.hudStateSystem = this.systems.hudState;

    this.scene = new BaseballScene(this.canvas, this.systems);
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
    this.scene.setCameraAngle('batter');

    this.input = new InputSystem('baseball');
    this.input.onEvent = (event) => this.update(event);

    this.state = {
      ...this._createInitialState(),
      phase: ModePhase.ACTIVE,
      score: this.systems.scoreSystem.getScore().total,
      prq: this.systems.prqSystem.getProfile().prq,
    };

    this._currentPitch = null;
    this._powerDepth = 0;
    this._plateAtBatCounted = false;
    this.systems.audio.playEvent('whistle');
    this.systems.audio.playEvent('crowd_swell');
    this._queueNextPitch(PITCH_DELAY_MS);
    this._syncHudState();
    return this.getState();
  }

  update(inputEvent = {}) {
    if (this.state.phase !== ModePhase.ACTIVE || this.state.winner) {
      return this.getState();
    }

    const { type, payload = {} } = inputEvent;

    if (type === 'aim') {
      const direction = payload.direction || (payload.rightStick?.y < -0.4 ? 'up' : payload.rightStick?.y > 0.4 ? 'down' : 'neutral');
      if (direction === 'up') this.scene?.setCameraAngle('pitcher');
      if (direction === 'down') this.scene?.setCameraAngle('batter');
      if (direction === 'right') this.scene?.setCameraAngle('home_run');
    }

    if (type === 'pitch') {
      this._powerDepth = payload.pitch_type === 'fastball' ? clamp(payload.power ?? 0, 0, 1) : 0;
    }

    if (type === 'swing') {
      this._handleSwing(payload.play_type ?? 'full_swing');
    }

    this._syncHudState();
    return this.getState();
  }

  _handleSwing(playType) {
    if (playType === 'check_swing') {
      this.state.lastResult = 'CHECK';
      this.systems.audio.playEvent('whistle');
      return;
    }

    if (!this.state.pitchInFlight) return;

    const elapsed = Math.max(0, Date.now() - this.state.pitchStartTime);
    const timingBonus = this._powerDepth > 0.25 ? POWER_WINDOW_BONUS_MS : 0;
    const perfectWindow = PERFECT_WINDOW_MS + timingBonus;
    const goodWindow = GOOD_WINDOW_MS + timingBonus;
    const isBunt = playType === 'bunt';

    this._clearPitchResolveTimer();
    this.state.pitchInFlight = false;
    this.state.pitchStartTime = 0;
    this.scene?.animateSwing(elapsed <= goodWindow);
    this.systems.audio.playEvent('swing_bat');

    if (elapsed < perfectWindow && !isBunt) {
      this._markAtBat();
      this.state.hits += 1;
      this.state.homeRuns += 1;
      this._sensory?.emit({ sfx: 'crowd', volume: feelConfig.sensory.crowdVolume, shake: 0.22, rumbleMs: feelConfig.sensory.rumbleMs }); // TUNE(elijah)
      this.state.lastResult = 'HOMERUN';
      this.state.score = this.systems.scoreSystem.addPoints(3);
      this.state.prq = this.systems.prqSystem.recordEvent({ type: 'combo', quality: 'perfect' });
      this.systems.audio.playEvent('score');
      this.systems.audio.playEvent('crowd_swell');
      this.systems.vfx.trigger('score_pop', { label: 'HOMERUN' });
      this.systems.vfx.trigger('camera_shake', { intensity: 0.55, duration: 280 });
      this.scene?.triggerHomeRun();
      this._resetPlate();
      return;
    }

    if (elapsed < goodWindow) {
      this._markAtBat();
      this.state.hits += 1;
      this.state.lastResult = 'HIT';
      this._sensory?.emit({ sfx: 'impact', volume: 0.7, shake: 0.07 }); // TUNE(elijah)
      this.state.score = this.systems.scoreSystem.addPoints(1);
      this.state.prq = this.systems.prqSystem.recordEvent({ type: 'hit', quality: isBunt ? 'ok' : 'good' });
      this.systems.audio.playEvent('hit_ball');
      this.systems.audio.playEvent('score');
      this.systems.audio.playEvent('crowd_swell');
      this.systems.vfx.trigger('score_pop', { label: isBunt ? 'BUNT HIT' : 'HIT' });
      this.systems.vfx.trigger('camera_shake', { intensity: 0.22, duration: 180 });
      this._resetPlate();
      return;
    }

    this.systems.audio.playEvent('bounce');
    this.systems.vfx.trigger('camera_shake', { intensity: 0.16, duration: 140 });
    this.state.prq = this.systems.prqSystem.recordEvent({ type: 'miss', quality: 'poor' });
    this._registerStrike('FOUL');
  }

  _queueNextPitch(delay = PITCH_DELAY_MS) {
    if (this.state.phase !== ModePhase.ACTIVE || this.state.winner) return;
    this._schedule(() => this._startPitch(), delay);
  }

  _startPitch() {
    if (this.state.phase !== ModePhase.ACTIVE || this.state.winner) return;

    const type = randomPitchType();
    const speed = 0.9 + Math.random() * 0.45;
    this._currentPitch = {
      type,
      speed,
      isBall: Math.random() < 0.28,
    };

    this.state.lastResult = '';
    this.state.pitchInFlight = true;
    this.state.pitchStartTime = Date.now();
    this.scene?.setCameraAngle('batter');
    this.scene?.animatePitch(speed, type);

    this._pitchResolveTimer = this._schedule(() => {
      this._pitchResolveTimer = null;
      this._resolvePitchWindow();
    }, SWING_WINDOW_MS);
  }

  _resolvePitchWindow() {
    if (!this.state.pitchInFlight) return;

    this.state.pitchInFlight = false;
    this.state.pitchStartTime = 0;

    if (this._currentPitch?.isBall) {
      this.state.lastResult = 'BALL';
      this.state.balls += 1;
      this.systems.audio.playEvent('whistle');
      if (this.state.balls >= 4) {
        this.state.score = this.systems.scoreSystem.addPoints(1);
        this.systems.audio.playEvent('score');
        this.systems.audio.playEvent('crowd_swell');
        this.systems.vfx.trigger('score_pop', { label: 'WALK' });
        this._resetPlate();
        return;
      }
      this._queueNextPitch(700);
      return;
    }

    this.state.prq = this.systems.prqSystem.recordEvent({ type: 'miss', quality: 'poor' });
    this.systems.audio.playEvent('whistle');
    this._registerStrike('STRIKE');
  }

  _registerStrike(label) {
    this.state.lastResult = label;
    this.state.strikes += 1;

    if (this.state.strikes >= 3) {
      this._markAtBat();
      this._recordOut();
      return;
    }

    this._queueNextPitch(750);
  }

  _recordOut() {
    this.state.outs += 1;
    this.state.lastResult = 'STRIKE';
    this.systems.audio.playEvent('whistle');
    this.systems.vfx.trigger('camera_shake', { intensity: 0.28, duration: 180 });

    if (this.state.outs >= 3) {
      this.state.outs = 0;
      this.state.strikes = 0;
      this.state.balls = 0;
      this.state.inning += 1;
      this._plateAtBatCounted = false;
      if (this.state.inning > 3) {
        this._finishGame();
        return;
      }
      this.state.lastResult = 'OUT';
      this._queueNextPitch(1200);
      return;
    }

    this._resetPlate();
  }

  _resetPlate() {
    this.state.strikes = 0;
    this.state.balls = 0;
    this.state.pitchInFlight = false;
    this.state.pitchStartTime = 0;
    this._currentPitch = null;
    this._powerDepth = 0;
    this._plateAtBatCounted = false;
    this._queueNextPitch(PITCH_DELAY_MS);
  }

  _markAtBat() {
    if (this._plateAtBatCounted) return;
    this.state.atBats += 1;
    this._plateAtBatCounted = true;
  }

  _finishGame() {
    this._clearAllTimers();
    this.state.phase = ModePhase.FINISHED;
    this.state.pitchInFlight = false;
    this.state.pitchStartTime = 0;
    this.state.winner = this.state.score > 0
      ? `PLAYER WINS · ${this.state.score} RUNS`
      : 'GAME OVER · 0 RUNS';
    this.systems?.audio?.playEvent('crowd_swell');
    this.systems?.audio?.playEvent('score');
  }

  _schedule(fn, delay) {
    const timer = setTimeout(() => {
      this._timers.delete(timer);
      fn();
    }, delay);
    this._timers.add(timer);
    return timer;
  }

  _clearPitchResolveTimer() {
    if (!this._pitchResolveTimer) return;
    clearTimeout(this._pitchResolveTimer);
    this._timers.delete(this._pitchResolveTimer);
    this._pitchResolveTimer = null;
  }

  _clearAllTimers() {
    this._clearPitchResolveTimer();
    this._timers.forEach((timer) => clearTimeout(timer));
    this._timers.clear();
  }

  getState() {
    return {
      modeId: this.getModeId(),
      phase: this.state.phase,
      score: this.state.score,
      prq: this.state.prq,
      atBats: this.state.atBats,
      hits: this.state.hits,
      homeRuns: this.state.homeRuns,
      strikes: this.state.strikes,
      balls: this.state.balls,
      outs: this.state.outs,
      inning: this.state.inning,
      lastResult: this.state.lastResult,
      pitchInFlight: this.state.pitchInFlight,
      pitchStartTime: this.state.pitchStartTime,
      winner: this.state.winner,
      powerDepth: this._powerDepth,
    };
  }

  getGamepadProps() {
    return this.input?.getGamepadProps() ?? {};
  }

  end() {
    this._finishGame();
    this._syncHudState();
    return this.getState();
  }

  dispose() {
    this._disposed = true;
    this._sensory?.dispose();
    this._sensory = null;
    this._clearAllTimers();
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
    this._currentPitch = null;
    this._powerDepth = 0;
    this._plateAtBatCounted = false;
    this.state = this._createInitialState();
  }

  _syncHudState() {
    this.systems?.hudStateSystem?.setState({
      score: { total: this.state.score },
      prq: this.systems?.prqSystem?.getProfile?.() ?? { prq: this.state.prq, tier: 'Silver', recentEvents: [] },
      baseball: {
        atBats: this.state.atBats,
        hits: this.state.hits,
        homeRuns: this.state.homeRuns,
        strikes: this.state.strikes,
        balls: this.state.balls,
        outs: this.state.outs,
        inning: this.state.inning,
        lastResult: this.state.lastResult,
        pitchInFlight: this.state.pitchInFlight,
        winner: this.state.winner,
      },
    });
  }
}

export default BaseballMode;
