import { createSharedSystems } from '../../systems/index.js';
import { ArcDrive } from '../../systems/ArcDrive.js';
import { feelConfig } from '../../systems/feelConfig.js';
import { InputBuffer } from '../../systems/InputBuffer.js';
import { StateMachine } from '../../systems/StateMachine.js';
import { FixedStepLoop } from '../../core/FixedStepLoop.js';
import { InputSystem } from '../../input/InputSystem.js';
import { GameModeInterface, ModePhase } from '../GameModeInterface.js';
import DunkingScene from './DunkingScene.js';

/** Dunk movement phases (feel spec: buffered inputs fire the next state
 *  immediately — no waiting on animation end). */
export const DunkPhase = Object.freeze({
  IDLE:     'Idle',
  APPROACH: 'Approach',
  JUMPPREP: 'JumpPrep',
  ASCENT:   'Ascent',
  PEAK:     'Peak',
  DESCENT:  'Descent',
  CONTACT:  'Contact',
  LANDING:  'Landing',
});

function clampValue(v, min, max) { return v < min ? min : v > max ? max : v; }

/** Move `current` toward `target` by at most `maxDelta` (no allocation). */
function approach(current, target, maxDelta) {
  const diff = target - current;
  if (diff > maxDelta) return current + maxDelta;
  if (diff < -maxDelta) return current - maxDelta;
  return target;
}

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

    // Guards the async start() against dispose() racing it (React StrictMode
    // double-mount: cleanup can run while scene init is still awaiting).
    this._disposed = false;

    // Fixed-timestep simulation state (preallocated — never allocate in tick)
    this._loop = null;
    this._rafId = null;
    this._lastRafTs = 0;
    this._prevPos = { x: 0, y: 0, z: 0 };
    this._renderPos = { x: 0, y: 0, z: 0 };
    this._verticalVelocity = 0;

    // Buffered input (feel DoD: jump fires within 1 physics step, always)
    this._inputBuffer = new InputBuffer({ windowMs: feelConfig.input.bufferMs });

    // Hybrid anim↔physics arc drive for the dunk itself (commit 4)
    this._arcDrive = new ArcDrive();
    this._arcTarget = { x: 0, y: 0, z: 0 };
    this._drivenDunk = null; // { variant, modifier } while an arc is driving

    // Movement FSM: Idle→Approach→JumpPrep→Ascent→Peak→Descent→Contact→Landing
    this._fsm = this._createMovementFsm();

    // Charge state (mirrors iOS styleTriggerHeld / powerTriggerHeld)
    this._styleCharge  = 0; // 0–1 from L2
    this._powerCharge  = 0; // 0–1 from R2
    this._chargeStartAt = null;
    this._isMidAir     = false;
    this._pendingDunkVariant = null;

    this.state = this._createInitialState();
  }

  /**
   * Movement FSM. Transition RULES live in _fixedUpdate (mode logic);
   * states carry enter effects only — shared StateMachine stays generic.
   * @private
   */
  _createMovementFsm() {
    const noop = {};
    return new StateMachine({
      initial: DunkPhase.IDLE,
      states: {
        [DunkPhase.IDLE]:     noop,
        [DunkPhase.APPROACH]: noop,
        [DunkPhase.JUMPPREP]: noop,
        [DunkPhase.ASCENT]: {
          enter: () => {
            this._isMidAir = true;
            this.systems?.audio?.playEvent('jump');
            this.systems?.vfx?.trigger('light_impact');
            this.state.prq = this.systems?.prqSystem?.recordEvent({ type: 'hit', quality: 'good' }) ?? this.state.prq;
          },
        },
        [DunkPhase.PEAK]:    noop,
        [DunkPhase.DESCENT]: noop,
        [DunkPhase.CONTACT]: {
          enter: () => { this._isMidAir = false; },
        },
        [DunkPhase.LANDING]: noop,
      },
    });
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
    this._disposed = false;

    this.container = container ?? this.container;
    this.systems   = createSharedSystems(this.container);

    // Alias for backwards compat
    this.systems.scoreSystem   = this.systems.score;
    this.systems.comboSystem   = this.systems.combo;
    this.systems.prqSystem     = this.systems.prq;
    this.systems.hudStateSystem = this.systems.hudState;

    this.scene = new DunkingScene(this.canvas, this.systems);
    await this.scene.init();

    // Disposed while init was awaiting (StrictMode remount) — tear down the
    // zombie scene and bail; the replacement mode owns the canvas now.
    if (this._disposed) {
      this.scene.dispose();
      this.scene = null;
      return this.getState();
    }

    // Wire input system for virtual gamepad
    this.input = new InputSystem(this.getModeId());
    this.input.onEvent = (ev) => this.update(ev);

    this.playerPosition = { x: 0, y: 0, z: 0 };
    this._verticalVelocity = 0;
    this._inputBuffer.clear();
    this._arcDrive.cancel();
    this._drivenDunk = null;
    this._fsm.transition(DunkPhase.IDLE);
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

    // ── Fixed-timestep simulation, decoupled from render ────────────────────
    this._loop = new FixedStepLoop({
      hz: feelConfig.timestepHz,
      maxAccumulatedMs: feelConfig.maxAccumulatedMs,
      update: (dt) => this._fixedUpdate(dt),
      render: (alpha) => this._renderInterpolate(alpha),
    });
    this._loop.start();
    if (this.scene && !this.scene.isFallback && this.scene.setFrameCallback) {
      // Babylon render loop drives the simulation clock.
      this.scene.setFrameCallback((dtMs) => this._loop.tick(dtMs));
    } else {
      this._startFallbackDriver();
    }

    return this.getState();
  }

  /**
   * One fixed simulation step (feelConfig.timestepHz). Reads the HELD left
   * stick state and integrates velocity → position. Allocates nothing.
   * @private
   */
  _fixedUpdate(dt) {
    if (this.state.phase !== ModePhase.ACTIVE) return;

    const stick = this.input ? this.input.leftStick : null;
    const sx = stick ? stick.x : 0;
    const sy = stick ? stick.y : 0;
    const held = stick && stick.magnitude > 0.05;

    const cfg = feelConfig.movement;
    const rate = (held ? cfg.accel : cfg.decel) * dt;
    this.playerVelocity.x = approach(this.playerVelocity.x, sx * cfg.runSpeed, rate);
    this.playerVelocity.z = approach(this.playerVelocity.z, -sy * cfg.runSpeed, rate);

    this._prevPos.x = this.playerPosition.x;
    this._prevPos.y = this.playerPosition.y;
    this._prevPos.z = this.playerPosition.z;

    const b = feelConfig.court;
    this.playerPosition.x = clampValue(this.playerPosition.x + this.playerVelocity.x * dt, b.minX, b.maxX);
    this.playerPosition.z = clampValue(this.playerPosition.z + this.playerVelocity.z * dt, b.minZ, b.maxZ);

    this._updateJumpPhase(dt);
    this._fsm.update(dt);
  }

  /**
   * Mid-air dunk lock-on: begins the hybrid arc drive when the player is
   * airborne within lock-on radius of the hoop. Returns false → caller
   * falls through to the immediate (grounded/out-of-range) dunk attempt.
   * @private
   */
  _tryBeginDunkDrive(variant, modifier) {
    if (this._arcDrive.active || !this._isMidAir) return false;
    const cfg = feelConfig.dunkArc;
    if (distanceToHoop(this.playerPosition) > cfg.lockOnRadius) return false;

    // Rim approach point: just in front of the rim center, slam height.
    const dx = this.playerPosition.x - HOOP_POSITION.x;
    const dz = this.playerPosition.z - HOOP_POSITION.z;
    const len = Math.sqrt(dx * dx + dz * dz) || 1;
    this._arcTarget.x = HOOP_POSITION.x + (dx / len) * cfg.rimStandoff;
    this._arcTarget.z = HOOP_POSITION.z + (dz / len) * cfg.rimStandoff;
    this._arcTarget.y = cfg.rimApproachY;

    this._arcDrive.begin({
      start: this.playerPosition,
      target: this._arcTarget,
      apexY: Math.max(this.playerPosition.y, cfg.rimApproachY) + cfg.apexBoostM,
      durationMs: cfg.durationMs,
    });
    this._drivenDunk = { variant, modifier };
    this.scene?.triggerDunkCameraSequence?.();
    return true;
  }

  /**
   * Vertical physics + movement-phase transitions. Runs once per fixed step.
   * @private
   */
  _updateJumpPhase(dt) {
    // ── Arc drive owns the body while active (hybrid blend) ────────────────
    if (this._arcDrive.active) {
      this._prevPos.x = this.playerPosition.x;
      this._prevPos.y = this.playerPosition.y;
      this._prevPos.z = this.playerPosition.z;
      const done = this._arcDrive.advance(dt, this.playerPosition);
      // Phase readout follows the arc's vertical motion (HUD/anim selector).
      const vyApprox = (this.playerPosition.y - this._prevPos.y) / dt;
      const g = feelConfig.gravity;
      if (vyApprox > g.peakVelocityWindow) this._fsm.transition(DunkPhase.ASCENT);
      else if (vyApprox >= -g.peakVelocityWindow) this._fsm.transition(DunkPhase.PEAK);
      else this._fsm.transition(DunkPhase.DESCENT);

      if (done) {
        // Rim contact: score, then hand control back to physics with
        // velocity continuity — position AND vy are continuous, no jerk.
        const dunk = this._drivenDunk;
        this._drivenDunk = null;
        this._verticalVelocity = this._arcDrive.endVerticalVelocity();
        if (dunk) this._executeDunk(dunk.variant, dunk.modifier, { nearHoop: true });
        this._fsm.transition(DunkPhase.DESCENT);
      }
      return;
    }
    this._updateFreePhase(dt);
  }

  /**
   * Free (non-driven) vertical physics + phase transitions.
   * @private
   */
  _updateFreePhase(dt) {
    const fsm = this._fsm;
    const jump = feelConfig.jump;
    const g = feelConfig.gravity;

    switch (fsm.current) {
      case DunkPhase.IDLE:
      case DunkPhase.APPROACH: {
        // Buffered jump fires within one physics step of being legal.
        if (this._inputBuffer.consume('jump')) {
          fsm.transition(DunkPhase.JUMPPREP);
          break;
        }
        const speedSq =
          this.playerVelocity.x * this.playerVelocity.x +
          this.playerVelocity.z * this.playerVelocity.z;
        const approaching = speedSq >= jump.approachSpeed * jump.approachSpeed;
        fsm.transition(approaching ? DunkPhase.APPROACH : DunkPhase.IDLE);
        break;
      }

      case DunkPhase.JUMPPREP: {
        if (fsm.timeInState * 1000 >= jump.prepMs) {
          this._verticalVelocity = jump.impulse;
          fsm.transition(DunkPhase.ASCENT);
        }
        break;
      }

      case DunkPhase.ASCENT:
      case DunkPhase.PEAK:
      case DunkPhase.DESCENT: {
        this._verticalVelocity -= g.base * this._gravityScale() * dt;
        this.playerPosition.y += this._verticalVelocity * dt;

        if (this.playerPosition.y <= 0 && this._verticalVelocity < 0) {
          // Landing snap: ground contact resolves on this step exactly.
          this.playerPosition.y = 0;
          this._verticalVelocity = 0;
          fsm.transition(DunkPhase.CONTACT);
        } else if (this._verticalVelocity > g.peakVelocityWindow) {
          fsm.transition(DunkPhase.ASCENT);
        } else if (this._verticalVelocity >= -g.peakVelocityWindow) {
          fsm.transition(DunkPhase.PEAK);
        } else {
          fsm.transition(DunkPhase.DESCENT);
        }
        break;
      }

      case DunkPhase.CONTACT: {
        // Consume here too — a jump buffered just before touchdown fires on
        // the very step the ground is reached, not one step later.
        if (this._inputBuffer.consume('jump')) {
          fsm.transition(DunkPhase.JUMPPREP);
        } else {
          fsm.transition(DunkPhase.LANDING);
        }
        break;
      }

      case DunkPhase.LANDING: {
        // Buffered jump cancels recovery — no waiting on animation end.
        if (this._inputBuffer.consume('jump')) {
          fsm.transition(DunkPhase.JUMPPREP);
        } else if (fsm.timeInState * 1000 >= jump.landingMs) {
          fsm.transition(DunkPhase.IDLE);
        }
        break;
      }

      default:
        break;
    }
  }

  /**
   * Velocity-driven gravity curve (the anti-floaty fix): ascent is light,
   * the peak hangs, the descent slams down. Values live in feelConfig so
   * every mode tunes the same knobs.
   * @private
   */
  _gravityScale() {
    const g = feelConfig.gravity;
    if (this._verticalVelocity > g.peakVelocityWindow) return g.ascentScale;
    if (this._verticalVelocity >= -g.peakVelocityWindow) return g.peakScale;
    return g.descentScale;
  }

  /**
   * Render-rate interpolation between the previous and current fixed steps.
   * @private
   */
  _renderInterpolate(alpha) {
    const p = this._prevPos;
    const c = this.playerPosition;
    const r = this._renderPos;
    r.x = p.x + (c.x - p.x) * alpha;
    r.y = p.y + (c.y - p.y) * alpha;
    r.z = p.z + (c.z - p.z) * alpha;
    if (this.scene && this.scene.updatePlayerTransform) this.scene.updatePlayerTransform(r);
  }

  /**
   * Drives the loop with requestAnimationFrame when no Babylon render loop
   * exists (fallback scene / headless-ish environments).
   * @private
   */
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

    // Movement no longer steps position per event: the fixed-timestep loop
    // reads the HELD stick state each step in _fixedUpdate (feel DoD —
    // frame-rate-independent arcs). payload.position above remains the
    // headless/test driver seam.

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

    // ── Jump (✕ button) — buffered; the FSM fires it the moment it's legal
    if (type === 'jump') {
      this._inputBuffer.press('jump');
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
      if (this._tryBeginDunkDrive(variant, payload.modifier)) {
        // Mid-air lock-on: the arc carries the player to the rim; scoring
        // fires at rim contact in _fixedUpdate.
      } else {
        this._executeDunk(variant, payload.modifier, payload);
      }
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
      // Movement FSM phase + jump height (HUD/tests/anim selector)
      dunkPhase:     this._fsm.current,
      jumpHeight:    this.playerPosition.y,
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
    this._disposed = true;
    if (this.matchTimer) { clearInterval(this.matchTimer); this.matchTimer = null; }
    if (this._loop) { this._loop.stop(); this._loop = null; }
    if (this._rafId !== null && typeof window !== 'undefined') {
      window.cancelAnimationFrame(this._rafId);
      this._rafId = null;
    }
    this.scene?.setFrameCallback?.(null);
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
    this._verticalVelocity = 0;
    this._inputBuffer.clear();
    this._arcDrive.cancel();
    this._drivenDunk = null;
    this._fsm.transition(DunkPhase.IDLE);
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
