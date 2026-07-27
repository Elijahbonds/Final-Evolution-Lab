// AdaptiveQuality — hold 60fps by shedding the right things, in the right
// order, and never a tell.
//
// THE BAR
// `docs/BLUEPRINT.md` §7 requires 60fps held for a three-minute session with no
// frame over 50ms. FEL runs in a browser on phones ranging from a current
// flagship to a four-year-old mid-range Android, and no fixed quality setting
// is right for both. So quality has to move.
//
// THE RULE THAT MAKES THIS PART OF PHASE 9 RATHER THAN A GRAPHICS SETTING
//
//     A TELL IS NEVER SHED.
//
// `Legibility.ts` separates effects that are decoration from tells that carry
// a mechanic. A naive quality scaler kills particles, then post-processing,
// then "minor overlays" — and somewhere in that list is the ground marker that
// showed which way the defender committed. The player's frame rate improves
// and a mechanic silently disappears. They do not experience a lower graphics
// setting; they experience a game that became random.
//
// That is the same failure this ten-phase pass has found five times in
// different clothes: something looks fine, runs fine, and quietly does
// nothing. Here it would be self-inflicted, so the order is declared as data
// and asserted by test.
//
// WHY DROP QUALITY RATHER THAN FRAMES
// A dropped frame is a missed input. M81 set a 66ms input-to-response budget;
// at 30fps a single frame is 33ms, so two bad frames blow it. Every mechanic
// in phases 2-8 assumes the player can react — spacing, whiff punish, pitch
// recognition, section timing. Frame rate is not a graphics concern in this
// product, it is a gameplay one.

/** Rendering work that may be reduced. Ordered by what it costs to lose. */
export type QualityLayer =
  | 'ambient_particles'    // crowd, dust, spray — pure atmosphere
  | 'post_bloom'
  | 'shadow_resolution'
  | 'reflections'
  | 'crowd_density'
  | 'impact_particles'     // hit sparks — feel, not information
  | 'venue_detail'
  | 'character_lod'
  | 'render_scale';        // last resort: fewer pixels

/**
 * The shed order.
 *
 * First entries go first. Atmosphere before anything a player reads, and
 * `render_scale` last because a soft image is worse than a plain one but far
 * better than a slow one.
 *
 * NOTE WHAT IS ABSENT: no tell layer appears here at all. That is not an
 * oversight to be corrected later; it is the point, and `SHEDDABLE` is
 * exhaustive by construction.
 */
export const SHED_ORDER: QualityLayer[] = [
  'ambient_particles',
  'post_bloom',
  'reflections',
  'crowd_density',
  'shadow_resolution',
  'venue_detail',
  'impact_particles',
  'character_lod',
  'render_scale',
];

/** Everything that may ever be reduced. Anything not here is protected. */
export const SHEDDABLE = new Set<QualityLayer>(SHED_ORDER);

export class ProtectedLayerError extends Error {}

/**
 * Refuse to shed something that carries information.
 *
 * A throwing guard rather than a comment, for the same reason
 * `assertCosmetic` and `assertNotPayToWin` are: the pressure to add "just the
 * ground markers" to the shed list will be real on the day someone is chasing
 * a frame budget on a cheap phone, and that is exactly when the decision needs
 * to already have been made.
 */
export function assertSheddable(layer: string): asserts layer is QualityLayer {
  if (!SHEDDABLE.has(layer as QualityLayer)) {
    throw new ProtectedLayerError(
      `"${layer}" is not a sheddable layer. If it is a TELL, it carries a mechanic and `
      + 'removing it does not lower quality — it removes the mechanic, and the player '
      + 'experiences a game that became random rather than one that looks simpler.',
    );
  }
}

export interface QualityState {
  /** How many layers have been shed. 0 is full quality. */
  level: number;
  /** Currently disabled. */
  shed: QualityLayer[];
  /** 0.5–1. Backing-buffer scale. */
  renderScale: number;
}

export const FULL_QUALITY: QualityState = { level: 0, shed: [], renderScale: 1 };

/** Target frame time. 16.67ms is 60fps. */
export const TARGET_MS = 1000 / 60;
/** Sustained above this and we shed. 18ms is ~55fps — a real drop, not jitter. */
export const SHED_THRESHOLD_MS = 18;
/** Sustained below this and we restore. Hysteresis, so quality does not
 *  oscillate visibly on a borderline device. */
export const RESTORE_THRESHOLD_MS = 14;
/** Frames of evidence before acting. About a third of a second. */
export const EVIDENCE_FRAMES = 20;

/**
 * Watches frame times and moves quality.
 *
 * Median rather than mean: one 200ms GC pause should not trigger a quality
 * drop, and a mean is dragged around by exactly those outliers. What matters
 * is whether the TYPICAL frame is late.
 */
export class QualityGovernor {
  private frames: number[] = [];
  private state: QualityState = { ...FULL_QUALITY, shed: [] };
  private cooldown = 0;

  /** Changes made, for reporting what a device actually needed. */
  public readonly history: Array<{ at: number; action: 'shed' | 'restore'; layer: QualityLayer }> = [];

  get current(): QualityState { return this.state; }

