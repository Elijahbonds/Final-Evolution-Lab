import { InputSystem } from '../../input/InputSystem.js';
import { GameModeInterface, ModePhase } from '../GameModeInterface.js';
import KarateScene from './KarateScene.js';

const STRIKE_DAMAGE = { light: 8, heavy: 15, special: 25, counter: 18 };
const DEFAULT_MATCH_TIME_SECONDS = 180;
const DODGE_IFRAME_MS   = 400;
const BLOCK_WINDOW_MS   = 800;
const HIT_STUN_MS       = 300;   // opponent immune window after heavy hit
const SPECIAL_CHAIN_REQ = 8;     // combo chain needed for special unlock
const AI_ATTACK_INTERVAL_MS_MIN = 1200;
const AI_ATTACK_INTERVAL_MS_MAX = 2800;
const LOW_HP_THRESHOLD  = 25;

function clampHP(v) { return Math.max(0, Math.min(100, v)); }

function createSystems() {
  return {
    strikeCore:  { damageByType: { ...STRIKE_DAMAGE } },
    dodgeCore:   { invincibilityMs: DODGE_IFRAME_MS },
    scoreSystem: {
      total: 0,
      addStrike(damage, combo) {
        const delta = damage * 10 + (combo > 1 ? combo * 5 : 0);
        this.total += delta;
        return this.total;
      },
    },
    comboSystem: {
      chain: 0,
      lastUpdatedAt: 0,
      registerStrike() { this.chain++; this.lastUpdatedAt = Date.now(); return this.chain; },
      reset() { this.chain = 0; return 0; },
    },
    prqSystem: {
      total: 50,
      recordDodge()         { this.total = Math.min(100, this.total + 6);  return this.total; },
      recordBlock()         { this.total = Math.min(100, this.total + 4);  return this.total; },
      recordStrike(damage)  { this.total = Math.min(100, this.total + Math.max(1, Math.round(damage / 8))); return this.total; },
      recordHit(damage)     { this.total = Math.max(0,   this.total - Math.max(2, Math.round(damage / 6))); return this.total; },
    },
  };
}

/**
 * Karate: Dojo Breach — premium mode with:
 *   - Virtual gamepad (□=light, △=heavy, ○=special, ✕=dodge, L1=block, R1=counter)
 *   - Hit-stun window: opponent immune for HIT_STUN_MS after heavy/special
 *   - Combo-locked specials: ○ only activates at chain ≥ SPECIAL_CHAIN_REQ
 *   - Basic AI opponent: escalating attack timing based on player HP
 *   - Audio and VFX hooks on every event
 *   - 3D scene reactive: hit flash, knockback, low-HP aura
 *
 * iOS parity: mirrors GamePlayView KarateEndlessMode + KarateMode
 * (chakraBar, karateHitFlash, showPerfectGuard, showVanishFlash).
 */
export class KarateMode extends GameModeInterface {
  /**
   * @param {string|HTMLCanvasElement|null|undefined} modeIdOrCanvas
   * @param {HTMLCanvasElement|null|undefined} [maybeCanvas]
   * @param {HTMLElement|null} [container]
   */
  constructor(modeIdOrCanvas, maybeCanvas, container) {
    const hasExplicitModeId = typeof modeIdOrCanvas === 'string';
    const modeId = hasExplicitModeId ? modeIdOrCanvas : 'karate';
    const canvas = hasExplicitModeId ? maybeCanvas : modeIdOrCanvas;
    super(modeId, canvas);

    this.container = container ?? null;
    this.scene     = null;
    this.systems   = null;
    this.input     = null;
    this.matchTimer = null;
    this._aiTimer   = null;

    this.playerStatus = { blockUntil: 0, invincibleUntil: 0, hitStunUntil: 0 };
    this.opponentStatus = { hitStunUntil: 0 };

    this.state = this._createInitialState();
  }

  _createInitialState() {
    return {
      phase:          ModePhase.WARMUP,
      timeRemaining:  DEFAULT_MATCH_TIME_SECONDS,
      playerHealth:   100,
      opponentHealth: 100,
      score:          0,
      prq:            50,
      combo:          0,
      winner:         null,
      lastAction:     '',
      showPerfectGuard: false,
    };
  }

