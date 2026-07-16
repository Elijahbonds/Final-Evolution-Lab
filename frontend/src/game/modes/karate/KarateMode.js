import { InputSystem } from '../../input/InputSystem.js';
import { GameModeInterface, ModePhase } from '../GameModeInterface.js';
import { feelConfig } from '../../systems/feelConfig.js';
import { FixedStepLoop } from '../../core/FixedStepLoop.js';
import { InputBuffer } from '../../systems/InputBuffer.js';
import { StateMachine } from '../../systems/StateMachine.js';
import { SensoryBus } from '../../systems/SensoryBus.js';
import KarateScene from './KarateScene.js';

/** Match flow: no AI action and no timer before FIGHT (round-gate rule). */
export const MatchPhase = Object.freeze({
  READY:     'Ready',
  COUNTDOWN: 'Countdown',
  FIGHT:     'Fight',
  OVER:      'Over',
});

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

    // Feel systems (same process as Dunk)
    this._disposed = false;
    this._loop = null;
    this._rafId = null;
    this._lastRafTs = 0;
    this._sensory = null;
    this._inputBuffer = new InputBuffer({ windowMs: feelConfig.input.bufferMs });
    // Pre-fight presses persist through the whole countdown (fighting-game
    // convention: mash during 3-2-1, your strike fires on FIGHT).
    this._preFightBuffer = new InputBuffer({
      windowMs: feelConfig.karate.readyMs + feelConfig.karate.countdownMs + 1000,
    });
    this._bufferedVariant = 'light';
    this._aiNextIn = 0; // seconds until next AI attack (fixed-step timer)
    this._matchFsm = new StateMachine({
      initial: MatchPhase.READY,
      states: {
        [MatchPhase.READY]: {},
        [MatchPhase.COUNTDOWN]: {},
        [MatchPhase.FIGHT]: {
          enter: () => {
            this.systems?.audio?.playEvent('match_start');
            this.systems?.audio?.playEvent('crowd_loop_start', { intensity: 0.08 });
            this._aiNextIn = this._aiDelay() / 1000;
            // A strike buffered during READY/COUNTDOWN fires the moment
            // the fight is live (no dropped inputs).
            if (this._preFightBuffer.consume('strike')) {
              this._performStrike(this._bufferedVariant);
            }
          },
        },
        [MatchPhase.OVER]: {},
      },
    });

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
    this._disposed = false;
    this.container = container ?? this.container;

    // Import createSharedSystems lazily to avoid circular dep
    const { createSharedSystems } = await import('../../systems/index.js');
    const shared = createSharedSystems(this.container);
    this.systems = { ...createSystems(), audio: shared.audio, vfx: shared.vfx, analytics: shared.analytics };

    this.scene = new KarateScene(this.canvas, this.systems);
    await this.scene.init();

    // Disposed while init awaited (StrictMode remount) — bail cleanly.
    if (this._disposed) {
      this.scene.dispose();
      this.scene = null;
      return this.getState();
    }
    this.scene.setCameraAngle('actionCloseUp');

    this.input = new InputSystem(this.getModeId());
    this.input.onEvent = (ev) => this.update(ev);

    this.state = { ...this._createInitialState(), phase: ModePhase.ACTIVE };
    this._inputBuffer.clear();
    this._preFightBuffer.clear();
    this._matchFsm.transition(MatchPhase.READY);

    // Match clock: wall-clock by documented choice, and ONLY during FIGHT —
    // the round gate means no timer and no AI before the fight is live.
    this.matchTimer = setInterval(() => {
      if (this.state.phase !== ModePhase.ACTIVE) return;
      if (this._matchFsm.current !== MatchPhase.FIGHT) return;
      this.state.timeRemaining = Math.max(0, this.state.timeRemaining - 1);
      if (this.state.timeRemaining === 0) this.end();
    }, 1000);

    // Fixed-timestep simulation drives match flow + the AI attack clock.
    this._loop = new FixedStepLoop({
      hz: feelConfig.timestepHz,
      maxAccumulatedMs: feelConfig.maxAccumulatedMs,
      update: (dt) => this._fixedUpdate(dt),
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
        crowd:  '/audio/sfx_crowd_cheer.mp3',
      },
    });

    return this.getState();
  }

  /**
   * Fixed simulation step: match-flow FSM + the AI attack clock. Because the
   * AI clock lives here, hit-stop freezes the opponent too — impacts pause
   * the whole fight, not just the player.
   * @private
   */
  _fixedUpdate(dt) {
    if (this.state.phase !== ModePhase.ACTIVE) return;
    this._matchFsm.update(dt);
    const k = feelConfig.karate;
    switch (this._matchFsm.current) {
      case MatchPhase.READY:
        if (this._matchFsm.timeInState * 1000 >= k.readyMs) {
          this._matchFsm.transition(MatchPhase.COUNTDOWN);
        }
        break;
      case MatchPhase.COUNTDOWN:
        if (this._matchFsm.timeInState * 1000 >= k.countdownMs) {
          this._matchFsm.transition(MatchPhase.FIGHT);
        }
        break;
      case MatchPhase.FIGHT: {
        this._aiNextIn -= dt;
        if (this._aiNextIn <= 0) {
          this._aiAttack();
          this._aiNextIn = this._aiDelay() / 1000;
        }
        break;
      }
      default:
        break;
    }
  }

  /** @private */
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

    // Round gate: before FIGHT, strikes BUFFER (they fire the moment the
    // fight goes live) and everything else is ignored — no pre-fight damage.
    if (this._matchFsm.current !== MatchPhase.FIGHT) {
      if (type === 'strike') {
        this._bufferedVariant = payload.variant ?? payload.strikeType ?? 'light';
        this._preFightBuffer.press('strike');
      }
      return this.getState();
    }

    if (type === 'strike') {
      this._performStrike(payload.variant ?? payload.strikeType ?? 'light', now);
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
      const incomingDamage = Number(payload.incomingDamage ?? payload.damage ?? 0);
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

  /**
   * Executes a player strike (only legal during FIGHT — callers gate).
   * @private
   */
  _performStrike(variant, now = Date.now()) {
    const stun = now < this.opponentStatus.hitStunUntil;
    if (stun) return;

    const damage = STRIKE_DAMAGE[variant] ?? STRIKE_DAMAGE.light;
    const combo  = this.systems.comboSystem.registerStrike();

    // Special move gated by combo chain
    if (variant === 'special' && combo < SPECIAL_CHAIN_REQ) {
      this.state.lastAction = 'NOT READY';
      return;
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

    // Sensory thud on the same frame as the hit
    const k = feelConfig.karate;
    const heavy = variant === 'heavy' || variant === 'special';
    this._sensory?.emit({
      sfx: 'impact',
      volume: heavy ? 1 : 0.5,
      shake: heavy ? k.heavyShake : k.hitShake,
      rumbleMs: heavy ? feelConfig.sensory.rumbleMs : 0,
    });

    if (combo >= 5) {
      this.systems.audio?.playEvent('combo_hit', { chain: combo });
      this.systems.vfx?.trigger('combo_hit', { chain: combo });
    }

    if (this.state.opponentHealth === 0) {
      this.systems.audio?.playEvent('ko');
      this.systems.vfx?.trigger('ko');
      // The KO is FELT before it is announced: freeze + big shake + crowd.
      this._sensory?.emit({
        sfx: 'impact', volume: 1,
        shake: k.koShake, hitStopMs: k.koHitStopMs,
        rumbleMs: feelConfig.sensory.rumbleMs,
      });
      this._sensory?.emit({ sfx: 'crowd', volume: feelConfig.sensory.crowdVolume });
      this.end();
    }
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
      matchPhase:     this._matchFsm.current,
      countdownMsRemaining: this._matchFsm.current === MatchPhase.COUNTDOWN
        ? Math.max(0, feelConfig.karate.countdownMs - this._matchFsm.timeInState * 1000)
        : 0,
    };
  }

  getGamepadProps() {
    return this.input?.getGamepadProps() ?? {};
  }

  end() {
    if (this.matchTimer) { clearInterval(this.matchTimer); this.matchTimer = null; }
    if (this._aiTimer)   { clearTimeout(this._aiTimer);   this._aiTimer   = null; }
    this._matchFsm.transition(MatchPhase.OVER);
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
      this._sensory?.emit({ sfx: 'impact', volume: 0.4, shake: feelConfig.karate.hitShake });
    }

    if (this.state.playerHealth === 0) {
      // Player KO: same freeze-frame weight as dealing one.
      this._sensory?.emit({
        sfx: 'impact', volume: 1,
        shake: feelConfig.karate.koShake,
        hitStopMs: feelConfig.karate.koHitStopMs,
      });
      this.end();
    }
    return this.state.playerHealth;
  }

  dispose() {
    this._disposed = true;
    if (this.matchTimer) { clearInterval(this.matchTimer); this.matchTimer = null; }
    if (this._aiTimer)   { clearTimeout(this._aiTimer);   this._aiTimer   = null; }
    if (this._loop) { this._loop.stop(); this._loop = null; }
    if (this._rafId !== null && typeof window !== 'undefined') {
      window.cancelAnimationFrame(this._rafId);
      this._rafId = null;
    }
    this._sensory?.dispose();
    this._sensory = null;
    this._inputBuffer.clear();
    this._preFightBuffer.clear();
    this._matchFsm.transition(MatchPhase.READY);
    this.scene?.setFrameCallback?.(null);
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
