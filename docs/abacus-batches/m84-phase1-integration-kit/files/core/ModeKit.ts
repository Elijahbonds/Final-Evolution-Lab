// ModeKit — five subsystems, one object, twenty lines per mode.
//
// WHY THIS EXISTS, IN NUMBERS
// M81–M83 shipped five things every mode needs: SimLoop (deterministic ticks),
// MotionModel (movement that feels controlled), DDA (PRQ as an input), a11y
// (assist, reduced motion), captions. Wired by hand that is five integrations
// × 25 modes = 125 chances to get it wrong, and the evidence says a meaningful
// share of them simply would not happen: M69 shipped `groundSnap` and
// `CameraStandoff` together, `groundSnap` runs in production and
// `CameraStandoff` shows no sign of ever having run. Nobody noticed for six
// batches.
//
// So the unit of integration is one object, not five. A mode calls
// `ModeKit.create()`, `kit.frame()`, `kit.move()`, `kit.window()` and
// `kit.finish()`. That is the whole surface.
//
// DESIGN CONSTRAINT WORTH STATING: THIS FILE IMPORTS NO BABYLON.
// It takes plain numbers and returns plain numbers. That is not tidiness — it
// is what makes the integration layer itself testable, and the integration
// layer is precisely where this project keeps losing work. A wiring harness
// nobody can test is how you get a `CameraStandoff`.

import { SimLoop } from './SimLoop';
import { FIXED_DT } from './FixedStep';
import { step as motionStep, DEFAULT_MOTION, NEUTRAL_MOTION, type MotionState, type MotionConfig } from './MotionModel';
import { PRQDrivenDDA, loadDDA } from './DDA';
import { a11y, finalWindow, shakeAmount, allowFlash, assistReactionBonus, type A11ySettings } from './a11y';
import { captions, type CueImportance } from './captions';
import { prqWeight, estimatePrqDelta } from './prqWeights';
import type { Intent } from './PlayerSlot';
import type { ReplayData } from './Replay';

export interface ModeKitOptions {
  modeId: string;
  /** Record this run as a ghost. Off by default. */
  record?: boolean;
  /** Replay conditions from a ghost: pass its seed AND its recorded PRQ. */
  seed?: number;
  /** Dev: capture a per-tick fingerprint for verifyDeterminism(). */
  captureHashes?: boolean;
  /** Per-mode movement overrides. Most modes should not need any. */
  motion?: Partial<MotionConfig>;
  /** Injected for tests. */
  fetchImpl?: typeof fetch;
}

/**
 * Everything a mode needs from the shared layers.
 *
 * Constructed via `ModeKit.create()` because DDA has to be fetched, and a
 * constructor that cannot await would either block or lie about being ready.
 */
export class ModeKit {
  readonly modeId: string;
  readonly sim: SimLoop;
  readonly dda: PRQDrivenDDA;
  readonly motionConfig: MotionConfig;
  /** Movement state. Advanced by `move()`, read by the renderer. */
  motion: MotionState = NEUTRAL_MOTION;

  private startedAtTick = 0;
  private unsubA11y: () => void;
  private settings: A11ySettings;

  private constructor(opts: ModeKitOptions, dda: PRQDrivenDDA) {
    this.modeId = opts.modeId;
    this.dda = dda;
    this.motionConfig = { ...DEFAULT_MOTION, ...(opts.motion ?? {}) };
    this.sim = new SimLoop({
      modeId: opts.modeId,
      seed: opts.seed,
      playerPRQ: dda.playerPRQ,
      record: opts.record,
      captureHashes: opts.captureHashes,
    });
    this.settings = a11y.get();
    // Live, because an accessibility change must apply without restarting the
    // mode. A settings screen that requires a restart is one people give up on.
    this.unsubA11y = a11y.subscribe((s) => { this.settings = s; captions.setEnabled(s.captions); });
    captions.setEnabled(this.settings.captions);
  }

  /**
   * Build a kit. Never throws, never blocks on the network.
   *
   * A guest with no account, or a player who is offline, gets a match at
   * neutral difficulty rather than a spinner. `loadDDA` already guarantees
   * that; this just makes it the only path.
   */
  static async create(opts: ModeKitOptions): Promise<ModeKit> {
    const dda = await loadDDA(opts.modeId, opts.fetchImpl ?? (typeof fetch !== 'undefined' ? fetch : undefined as never));
    return new ModeKit(opts, dda);
  }

  /** Synchronous construction at neutral difficulty — for tests and for a
   *  mode that genuinely cannot await. */
  static neutral(opts: ModeKitOptions): ModeKit {
    return new ModeKit(opts, PRQDrivenDDA.neutral(opts.modeId));
  }

  // ── the render loop ────────────────────────────────────────────────────

