import { GameModeInterface, ModePhase } from '../GameModeInterface.js';
import KarateScene from './KarateScene.js';

const STRIKE_DAMAGE = {
  light: 8,
  heavy: 15,
  special: 25,
};

const DEFAULT_MATCH_TIME_SECONDS = 180;
const DODGE_IFRAME_MS = 400;
const BLOCK_WINDOW_MS = 800;

function clampHealth(value) {
  return Math.max(0, Math.min(100, value));
}

function determineWinner(playerHealth, opponentHealth) {
  if (playerHealth > opponentHealth) {
    return 'player';
  }

  if (opponentHealth > playerHealth) {
    return 'opponent';
  }

  return null;
}

function createSystems() {
  return {
    strikeCore: {
      damageByType: { ...STRIKE_DAMAGE },
    },
    dodgeCore: {
      invincibilityMs: DODGE_IFRAME_MS,
    },
    scoreSystem: {
      total: 0,
      addStrike(damage, combo) {
        const comboBonus = combo > 1 ? combo * 5 : 0;
        const delta = damage * 10 + comboBonus;
        this.total += delta;
        return this.total;
      },
    },
    comboSystem: {
      chain: 0,
      lastUpdatedAt: 0,
      registerStrike() {
        this.chain += 1;
        this.lastUpdatedAt = Date.now();
        return this.chain;
      },
      reset() {
        this.chain = 0;
        this.lastUpdatedAt = Date.now();
        return this.chain;
      },
    },
    prqSystem: {
      total: 0,
      recordDodge() {
        this.total += 2;
        return this.total;
      },
      recordStrike(damage) {
        this.total += Math.max(1, Math.round(damage / 10));
        return this.total;
      },
    },
  };
}

export class KarateMode extends GameModeInterface {
  /**
   * @param {string|HTMLCanvasElement|null|undefined} modeIdOrCanvas
   * @param {HTMLCanvasElement|null|undefined} [maybeCanvas]
   */
  constructor(modeIdOrCanvas, maybeCanvas) {
    const hasExplicitModeId = typeof modeIdOrCanvas === 'string';
    const modeId = hasExplicitModeId ? modeIdOrCanvas : 'karate';
    const canvas = hasExplicitModeId ? maybeCanvas : modeIdOrCanvas;

    super(modeId, canvas);

    this.scene = null;
    this.systems = null;
    this.matchTimer = null;
    this.state = {
      phase: ModePhase.WARMUP,
      timeRemaining: DEFAULT_MATCH_TIME_SECONDS,
      playerHealth: 100,
      opponentHealth: 100,
      score: 0,
      prq: 0,
      combo: 0,
      winner: null,
    };
    this.playerStatus = {
      blockUntil: 0,
      invincibleUntil: 0,
    };
  }

  /**
   * Creates mode systems, initializes the scene, and starts the match timer.
   * @returns {Promise<object>}
   */
  async start() {
    this.dispose();

    this.systems = createSystems();
    this.state = {
      phase: ModePhase.WARMUP,
      timeRemaining: DEFAULT_MATCH_TIME_SECONDS,
      playerHealth: 100,
      opponentHealth: 100,
      score: 0,
      prq: 0,
      combo: 0,
      winner: null,
    };
    this.playerStatus = {
      blockUntil: 0,
      invincibleUntil: 0,
    };

    this.scene = new KarateScene(this.canvas, this.systems);
    await this.scene.init();

    this.state.phase = ModePhase.ACTIVE;
    this.matchTimer = setInterval(() => {
      if (this.state.phase !== ModePhase.ACTIVE) {
        return;
      }

      this.state.timeRemaining = Math.max(0, this.state.timeRemaining - 1);

      if (this.state.timeRemaining === 0) {
        this.end();
      }
    }, 1000);

    return this.getState();
  }

  /**
   * Routes gameplay input to strike, dodge, and block handling.
   * @param {{ type: 'strike'|'dodge'|'block', payload?: object }} inputEvent
   * @returns {object}
   */
  update(inputEvent = {}) {
    if (this.state.phase !== ModePhase.ACTIVE) {
      return this.getState();
    }

    const { type, payload = {} } = inputEvent;

    if (type === 'strike') {
      const strikeType = payload.variant || payload.strikeType || 'light';
      const damage = this.systems?.strikeCore?.damageByType?.[strikeType] ?? STRIKE_DAMAGE.light;
      const combo = this.systems.comboSystem.registerStrike();

      this.state.opponentHealth = clampHealth(this.state.opponentHealth - damage);
      this.state.score = this.systems.scoreSystem.addStrike(damage, combo);
      this.state.prq = this.systems.prqSystem.recordStrike(damage);
      this.state.combo = combo;

      if (this.state.opponentHealth === 0) {
        this.end();
      }
    }

    if (type === 'dodge') {
      this.playerStatus.invincibleUntil = Date.now() + (this.systems?.dodgeCore?.invincibilityMs ?? DODGE_IFRAME_MS);
      this.state.prq = this.systems.prqSystem.recordDodge();
    }

    if (type === 'block') {
      this.playerStatus.blockUntil = Date.now() + BLOCK_WINDOW_MS;
      const incomingDamage = Number(payload.incomingDamage ?? payload.damage ?? 0);

      if (incomingDamage > 0) {
        this.applyIncomingDamage(incomingDamage);
      }
    }

    return this.getState();
  }

  /**
   * Returns a serializable snapshot of the current mode state.
   * @returns {{ modeId: string, phase: 'warmup'|'active'|'finished', timeRemaining: number, playerHealth: number, opponentHealth: number, score: number, prq: number, combo: number, winner: null|'player'|'opponent' }}
   */
  getState() {
    return {
      modeId: this.getModeId(),
      phase: this.state.phase,
      timeRemaining: this.state.timeRemaining,
      playerHealth: this.state.playerHealth,
      opponentHealth: this.state.opponentHealth,
      score: this.state.score,
      prq: this.state.prq,
      combo: this.state.combo,
      winner: this.state.winner,
    };
  }

  /**
   * Stops the timer, resolves the match winner, and returns the final state.
   * @returns {object}
   */
  end() {
    if (this.matchTimer) {
      clearInterval(this.matchTimer);
      this.matchTimer = null;
    }

    this.state.phase = ModePhase.FINISHED;
    this.state.winner = determineWinner(this.state.playerHealth, this.state.opponentHealth);

    return this.getState();
  }

  /**
   * Disposes the active match timer and scene resources.
   */
  dispose() {
    if (this.matchTimer) {
      clearInterval(this.matchTimer);
      this.matchTimer = null;
    }

    this.scene?.dispose();
    this.scene = null;
    this.systems = null;
  }

  applyIncomingDamage(baseDamage) {
    const now = Date.now();

    if (now <= this.playerStatus.invincibleUntil) {
      return this.state.playerHealth;
    }

    const isBlocking = now <= this.playerStatus.blockUntil;
    const appliedDamage = isBlocking ? baseDamage * 0.4 : baseDamage;

    this.state.playerHealth = clampHealth(this.state.playerHealth - appliedDamage);

    if (!isBlocking) {
      this.systems?.comboSystem?.reset();
      this.state.combo = this.systems?.comboSystem?.chain ?? 0;
    }

    if (this.state.playerHealth === 0) {
      this.end();
    }

    return this.state.playerHealth;
  }
}

export default KarateMode;
