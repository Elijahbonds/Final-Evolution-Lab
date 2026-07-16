import { InputSystem } from '../../input/InputSystem.js';
import { GameModeInterface, ModePhase } from '../GameModeInterface.js';
import { SensoryBus } from '../../systems/SensoryBus.js';
import { feelConfig } from '../../systems/feelConfig.js';
import FootballScene from './FootballScene.js';

const DRIVE_START_YARD = 20;
const GOAL_LINE = 100;
const FIRST_DOWN_DISTANCE = 10;
const TACKLE_INTERVAL_MS = 140;
const BURST_DRAIN_PER_TICK = 0.045;
const BURST_RECHARGE_PER_TICK = 0.028;
const BURST_MIN_SPEED = 1;
const BURST_MAX_SPEED = 1.85;

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, Number(value) || 0));
}

function ordinalDown(down) {
  return ['1st', '2nd', '3rd', '4th'][Math.max(0, Math.min(3, (down || 1) - 1))] || `${down}th`;
}

export class FootballMode extends GameModeInterface {
  constructor(modeIdOrCanvas, maybeCanvas, container) {
    const hasExplicitModeId = typeof modeIdOrCanvas === 'string';
    const modeId = hasExplicitModeId ? modeIdOrCanvas : 'football';
    const canvas = hasExplicitModeId ? maybeCanvas : modeIdOrCanvas;
    super(modeId, canvas);

    this.container = container ?? null;
    this._sensory = null;
    this._disposed = false;
    this.scene = null;
    this.systems = null;
    this.input = null;
    this.loopTimer = null;
    this._patTimer = null;
    this._burstMeter = 1;
    this._burstDepth = 0;
    this._fieldPosition = DRIVE_START_YARD;
    this._firstDownMarker = DRIVE_START_YARD + FIRST_DOWN_DISTANCE;
    this._runnerLane = 0;
    this._awaitingPAT = false;
    this._lastBurstTick = Date.now();
    this._defenders = [];
    this.state = this._createInitialState();
  }