  async start(container) {
    this.dispose();
    this.container = container ?? this.container;

    // Import createSharedSystems lazily to avoid circular dep
    const { createSharedSystems } = await import('../../systems/index.js');
    const shared = createSharedSystems(this.container);
    this.systems = { ...createSystems(), audio: shared.audio, vfx: shared.vfx, analytics: shared.analytics };

    this.scene = new KarateScene(this.canvas, this.systems);
    await this.scene.init();
    this.scene.setCameraAngle('actionCloseUp');

    this.input = new InputSystem(this.getModeId());
    this.input.onEvent = (ev) => this.update(ev);

    this.state = { ...this._createInitialState(), phase: ModePhase.ACTIVE };

    this.systems.audio.playEvent('match_start');
    this.systems.audio.playEvent('crowd_loop_start', { intensity: 0.08 });

    // Match countdown timer
    this.matchTimer = setInterval(() => {
      if (this.state.phase !== ModePhase.ACTIVE) return;
      this.state.timeRemaining = Math.max(0, this.state.timeRemaining - 1);
      if (this.state.timeRemaining === 0) this.end();
    }, 1000);

    // AI opponent timer
    this._scheduleAIAttack();

    return this.getState();
  }

  /** @private — schedule the next AI attack */
  _scheduleAIAttack() {
    const delay = this._aiDelay();
    this._aiTimer = setTimeout(() => {
      if (this.state.phase === ModePhase.ACTIVE) {
        this._aiAttack();
        this._scheduleAIAttack();
      }
    }, delay);
  }

  /** @private — AI delay escalates as player HP drops (mirror DynamicDifficulty.swift) */
  _aiDelay() {
    const healthFactor = this.state.playerHealth / 100;
    const min = AI_ATTACK_INTERVAL_MS_MIN * (0.5 + healthFactor * 0.5);
    const max = AI_ATTACK_INTERVAL_MS_MAX * (0.5 + healthFactor * 0.5);
    return min + Math.random() * (max - min);
  }

  /** @private — AI picks a move */
  _aiAttack() {
    if (this.state.opponentHealth <= 0) return;
    const roll = Math.random();
    const variant = roll < 0.6 ? 'light' : roll < 0.85 ? 'heavy' : 'special';
    const damage  = STRIKE_DAMAGE[variant] * (0.8 + Math.random() * 0.4);
    this.applyIncomingDamage(damage);

    // Scene reaction
    if (this.scene?.isFallback === false) {
      // AI hit — flip: the "player" received the hit, show on player side
    }
    this.systems?.audio?.playEvent(variant === 'light' ? 'strike_light' : variant === 'heavy' ? 'strike_heavy' : 'strike_special');
  }

  /**
   * Routes input events from virtual gamepad.
   * @param {{ type: string, payload?: object }} inputEvent
   */
  update(inputEvent = {}) {
    if (this.state.phase !== ModePhase.ACTIVE) return this.getState();
    const { type, payload = {} } = inputEvent;
    const now = Date.now();

    if (type === 'strike') {
      const variant  = payload.variant ?? 'light';
      const stun     = now < this.opponentStatus.hitStunUntil;
      if (!stun) {
        const damage = STRIKE_DAMAGE[variant] ?? STRIKE_DAMAGE.light;
        const combo  = this.systems.comboSystem.registerStrike();

        // Special move gated by combo chain
        if (variant === 'special' && combo < SPECIAL_CHAIN_REQ) {
          this.state.lastAction = 'NOT READY';
          return this.getState();
        }

        this.state.opponentHealth = clampHP(this.state.opponentHealth - damage);
        this.state.score = this.systems.scoreSystem.addStrike(damage, combo);
        this.state.prq   = this.systems.prqSystem.recordStrike(damage);
        this.state.combo = combo;
        this.state.lastAction = variant.toUpperCase();

        // Hit-stun on heavy/special
        if (variant === 'heavy' || variant === 'special') {
          this.opponentStatus.hitStunUntil = now + HIT_STUN_MS;
        }

        // Audio
        this.systems.audio?.playEvent(
          variant === 'special' ? 'strike_special' : variant === 'heavy' ? 'strike_heavy' : 'strike_light'
        );
        // VFX
        this.systems.vfx?.trigger(
          variant === 'special' ? 'heavy_impact' : variant === 'heavy' ? 'heavy_impact' : 'light_impact'
        );
        // Scene reaction
        this.scene?.triggerHitFlash?.(variant);
        if (variant === 'heavy' || variant === 'special') this.scene?.triggerKnockback?.(variant);

        if (combo >= 5) {
          this.systems.audio?.playEvent('combo_hit', { chain: combo });
          this.systems.vfx?.trigger('combo_hit', { chain: combo });
        }

        if (this.state.opponentHealth === 0) {
          this.systems.audio?.playEvent('ko');
          this.systems.vfx?.trigger('ko');
          this.end();
        }
      }
    }

    if (type === 'dodge') {
      this.playerStatus.invincibleUntil = now + DODGE_IFRAME_MS;
      this.state.prq = this.systems.prqSystem.recordDodge();
      this.state.lastAction = 'DODGE';
      this.systems.audio?.playEvent('dodge');
      this.systems.vfx?.trigger('light_impact');
    }

    if (type === 'block') {
      this.playerStatus.blockUntil = now + BLOCK_WINDOW_MS;
      this.state.lastAction = 'BLOCK';
      this.systems.audio?.playEvent('block');
      const incomingDamage = Number(payload.incomingDamage ?? 0);
      if (incomingDamage > 0) {
        this.state.prq = this.systems.prqSystem.recordBlock();
        this.state.showPerfectGuard = true;
        setTimeout(() => { this.state.showPerfectGuard = false; }, 800);
        this.applyIncomingDamage(incomingDamage);
      }
    }

    // Low-HP scene aura
    if (this.state.playerHealth <= LOW_HP_THRESHOLD && this.scene) {
      this.scene.setPlayerLowHPAura?.(true);
      this.systems.vfx?.trigger('low_hp', { active: true });
    } else if (this.state.playerHealth > LOW_HP_THRESHOLD && this.scene) {
      this.scene.setPlayerLowHPAura?.(false);
    }

    return this.getState();
  }

