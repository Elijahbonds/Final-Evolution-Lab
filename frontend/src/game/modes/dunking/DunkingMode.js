import { createSharedSystems } from '../../systems/index.js';
import { GameModeInterface, ModePhase } from '../GameModeInterface.js';
import DunkingScene from './DunkingScene.js';

const DEFAULT_MATCH_TIME_SECONDS = 180;
const HOOP_POSITION = { x: 0, y: 3.05, z: -13.23 };
const HOOP_PROXIMITY_THRESHOLD = 2.5;

function distanceToHoop(position = {}) {
  const dx = (position.x ?? 0) - HOOP_POSITION.x;
  const dy = (position.y ?? 0) - HOOP_POSITION.y;
  const dz = (position.z ?? 0) - HOOP_POSITION.z;

  return Math.sqrt(dx * dx + dy * dy + dz * dz);
}

/**
 * Dunking Hero mode skin mounted on shared systems.
 */
export class DunkingMode extends GameModeInterface {
  /**
   * @param {string|HTMLCanvasElement|null|undefined} modeIdOrCanvas
   * @param {HTMLCanvasElement|null|undefined} [maybeCanvas]
   */
  constructor(modeIdOrCanvas, maybeCanvas) {
    const hasExplicitModeId = typeof modeIdOrCanvas === 'string';
    const modeId = hasExplicitModeId ? modeIdOrCanvas : 'basketball_dunk';
    const canvas = hasExplicitModeId ? maybeCanvas : modeIdOrCanvas;

    super(modeId, canvas);

    this.scene = null;
    this.systems = null;
    this.matchTimer = null;
    this.playerPosition = { x: 0, y: 0, z: 0 };
    this.state = this.createInitialState();
  }

  /**
   * Build the default serializable mode state.
   *
   * @returns {{ phase: 'warmup', timeRemaining: number, score: number, prq: number, combo: { chain: number, multiplier: number, windowOpen: boolean } }}
   */
  createInitialState() {
    return {
      phase: ModePhase.WARMUP,
      timeRemaining: DEFAULT_MATCH_TIME_SECONDS,
      score: 0,
      prq: 50,
      combo: {
        chain: 0,
        multiplier: 1,
        windowOpen: false,
      },
    };
  }

  /**
   * Creates shared systems, initializes the scene, and starts the match timer.
   *
   * @returns {Promise<object>}
   */
  async start() {
    this.dispose();

    this.systems = createSharedSystems();
    this.systems.scoreSystem = this.systems.score;
    this.systems.comboSystem = this.systems.combo;
    this.systems.prqSystem = this.systems.prq;
    this.systems.hudStateSystem = this.systems.hudState;

    this.scene = new DunkingScene(this.canvas, this.systems);
    await this.scene.init();

    this.playerPosition = { x: 0, y: 0, z: 0 };
    this.state = {
      ...this.createInitialState(),
      phase: ModePhase.ACTIVE,
      score: this.systems.scoreSystem.getScore().total,
      prq: this.systems.prqSystem.getProfile().prq,
    };

    this.syncHudState();

    this.matchTimer = setInterval(() => {
      if (this.state.phase !== ModePhase.ACTIVE) {
        return;
      }

      this.state.timeRemaining = Math.max(0, this.state.timeRemaining - 1);
      this.syncHudState();

      if (this.state.timeRemaining === 0) {
        this.end();
      }
    }, 1000);

    return this.getState();
  }

