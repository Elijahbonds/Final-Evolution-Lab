import { createSharedSystems } from '../../systems/index.js';
import { InputSystem } from '../../input/InputSystem.js';
import { GameModeInterface, ModePhase } from '../GameModeInterface.js';
import DunkingScene from './DunkingScene.js';

const DEFAULT_MATCH_TIME_SECONDS = 180;
const HOOP_POSITION = { x: 0, y: 3.05, z: -13.23 };
const HOOP_PROXIMITY_THRESHOLD = 2.5;
const CHARGE_MAX_HOLD_MS = 2000;

function distanceToHoop(position = {}) {
  const dx = (position.x ?? 0) - HOOP_POSITION.x;
  const dy = (position.y ?? 0) - HOOP_POSITION.y;
  const dz = (position.z ?? 0) - HOOP_POSITION.z;
  return Math.sqrt(dx * dx + dy * dy + dz * dz);
}

/**
 * Maps an iOS ArcadeFaceButton dunk modifier to score value.
 * Mirrors DunkModifier.scoreMultiplier from iOS.
 */
function modifierMultiplier(variant) {
  switch (variant) {
    case 'signature':   return 1.8;
    case 'power':       return 1.35;
    case 'contortion':
    case 'flashy':      return 1.25;
    default:            return 1.0;
  }
}

/**
 * Dunking Hero mode — premium implementation with:
 *   - Virtual gamepad input (GamepadOverlay / InputSystem)
 *   - Charge mechanic: hold L2/R2 builds power, release on dunk multiplies score
 *   - 4 dunk variants via face buttons (△=contortion, □=windmill, ○=power, ✕=jump)
 *   - Audio (AudioSystem) and screen VFX (VFXSystem) on every event
 *   - Scenic camera sequence triggered on dunk score
 *
 * iOS parity: mirrors GamePlayView dunkEngine, dunkTimerTask,
 * styleTriggerHeld, powerTriggerHeld, showComboChain from GamePlayView.swift.
 */
export class DunkingMode extends GameModeInterface {
  /**
   * @param {string|HTMLCanvasElement|null|undefined} modeIdOrCanvas
   * @param {HTMLCanvasElement|null|undefined} [maybeCanvas]
   * @param {HTMLElement|null} [container]  — root DOM element for VFXSystem
   */
  constructor(modeIdOrCanvas, maybeCanvas, container) {
    const hasExplicitModeId = typeof modeIdOrCanvas === 'string';
    const modeId = hasExplicitModeId ? modeIdOrCanvas : 'basketball_dunk';
    const canvas = hasExplicitModeId ? maybeCanvas : modeIdOrCanvas;

    super(modeId, canvas);

    this.container = container ?? null;
    this.scene     = null;
    this.systems   = null;
    this.input     = null;
    this.matchTimer = null;
    this.playerPosition = { x: 0, y: 0, z: 0 };
    this.playerVelocity = { x: 0, y: 0, z: 0 };

    // Charge state (mirrors iOS styleTriggerHeld / powerTriggerHeld)
    this._styleCharge  = 0; // 0–1 from L2
    this._powerCharge  = 0; // 0–1 from R2
    this._chargeStartAt = null;
    this._isMidAir     = false;
    this._pendingDunkVariant = null;

    this.state = this._createInitialState();
  }

  _createInitialState() {
    return {
      phase:         ModePhase.WARMUP,
      timeRemaining: DEFAULT_MATCH_TIME_SECONDS,
      score:         0,
      prq:           50,
      combo: { chain: 0, multiplier: 1, windowOpen: false },
    };
  }

  /**
   * Creates shared systems, initializes the scene, wires input, starts match.
   * @param {HTMLElement|null} [container]
   * @returns {Promise<object>}
   */
  async start(container) {
    this.dispose();

    this.container = container ?? this.container;
    this.systems   = createSharedSystems(this.container);

    // Alias for backwards compat
    this.systems.scoreSystem   = this.systems.score;
    this.systems.comboSystem   = this.systems.combo;
    this.systems.prqSystem     = this.systems.prq;
    this.systems.hudStateSystem = this.systems.hudState;

    this.scene = new DunkingScene(this.canvas, this.systems);
    await this.scene.init();

    // Wire input system for virtual gamepad
    this.input = new InputSystem(this.getModeId());
    this.input.onEvent = (ev) => this.update(ev);

    this.playerPosition = { x: 0, y: 0, z: 0 };
    this.state = {
      ...this._createInitialState(),
      phase: ModePhase.ACTIVE,
      score: this.systems.scoreSystem.getScore().total,
      prq:   this.systems.prqSystem.getProfile().prq,
    };

    this._syncHudState();

    // Announce match start with audio + VFX
    this.systems.audio.playEvent('match_start');
    this.systems.audio.playEvent('crowd_loop_start', { intensity: 0.12 });

    this.matchTimer = setInterval(() => {
      if (this.state.phase !== ModePhase.ACTIVE) return;
      this.state.timeRemaining = Math.max(0, this.state.timeRemaining - 1);
      if (this.state.timeRemaining <= 10) {
        this.systems.audio.playEvent('countdown_tick');
      }
      this._syncHudState();
      if (this.state.timeRemaining === 0) this.end();
    }, 1000);

    return this.getState();
  }