  getState() {
    return {
      modeId:         this.getModeId(),
      phase:          this.state.phase,
      timeRemaining:  this.state.timeRemaining,
      playerHealth:   this.state.playerHealth,
      opponentHealth: this.state.opponentHealth,
      score:          this.state.score,
      prq:            this.state.prq,
      combo:          this.state.combo,
      winner:         this.state.winner,
      lastAction:     this.state.lastAction,
      showPerfectGuard: this.state.showPerfectGuard,
    };
  }

  getGamepadProps() {
    return this.input?.getGamepadProps() ?? {};
  }

  end() {
    if (this.matchTimer) { clearInterval(this.matchTimer); this.matchTimer = null; }
    if (this._aiTimer)   { clearTimeout(this._aiTimer);   this._aiTimer   = null; }
    this.state.phase  = ModePhase.FINISHED;
    this.state.winner = this.state.playerHealth > this.state.opponentHealth ? 'player'
                      : this.state.opponentHealth > this.state.playerHealth  ? 'opponent'
                      : null;
    this.systems?.audio?.playEvent('match_end');
    this.systems?.audio?.playEvent('crowd_loop_stop');
    return this.getState();
  }

  applyIncomingDamage(baseDamage) {
    const now = Date.now();
    if (now <= this.playerStatus.invincibleUntil) return this.state.playerHealth;

    const isBlocking  = now <= this.playerStatus.blockUntil;
    const appliedDmg  = isBlocking ? baseDamage * 0.4 : baseDamage;

    this.state.playerHealth = clampHP(this.state.playerHealth - appliedDmg);
    this.state.prq = this.systems?.prqSystem?.recordHit?.(appliedDmg) ?? this.state.prq;

    if (!isBlocking) {
      this.systems?.comboSystem?.reset();
      this.state.combo = 0;
      this.systems?.audio?.playEvent('hit_receive');
      this.systems?.vfx?.trigger('hit_receive');
    }

    if (this.state.playerHealth === 0) this.end();
    return this.state.playerHealth;
  }

  dispose() {
    if (this.matchTimer) { clearInterval(this.matchTimer); this.matchTimer = null; }
    if (this._aiTimer)   { clearTimeout(this._aiTimer);   this._aiTimer   = null; }
    this.scene?.dispose();
    this.scene = null;
    this.systems?.audio?.dispose?.();
    this.systems?.vfx?.dispose?.();
    this.systems = null;
    this.input   = null;
    this.playerStatus   = { blockUntil: 0, invincibleUntil: 0, hitStunUntil: 0 };
    this.opponentStatus = { hitStunUntil: 0 };
    this.state = this._createInitialState();
  }
}

export default KarateMode;


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