  /** Feed one frame time in ms. Returns a change, or null. */
  sample(frameMs: number, now = Date.now()): { action: 'shed' | 'restore'; layer: QualityLayer } | null {
    if (!Number.isFinite(frameMs) || frameMs <= 0) return null;
    this.frames.push(frameMs);
    if (this.frames.length > EVIDENCE_FRAMES) this.frames.shift();
    if (this.frames.length < EVIDENCE_FRAMES) return null;
    if (this.cooldown > 0) { this.cooldown--; return null; }

    const median = [...this.frames].sort((a, b) => a - b)[Math.floor(this.frames.length / 2)];

    if (median > SHED_THRESHOLD_MS && this.state.level < SHED_ORDER.length) {
      const layer = SHED_ORDER[this.state.level];
      this.state = {
        level: this.state.level + 1,
        shed: [...this.state.shed, layer],
        renderScale: layer === 'render_scale' ? 0.75 : this.state.renderScale,
      };
      this.cooldown = EVIDENCE_FRAMES;
      const change = { action: 'shed' as const, layer };
      this.history.push({ at: now, ...change });
      return change;
    }

    if (median < RESTORE_THRESHOLD_MS && this.state.level > 0) {
      const layer = SHED_ORDER[this.state.level - 1];
      this.state = {
        level: this.state.level - 1,
        shed: this.state.shed.slice(0, -1),
        renderScale: layer === 'render_scale' ? 1 : this.state.renderScale,
      };
      this.cooldown = EVIDENCE_FRAMES * 3;      // restore cautiously
      const change = { action: 'restore' as const, layer };
      this.history.push({ at: now, ...change });
      return change;
    }
    return null;
  }

  isShed(layer: QualityLayer): boolean { return this.state.shed.includes(layer); }

  reset(): void {
    this.frames = [];
    this.state = { ...FULL_QUALITY, shed: [] };
    this.cooldown = 0;
  }

  /**
   * What this device actually needed. For telemetry, and for telling a player
   * something true instead of leaving them to conclude the game is bad.
   */
  get verdict(): { comfortable: boolean; note: string } {
    if (this.state.level === 0) {
      return { comfortable: true, note: 'Held 60fps at full quality.' };
    }
    if (this.state.level >= SHED_ORDER.length) {
      return {
        comfortable: false,
        note: 'Everything sheddable is off and frames are still late. This device cannot hold '
          + '60fps in this mode — and below 60 the reaction-based mechanics stop being fair.',
      };
    }
    return {
      comfortable: true,
      note: `Holding 60fps with ${this.state.level} effect layer(s) reduced.`,
    };
  }
}

// ── juice, gated ─────────────────────────────────────────────────────────

/**
 * The a11y gate that `core/gameFeel.ts` never got.
 *
 * `gameFeel` (M26) predates M82's accessibility layer, so `Shaker.kick()`
 * shakes the camera and `haptic()` vibrates the phone regardless of what the
 * player asked for. `reducedMotion` is honoured by the HUD's CSS and ignored by
 * the thing that actually moves the camera — which is the one that makes
 * people ill.
 *
 * These wrap the existing calls rather than replacing them, so the fix is a
 * call-site change rather than a rewrite of a file every mode depends on.
 */
export interface FeelSettings {
  reducedMotion: boolean;
  noFlashing: boolean;
  /** Some players want the shake and not the buzz. */
  hapticsEnabled: boolean;
}

export const DEFAULT_FEEL: FeelSettings = {
  reducedMotion: false, noFlashing: false, hapticsEnabled: true,
};

/** Shake amplitude after accessibility. Zero under reduced motion. */
export function gatedShake(strength: number, s: FeelSettings): number {
  return s.reducedMotion ? 0 : Math.max(0, Math.min(1, strength));
}

/**
 * Hit-stop duration after accessibility.
 *
 * Reduced motion does NOT remove hit-stop — it is a pause, not movement, and
 * it carries impact information without moving anything. Blanket-disabling
 * everything under one flag is how accessibility settings end up feeling like
 * a punishment. It is shortened rather than removed.
 */
export function gatedHitStop(ms: number, s: FeelSettings): number {
  const capped = Math.min(ms, 120);
  return s.reducedMotion ? Math.min(capped, 40) : capped;
}

/** Haptic pattern after accessibility, or null. */
export function gatedHaptic(pattern: number[] | null, s: FeelSettings): number[] | null {
  if (!pattern || !s.hapticsEnabled) return null;
  return pattern;
}

/**
 * Should this flash be shown, and at what intensity?
 *
 * Above 3Hz is the documented photosensitive-seizure threshold. This is the
 * one presentation decision where being wrong can hurt somebody, so it is a
 * hard gate rather than a scale — same as M82's `allowFlash`.
 */
export function gatedFlash(hz: number, intensity: number, s: FeelSettings): number {
  if (s.noFlashing || hz > 3) return 0;
  return s.reducedMotion ? Math.min(intensity, 0.3) : intensity;
}

/**
 * The full impact bundle, gated.
 *
 * A drop-in for `gameFeel.impact()`. Returns what to do rather than doing it,
 * so it is testable without a scene — which is what let the missing gate be
 * caught by a test instead of by a player feeling sick.
 */
export function impactPlan(
  strength: number, s: FeelSettings = DEFAULT_FEEL,
): { hitStopMs: number; shake: number; haptic: number[] | null; flash: number } {
  return {
    hitStopMs: gatedHitStop(30 + strength * 50, s),
    shake: gatedShake(strength, s),
    haptic: gatedHaptic([Math.round(8 + strength * 22)], s),
    flash: gatedFlash(1, strength * 0.5, s),
  };
}