  /**
   * Routes all input events (face buttons, D-pad, sticks, triggers).
   * Handles: jump, dunk variants, charge mechanic, dodge, movement.
   *
   * @param {{ type: string, payload?: object }} inputEvent
   * @returns {object}
   */
  update(inputEvent = {}) {
    if (this.state.phase !== ModePhase.ACTIVE || !this.systems) return this.getState();

    const { type, payload = {} } = inputEvent;

    // ── Direct position set (headless/test drivers) ────────────────────────
    if (payload.position && typeof payload.position === 'object') {
      this.playerPosition = { ...this.playerPosition, ...payload.position };
    }

    // ── Movement (left stick) ───────────────────────────────────────────────
    if (type === 'move' && payload.leftStick) {
      const { x, y } = payload.leftStick;
      this.playerVelocity = { x, y: 0, z: -y };
      this.playerPosition = {
        x: Math.max(-7, Math.min(7, this.playerPosition.x + x * 0.4)),
        y: this.playerPosition.y,
        z: Math.max(-13.5, Math.min(13, this.playerPosition.z - y * 0.4)),
      };
    }

    // ── Charge input (L2=style, R2=power) ──────────────────────────────────
    if (type === 'charge') {
      if (payload.trigger === 'style') {
        this._styleCharge = payload.depth ?? 0;
        if (this._styleCharge > 0.05 && !this._chargeStartAt) {
          this._chargeStartAt = Date.now();
        }
      }
      if (payload.trigger === 'power') {
        this._powerCharge = payload.depth ?? 0;
      }
    }

    // ── Jump (✕ button) ─────────────────────────────────────────────────────
    if (type === 'jump') {
      this._isMidAir = true;
      this.systems.audio.playEvent('jump');
      this.systems.vfx.trigger('light_impact');
      this.state.prq = this.systems.prqSystem.recordEvent({ type: 'hit', quality: 'good' });
    }

    // ── Dodge ───────────────────────────────────────────────────────────────
    if (type === 'dodge') {
      this.systems.audio.playEvent('swoosh');
      this.systems.vfx.trigger('light_impact');
      this.state.prq  = this.systems.prqSystem.recordEvent({ type: 'dodge', quality: 'clean' });
      this.state.combo = {
        ...this.state.combo,
        ...this.systems.comboSystem.breakCombo('dodge-reset'),
      };
    }

    // ── Dunk (△/□/○ face buttons or explicit dunk event) ───────────────────
    if (type === 'dunk') {
      const variant = payload.variant ?? 'standard';
      this._pendingDunkVariant = variant;
      this._executeDunk(variant, payload.modifier, payload);
    }

    this._syncHudState();
    return this.getState();
  }