  _createInitialState() {
    return {
      phase: ModePhase.WARMUP,
      score: 0,
      prq: 50,
      yardsGained: 0,
      down: 1,
      toGo: 10,
      touchdowns: 0,
      lastMove: '',
      speed: 1,
      isBursting: false,
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

    this.scene = new FootballScene(this.canvas, this.systems);
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
    this.scene.setCameraAngle('line_of_scrimmage');

    this.input = new InputSystem('football');
    this.input.onEvent = (event) => this.update(event);

    this._resetDriveState();
    this.state = { ...this._createInitialState(), phase: ModePhase.ACTIVE };
    this._syncHudState();

    this.systems.audio?.playEvent('match_start');
    this.systems.audio?.playEvent('crowd_loop_start', { intensity: 0.12 });
    this.systems.audio?.playEvent('whistle');

    this.loopTimer = setInterval(() => this._tick(), TACKLE_INTERVAL_MS);
    return this.getState();
  }

  update(inputEvent = {}) {
    if (this.state.phase !== ModePhase.ACTIVE) return this.getState();
    const { type, payload = {} } = inputEvent;

    if (type === 'move' && payload.play_type) {
      this._handleSpecialMove(payload.play_type);
      return this.getState();
    }

    if (type === 'move' && payload.leftStick) {
      this._handleRun(payload.leftStick, payload.direction, payload.magnitude ?? 1);
      return this.getState();
    }

    if (type === 'move' && payload.direction) {
      this._handleDigitalMove(payload.direction);
      return this.getState();
    }

    if (type === 'l2' || type === 'r2') {
      this._burstDepth = clamp(payload.value, 0, 1);
      this.state.isBursting = this._burstDepth > 0.15 && this._burstMeter > 0.05;
      this.state.speed = this.state.isBursting
        ? clamp(BURST_MIN_SPEED + this._burstDepth * 0.85, BURST_MIN_SPEED, BURST_MAX_SPEED)
        : BURST_MIN_SPEED;
      this._syncHudState();
      return this.getState();
    }

    return this.getState();
  }

  _handleRun(stick, direction = 'up', magnitude = 1) {
    const laneShift = clamp(stick.x, -1, 1) * 1.25;
    const pace = clamp(magnitude, 0.35, 1) * this.state.speed;

    this._runnerLane = clamp(this._runnerLane + laneShift, -9.5, 9.5);
    this._advanceField(Math.max(0.45, pace * 1.55));
    this.state.lastMove = direction === 'neutral' ? 'CUTBACK' : `RUN ${String(direction).replace('-', ' ').toUpperCase()}`;

    this.scene?.setCameraAngle('ball_carry');
    this.scene?.animatePlayerRun(direction);
    this.systems.audio?.playEvent('bounce');
    this._syncHudState();
  }

  _handleDigitalMove(direction) {
    const vector = {
      up: { x: 0, y: -1 },
      down: { x: 0, y: 0.35 },
      left: { x: -0.8, y: -0.7 },
      right: { x: 0.8, y: -0.7 },
    }[direction] || { x: 0, y: -1 };
    this._handleRun(vector, direction, 0.78);
  }

  _handleSpecialMove(playType) {
    if (this._awaitingPAT && playType === 'hurdle') {
      this._completePAT();
      return;
    }

    const moveName = String(playType || '').replace('_', ' ').toUpperCase();
    this.state.lastMove = moveName;
    this.systems.audio?.playEvent('bounce');

    switch (playType) {
      case 'dive':
        this._advanceField(2.3);
        this.state.prq = this.systems.prqSystem?.recordEvent({ type: 'dodge', quality: 'clean' }) ?? this.state.prq;
        break;
      case 'spin':
        this._runnerLane = clamp(this._runnerLane + (Math.random() > 0.5 ? 2.4 : -2.4), -10, 10);
        this._advanceField(1.8);
        this.state.prq = this.systems.prqSystem?.recordEvent({ type: 'dodge', quality: 'great' }) ?? this.state.prq;
        break;
      case 'stiff_arm':
        this._pushNearestDefenderBack();
        this._advanceField(1.4);
        this.state.prq = this.systems.prqSystem?.recordEvent({ type: 'dodge', quality: 'excellent' }) ?? this.state.prq;
        break;
      case 'hurdle':
        this._advanceField(2);
        this.state.prq = this.systems.prqSystem?.recordEvent({ type: 'dodge', quality: 'good' }) ?? this.state.prq;
        break;
      default:
        break;
    }

    this._syncHudState();
  }

  _tick() {
    if (this.state.phase !== ModePhase.ACTIVE) return;

    const now = Date.now();
    const elapsedFactor = Math.max(1, (now - this._lastBurstTick) / TACKLE_INTERVAL_MS);
    this._lastBurstTick = now;

    if (this.state.isBursting && this._burstMeter > 0) {
      this._burstMeter = clamp(this._burstMeter - BURST_DRAIN_PER_TICK * elapsedFactor, 0, 1);
      if (this._burstMeter <= 0.02) {
        this.state.isBursting = false;
        this.state.speed = BURST_MIN_SPEED;
      }
    } else {
      this._burstMeter = clamp(this._burstMeter + BURST_RECHARGE_PER_TICK * elapsedFactor, 0, 1);
    }

    this._defenders.forEach((defender, idx) => {
      defender.depth -= 0.45 + this.state.speed * 0.18 + idx * 0.02;
      defender.lane += (this._runnerLane - defender.lane) * 0.16;

      const lateralGap = Math.abs(defender.lane - this._runnerLane);
      if (defender.depth <= 1.15 && lateralGap < 2.2 && !this._awaitingPAT) {
        this._registerTackle(idx);
      }
    });

    this.state.prq = this.systems.prqSystem?.computePRQ?.() ?? this.state.prq;
    this._syncHudState();
  }

  _advanceField(yards) {
    if (this._awaitingPAT) return;
    this._fieldPosition = clamp(this._fieldPosition + yards, DRIVE_START_YARD, GOAL_LINE);
    this.state.yardsGained = Math.max(0, Math.round((this._fieldPosition - DRIVE_START_YARD) * 10) / 10);

    if (this._fieldPosition >= GOAL_LINE) {
      this._scoreTouchdown();
      return;
    }

    if (this._fieldPosition >= this._firstDownMarker) {
      this.state.down = 1;
      this._firstDownMarker = Math.min(this._fieldPosition + FIRST_DOWN_DISTANCE, GOAL_LINE);
      this.state.toGo = Math.max(0, Math.ceil(this._firstDownMarker - this._fieldPosition));
      this.state.lastMove = 'FIRST DOWN';
      this.systems.audio?.playEvent('crowd_swell');
      this.systems.vfx?.trigger('score_pop', { text: 'FIRST DOWN' });
      this.scene?.setCameraAngle('line_of_scrimmage');
      this._resetDefenders(false);
      return;
    }

    this.state.toGo = Math.max(0, Math.ceil(this._firstDownMarker - this._fieldPosition));
  }

  _registerTackle(defenderIndex) {
    if (this._awaitingPAT || this.state.phase !== ModePhase.ACTIVE) return;
    this.scene?.animateDefenderTackle(defenderIndex);
    this.scene?.setCameraAngle('line_of_scrimmage');
    this.systems.audio?.playEvent('whistle');
    this.systems.vfx?.trigger('camera_shake', { intensity: 0.5, duration: 220 });
    this.state.lastMove = 'TACKLED';
    this.state.prq = this.systems.prqSystem?.recordEvent({ type: 'miss', quality: 'poor' }) ?? this.state.prq;

    if (this.state.toGo > 0) {
      this.state.down += 1;
    }

    if (this.state.down > 4) {
      this.state.winner = 'defense';
      this.end('defense');
      return;
    }

    this._resetDefenders(true);
    this._syncHudState();
  }

  _scoreTouchdown() {
    this._awaitingPAT = true;
    this.state.touchdowns += 1;
    this._sensory?.emit({ sfx: 'crowd', volume: feelConfig.sensory.crowdVolume, shake: 0.2, rumbleMs: feelConfig.sensory.rumbleMs }); // TUNE(elijah)
    this.state.score = this.systems.scoreSystem?.addPoints(6, 1) ?? (this.state.score + 6);
    this.state.lastMove = 'TOUCHDOWN!';
    this.state.winner = 'player';
    this.state.prq = this.systems.prqSystem?.recordEvent({ type: 'combo', quality: 'perfect' }) ?? this.state.prq;
    this.systems.audio?.playEvent('score');
    this.systems.audio?.playEvent('crowd_swell');
    this.systems.vfx?.trigger('touchdown');
    this.systems.vfx?.trigger('camera_shake', { intensity: 0.75, duration: 350 });
    this.systems.vfx?.trigger('score_pop', { text: 'TOUCHDOWN' });
    this.scene?.triggerTouchdown();

    if (this._patTimer) clearTimeout(this._patTimer);
    this._patTimer = setTimeout(() => {
      if (this._awaitingPAT && this.state.phase === ModePhase.ACTIVE) this.end('player');
    }, 3200);

    this._syncHudState();
  }

  _completePAT() {
    if (!this._awaitingPAT) return;
    if (this._patTimer) {
      clearTimeout(this._patTimer);
      this._patTimer = null;
    }
    this._awaitingPAT = false;
    this.state.score = this.systems.scoreSystem?.addPoints(1, 1) ?? (this.state.score + 1);
    this.state.lastMove = 'PAT GOOD';
    this.systems.audio?.playEvent('score');
    this.systems.audio?.playEvent('crowd_swell');
    this.systems.vfx?.trigger('score_pop', { text: '+1 PAT' });
    this.end('player');
  }

  _pushNearestDefenderBack() {
    const nearestIndex = this._defenders.reduce((best, defender, idx, arr) => (
      !arr[best] || defender.depth < arr[best].depth ? idx : best
    ), 0);
    const nearest = this._defenders[nearestIndex];
    if (!nearest) return;
    nearest.depth += 3.4;
    this.scene?.animateDefenderTackle(nearestIndex);
  }

  _resetDriveState() {
    this._fieldPosition = DRIVE_START_YARD;
    this._firstDownMarker = DRIVE_START_YARD + FIRST_DOWN_DISTANCE;
    this._runnerLane = 0;
    this._awaitingPAT = false;
    this._burstMeter = 1;
    this._burstDepth = 0;
    this._lastBurstTick = Date.now();
    this._resetDefenders(false);
  }

  _resetDefenders(preserveDown) {
    this._defenders = [
      { lane: -4.5, depth: 12.5 },
      { lane: 0, depth: 9.5 },
      { lane: 4.2, depth: 14.5 },
    ];
    if (!preserveDown) {
      this.state.down = 1;
      this.state.toGo = FIRST_DOWN_DISTANCE;
      this.state.yardsGained = Math.max(0, Math.round((this._fieldPosition - DRIVE_START_YARD) * 10) / 10);
    }
  }

  _syncHudState() {
    this.systems?.hudStateSystem?.setState({
      score: this.systems?.scoreSystem?.getScore?.() ?? { total: this.state.score },
      prq: this.systems?.prqSystem?.getProfile?.() ?? { prq: this.state.prq, tier: 'Silver', recentEvents: [] },
      combo: {
        chain: this.state.touchdowns,
        multiplier: this.state.isBursting ? 2 : 1,
        windowOpen: this.state.isBursting,
        lastBreakReason: this.state.lastMove,
      },
      timer: {
        elapsedMs: Math.round((this._fieldPosition - DRIVE_START_YARD) * 100),
        remainingMs: this._awaitingPAT ? 3000 : null,
      },
    });
  }

  getState() {
    return {
      modeId: this.getModeId(),
      phase: this.state.phase,
      score: this.state.score,
      prq: this.state.prq,
      yardsGained: this.state.yardsGained,
      down: this.state.down,
      toGo: this.state.toGo,
      touchdowns: this.state.touchdowns,
      lastMove: this.state.lastMove,
      speed: Math.round(this.state.speed * 100) / 100,
      isBursting: this.state.isBursting,
      winner: this.state.winner,
      burstMeter: this._burstMeter,
      driveText: `${ordinalDown(this.state.down)} & ${this.state.toGo}`,
    };
  }

  getGamepadProps() {
    return this.input?.getGamepadProps() ?? {};
  }

  end(winner = this.state.winner) {
    if (this.loopTimer) {
      clearInterval(this.loopTimer);
      this.loopTimer = null;
    }
    if (this._patTimer) {
      clearTimeout(this._patTimer);
      this._patTimer = null;
    }
    this.state.phase = ModePhase.FINISHED;
    this.state.winner = winner ?? this.state.winner;
    this.systems?.audio?.playEvent('match_end');
    this.systems?.audio?.playEvent('crowd_loop_stop');
    this._syncHudState();
    return this.getState();
  }

  dispose() {
    this._disposed = true;
    this._sensory?.dispose();
    this._sensory = null;
    if (this.loopTimer) {
      clearInterval(this.loopTimer);
      this.loopTimer = null;
    }
    if (this._patTimer) {
      clearTimeout(this._patTimer);
      this._patTimer = null;
    }
    this.scene?.dispose();
    this.scene = null;
    this.systems?.scoreSystem?.reset?.();
    this.systems?.prqSystem?.reset?.();
    this.systems?.hudStateSystem?.reset?.();
    this.systems?.analytics?.reset?.();
    this.systems?.audio?.dispose?.();
    this.systems?.vfx?.dispose?.();
    this.systems = null;
    this.input = null;
    this._resetDriveState();
    this.state = this._createInitialState();
  }
}

export default FootballMode;