  /**
   * Routes dunking inputs into the shared systems.
   *
   * @param {{ type: 'jump'|'dunk'|'dodge', payload?: object }} inputEvent
   * @returns {object}
   */
  update(inputEvent = {}) {
    if (this.state.phase !== ModePhase.ACTIVE || !this.systems) {
      return this.getState();
    }

    const { type, payload = {} } = inputEvent;

    if (payload.position && typeof payload.position === 'object') {
      this.playerPosition = {
        ...this.playerPosition,
        ...payload.position,
      };
    }

    if (type === 'jump') {
      this.systems.analytics.track('jump', { position: this.playerPosition });
      this.state.prq = this.systems.prqSystem.recordEvent({ type: 'hit', quality: 'good' });
    }

    if (type === 'dodge') {
      this.systems.analytics.track('dodge', { direction: payload.direction || 'neutral' });
      this.state.prq = this.systems.prqSystem.recordEvent({ type: 'dodge', quality: 'clean' });
      this.state.combo = {
        ...this.state.combo,
        ...this.systems.comboSystem.breakCombo('dodge-reset'),
      };
    }

    if (type === 'dunk') {
      const nearHoop =
        payload.nearHoop === true ||
        Number(payload.distanceToHoop) <= HOOP_PROXIMITY_THRESHOLD ||
        distanceToHoop(this.playerPosition) <= HOOP_PROXIMITY_THRESHOLD;

      if (nearHoop) {
        const totalScore = this.systems.scoreSystem.addPoints(
          2,
          this.systems.comboSystem.getMultiplier()
        );
        const comboState = this.systems.comboSystem.registerHit('perfect');
        const prq = this.systems.prqSystem.recordEvent({ type: 'combo', quality: 'perfect' });

        this.state.score = totalScore;
        this.state.prq = prq;
        this.state.combo = {
          ...comboState,
          lastBreakReason: this.systems.comboSystem.lastBreakReason ?? null,
        };

        this.systems.analytics.track('prq_event', {
          mode: 'dunking',
          action: 'dunk',
          score: totalScore,
          prq,
        });
        this.systems.analytics.track('combo_hit', {
          mode: 'dunking',
          chain: comboState.chain,
          multiplier: comboState.multiplier,
        });
      } else {
        this.state.prq = this.systems.prqSystem.recordEvent({ type: 'miss', quality: 'poor' });
        this.state.combo = this.systems.comboSystem.breakCombo('missed-dunk');
        this.systems.analytics.track('dunk_miss', {
          mode: 'dunking',
          position: this.playerPosition,
        });
      }
    }

    this.syncHudState();
    return this.getState();
  }

  /**
   * Returns a serializable snapshot of the current mode state.
   *
   * @returns {{ modeId: string, phase: 'warmup'|'active'|'finished', timeRemaining: number, score: number, prq: number, combo: { chain: number, multiplier: number, windowOpen?: boolean, lastBreakReason?: string|null } }}
   */
  getState() {
    return {
      modeId: this.getModeId(),
      phase: this.state.phase,
      timeRemaining: this.state.timeRemaining,
      score: this.state.score,
      prq: this.state.prq,
      combo: { ...this.state.combo },
    };
  }

  /**
   * Stops the timer and returns the final mode snapshot.
   *
   * @returns {object}
   */
  end() {
    if (this.matchTimer) {
      clearInterval(this.matchTimer);
      this.matchTimer = null;
    }

    this.state.phase = ModePhase.FINISHED;
    this.syncHudState();
    return this.getState();
  }

  /**
   * Disposes the active scene and shared systems.
   */
  dispose() {
    if (this.matchTimer) {
      clearInterval(this.matchTimer);
      this.matchTimer = null;
    }

    this.scene?.dispose();
    this.scene = null;

    this.systems?.scoreSystem?.reset?.();
    this.systems?.comboSystem?.reset?.();
    this.systems?.prqSystem?.reset?.();
    this.systems?.hudStateSystem?.reset?.();
    this.systems?.analytics?.reset?.();
    this.systems?.skillLab?.reset?.();

    this.systems = null;
    this.playerPosition = { x: 0, y: 0, z: 0 };
    this.state = this.createInitialState();
  }

  /**
   * Syncs the shared HUD state store with the current mode snapshot.
   */
  syncHudState() {
    this.systems?.hudStateSystem?.setState({
      score: this.systems?.scoreSystem?.getScore() ?? { total: this.state.score },
      prq: this.systems?.prqSystem?.getProfile() ?? { prq: this.state.prq, tier: 'Silver', recentEvents: [] },
      combo: {
        ...this.state.combo,
        lastBreakReason: this.systems?.comboSystem?.lastBreakReason ?? this.state.combo.lastBreakReason ?? null,
      },
      timer: {
        elapsedMs: (DEFAULT_MATCH_TIME_SECONDS - this.state.timeRemaining) * 1000,
        remainingMs: this.state.timeRemaining * 1000,
      },
    });
  }
}

// COMPLIANCE TODO: real-money IRL Dunking mode is legal-review-gated — DO NOT ship live without sign-off

export default DunkingMode;