  /** @private */
  _executeDunk(variant, modifier, payload = {}) {
    const nearHoop =
      payload.nearHoop === true ||
      Number(payload.distanceToHoop) <= HOOP_PROXIMITY_THRESHOLD ||
      distanceToHoop(this.playerPosition) <= HOOP_PROXIMITY_THRESHOLD;

    // Compute charge bonus (style + power triggers)
    const holdMs    = this._chargeStartAt ? Math.min(Date.now() - this._chargeStartAt, CHARGE_MAX_HOLD_MS) : 0;
    const chargePct = holdMs / CHARGE_MAX_HOLD_MS;
    const styleBonus = 1 + this._styleCharge * 0.3;
    const powerBonus = 1 + this._powerCharge * 0.5;
    const chargeBonus = 1 + chargePct * 0.4;
    const variantMult = modifierMultiplier(modifier ?? variant);
    this._styleCharge  = 0;
    this._powerCharge  = 0;
    this._chargeStartAt = null;
    this._isMidAir     = false;

    if (nearHoop) {
      const basePoints = 2;
      const comboMult  = this.systems.comboSystem.getMultiplier();
      const totalMult  = comboMult * variantMult * styleBonus * powerBonus * chargeBonus;
      const totalScore = this.systems.scoreSystem.addPoints(basePoints, totalMult);
      const comboState = this.systems.comboSystem.registerHit('perfect');
      const prq        = this.systems.prqSystem.recordEvent({ type: 'combo', quality: 'perfect' });

      this.state.score = totalScore;
      this.state.prq   = prq;
      this.state.combo = { ...comboState, lastBreakReason: null };

      // Audio
      this.systems.audio.playEvent('dunk', { modifier: modifier ?? variant });
      if (totalMult >= 2) this.systems.audio.playEvent('perfect');

      // VFX
      this.systems.vfx.trigger('dunk', { points: Math.round(basePoints * totalMult) });
      this.systems.vfx.trigger('combo_hit', { chain: comboState.chain });

      // Scene reactions
      this.scene?.burstConfetti?.();
      this.scene?.flashGlow?.();
      this.scene?.triggerDunkCameraSequence?.();

      // Analytics
      this.systems.analytics.track('dunk_score', {
        mode: 'dunking', variant, modifier,
        score: totalScore, prq, combo: comboState.chain,
        chargeBonus: chargePct.toFixed(2),
      });
    } else {
      this.state.prq  = this.systems.prqSystem.recordEvent({ type: 'miss', quality: 'poor' });
      this.state.combo = this.systems.comboSystem.breakCombo('missed-dunk');
      this.systems.audio.playEvent('dunk_miss');
      this.systems.vfx.trigger('dunk_miss');
      this.systems.analytics.track('dunk_miss', { mode: 'dunking', position: this.playerPosition });
    }
  }

  getState() {
    return {
      modeId:        this.getModeId(),
      phase:         this.state.phase,
      timeRemaining: this.state.timeRemaining,
      score:         this.state.score,
      prq:           this.state.prq,
      combo:         { ...this.state.combo },
      // Expose charge state for HUD power-meter display
      styleCharge:   this._styleCharge,
      powerCharge:   this._powerCharge,
      isMidAir:      this._isMidAir,
    };
  }

  /**
   * Returns GamepadOverlay props ready to spread onto <GamepadOverlay />.
   * Callers: `<GamepadOverlay {...mode.getGamepadProps()} />`
   */
  getGamepadProps() {
    return this.input?.getGamepadProps() ?? {};
  }

  end() {
    if (this.matchTimer) { clearInterval(this.matchTimer); this.matchTimer = null; }
    this.state.phase = ModePhase.FINISHED;
    this.systems?.audio?.playEvent('match_end');
    this.systems?.audio?.playEvent('crowd_loop_stop');
    this._syncHudState();
    return this.getState();
  }

  dispose() {
    if (this.matchTimer) { clearInterval(this.matchTimer); this.matchTimer = null; }
    this.scene?.dispose();
    this.scene = null;
    this.systems?.scoreSystem?.reset?.();
    this.systems?.comboSystem?.reset?.();
    this.systems?.prqSystem?.reset?.();
    this.systems?.hudStateSystem?.reset?.();
    this.systems?.analytics?.reset?.();
    this.systems?.skillLab?.reset?.();
    this.systems?.audio?.dispose?.();
    this.systems?.vfx?.dispose?.();
    this.systems = null;
    this.input   = null;
    this.playerPosition = { x: 0, y: 0, z: 0 };
    this.playerVelocity = { x: 0, y: 0, z: 0 };
    this._styleCharge  = 0;
    this._powerCharge  = 0;
    this._chargeStartAt = null;
    this._isMidAir     = false;
    this.state = this._createInitialState();
  }

  _syncHudState() {
    this.systems?.hudStateSystem?.setState({
      score:  this.systems?.scoreSystem?.getScore() ?? { total: this.state.score },
      prq:    this.systems?.prqSystem?.getProfile() ?? { prq: this.state.prq, tier: 'Silver', recentEvents: [] },
      combo:  { ...this.state.combo, lastBreakReason: this.systems?.comboSystem?.lastBreakReason ?? null },
      timer:  {
        elapsedMs:   (DEFAULT_MATCH_TIME_SECONDS - this.state.timeRemaining) * 1000,
        remainingMs: this.state.timeRemaining * 1000,
      },
    });
  }
}

// COMPLIANCE TODO: real-money IRL Dunking mode is legal-review-gated — DO NOT ship live without sign-off

export default DunkingMode;