  /**
   * Call once per rendered frame with the raw frame time.
   *
   * `tickFn` always receives 1/60. If a mode reaches past this for
   * `engine.getDeltaTime()` it reintroduces every problem M83 removed, and the
   * symptom — a ghost that drifts — appears nowhere near the cause.
   */
  frame(
    frameSec: number,
    tickFn: (dt: number, tick: number) => void,
    intentFn?: () => Intent,
    stateFn?: () => number[],
  ): number {
    return this.sim.frame(frameSec, tickFn, intentFn, stateFn);
  }

  /** 0..1 through the next tick. For interpolating the RENDER only. */
  get alpha(): number { return this.sim.alpha; }
  get tick(): number { return this.sim.tick; }
  get simTime(): number { return this.sim.simTime; }

  // ── movement ───────────────────────────────────────────────────────────

  /**
   * Advance movement one tick and return the new state.
   *
   * Note `sprint` comes from the intent, which comes from an explicit button.
   * If a caller passes `sprint: Math.hypot(moveX, moveY) > 0.85` it has
   * reintroduced the always-sprinting bug that M81 exists to kill — there is a
   * test asserting a full-deflection walk is not a sprint.
   */
  move(intent: Intent, cameraYawDeg: number, grounded = true): MotionState {
    this.motion = motionStep(this.motion, {
      x: intent.moveX,
      y: intent.moveY,
      sprint: intent.sprint,
      jumpPressed: intent.action,
      grounded,
      cameraYawDeg,
    }, FIXED_DT, this.motionConfig);
    return this.motion;
  }

  /** World displacement for this tick, given a top speed in m/s. */
  velocity(topSpeed: number): { x: number; z: number } {
    const v = this.motion.speed * topSpeed * FIXED_DT;
    return { x: this.motion.dirX * v, z: this.motion.dirZ * v };
  }

  /** Facing in radians, for a Babylon `rotation.y`. */
  get facingRad(): number { return (this.motion.facingDeg * Math.PI) / 180; }

  // ── difficulty and assist, composed ────────────────────────────────────

  /**
   * A timing window in ms, after BOTH the game's catch-up scaling and the
   * player's accessibility assist.
   *
   * One call, so the two can never be applied in the wrong order or one of
   * them forgotten. Every mode with a timing window should use this and keep
   * no raw constant of its own.
   */
  window(baseMs: number, playerScore = 0, aiScore = 0, targetScore = 10): number {
    return finalWindow(baseMs, this.dda.qteWindowScale(playerScore, aiScore, targetScore), this.settings);
  }

  /** AI reaction delay in seconds, after PRQ and the assist allowance. */
  reactionDelay(playerScore = 0, aiScore = 0): number {
    return this.dda.aiReactionSpeed(playerScore, aiScore) + assistReactionBonus(this.settings.assist);
  }

  /** Camera shake amplitude — zero under reduced motion. */
  shake(base: number): number { return shakeAmount(base, this.settings); }

  /** May a flash at this rate be shown? Above 3Hz is a seizure risk. */
  flash(hz: number): boolean { return allowFlash(hz, this.settings); }

  // ── captions ───────────────────────────────────────────────────────────

  /** Show a caption. No-op when captions are off, so call sites never branch. */
  cue(text: string, importance: CueImportance = 'feedback'): void {
    captions.cue(text, importance);
  }

  /** Play a sound and caption it together. The caption is required. */
  sound(play: () => void, caption: string, importance: CueImportance = 'feedback'): void {
    play();
    captions.cue(caption, importance);
  }

  /** Expire captions. Call from the mode's per-tick update. */
  tickCaptions(): void { captions.tick(); }

  // ── scoring ────────────────────────────────────────────────────────────

  /** What this mode's sessions are worth. 0 means it must never mint PRQ. */
  get prqWeight(): number { return prqWeight(this.modeId); }

  /** Live PRQ estimate, so the HUD can be honest before the receipt returns. */
  estimatedPrq(score: number, completed = false): number {
    return estimatePrqDelta(this.modeId, score, this.sim.simTime, completed);
  }

  /**
   * Close out. Returns the ghost recording if one was made.
   *
   * Safe to call more than once — a mode that ends on both a timer and a score
   * condition would otherwise double-report, which is a real bug pattern in
   * this codebase.
   */
  private finished = false;
  finish(score: number, outcome: string): ReplayData | null {
    if (this.finished) return null;
    this.finished = true;
    return this.sim.finish(score, outcome);
  }

  dispose(): void {
    this.unsubA11y();
    captions.clear();
  }
}

/**
 * The checklist a migrated mode satisfies.
 *
 * Exported and asserted by tests rather than written in a README, because a
 * README is what `CameraStandoff` had. `tools/integration_audit.mjs` reports
 * these against the deployed build.
 */
export const MIGRATION_MARKERS = [
  'kit.frame',        // deterministic ticks, not engine.getDeltaTime()
  'kit.move',         // MotionModel, not raw intent→position
  'kit.window',       // DDA + assist, not a raw timing constant
  'kit.sound',        // captioned audio, not bare play()
  'kit.finish',       // one exit path
] as const;
