// a11y — accessibility as a layer, not as twenty-five retrofits.
//
// Current coverage across the whole product is ONE line about text contrast in
// a distribution doc. No reduced motion, no remapping, no captions, no
// colourblind support, no assist — in a product whose premise is athletic
// identity for everyone.
//
// This lives in core/ and is read by ModeHarness and InputBus, so it lands
// once across every mode. Retrofitting captions and remapping into 25 modes
// individually costs several times what building them into the harness does,
// and it is the kind of cost that only ever goes up.
//
// TWO DESIGN DECISIONS WORTH STATING
//
// 1. THE ASSIST SLIDER IS THE SAME MACHINERY AS DDA. `qteWindowScale` in
//    DDA.ts already widens timing windows when a player is losing. An
//    accessibility assist widens them because the player asked. Same
//    multiplier, different reason — so it is built once and exposed twice.
//    Anything else would mean two systems fighting over the same number.
//
// 2. OS PREFERENCES ARE DEFAULTS, NOT LOCKS. `prefers-reduced-motion` seeds
//    the setting; the player can still override it per-session. Someone who
//    turned it on system-wide for scrolling may still want camera shake in a
//    dunk contest, and refusing them that is paternalism dressed as
//    accessibility.

export type AssistLevel = 'off' | 'light' | 'standard' | 'full';
export type ColorMode = 'default' | 'deuteranopia' | 'protanopia' | 'tritanopia' | 'high-contrast';

export interface A11ySettings {
  /** Cut camera shake, screen flash, particle bursts. */
  reducedMotion: boolean;
  /** Visual equivalent for every gameplay-relevant sound. */
  captions: boolean;
  /** Widens every timing window. See assistWindowScale(). */
  assist: AssistLevel;
  /** Palette substitution. */
  colorMode: ColorMode;
  /** Hold-to-charge becomes press-to-start / press-to-release. */
  holdToToggle: boolean;
  /** Mirror the touch overlay for one-handed play. */
  mirrorControls: boolean;
  /** Compact overlay so both controls sit within one thumb's reach. */
  oneHanded: boolean;
  /** HUD text scale, 1.0-2.0. */
  textScale: number;
  /** Key → button overrides for InputBus. */
  bindings: Record<string, string>;
  /** Suppress flashing beyond 3Hz. Independent of reducedMotion: photo-
   *  sensitive epilepsy is a seizure risk, motion sickness is not. */
  noFlashing: boolean;
}

export const DEFAULT_A11Y: A11ySettings = {
  reducedMotion: false,
  captions: false,
  assist: 'off',
  colorMode: 'default',
  holdToToggle: false,
  mirrorControls: false,
  oneHanded: false,
  textScale: 1,
  bindings: {},
  noFlashing: false,
};

const STORAGE_KEY = 'fel.a11y.v1';

/**
 * Timing-window multiplier for an assist level.
 *
 * Multiplies with DDA's own scale rather than replacing it, so a struggling
 * player on full assist gets both. `full` at 1.6× makes a 100ms window 160ms
 * — generous enough to matter to someone with a motor impairment, not so
 * generous that the game plays itself. There is a difference and it is worth
 * respecting.
 */
export function assistWindowScale(level: AssistLevel): number {
  switch (level) {
    case 'off': return 1.0;
    case 'light': return 1.2;
    case 'standard': return 1.4;
    case 'full': return 1.6;
  }
}

/**
 * Reaction-time allowance, in seconds, added to any AI reaction delay.
 *
 * Widening a window helps you hit a beat. It does nothing about an opponent
 * who acts before you can perceive them — that needs its own dial.
 */
export function assistReactionBonus(level: AssistLevel): number {
  switch (level) {
    case 'off': return 0;
    case 'light': return 0.1;
    case 'standard': return 0.2;
    case 'full': return 0.35;
  }
}

/** Read the OS's stated preferences. Defaults only — never a lock. */
export function osPreferences(): Partial<A11ySettings> {
  if (typeof window === 'undefined' || !window.matchMedia) return {};
  const out: Partial<A11ySettings> = {};
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    out.reducedMotion = true;
    // Someone who asked for less motion has usually asked because motion makes
    // them ill; flashing is the same family of harm.
    out.noFlashing = true;
  }
  if (window.matchMedia('(prefers-contrast: more)').matches) out.colorMode = 'high-contrast';
  return out;
}

/** Clamp anything out of range rather than trusting stored JSON. */
export function normalise(s: Partial<A11ySettings>): A11ySettings {
  const merged = { ...DEFAULT_A11Y, ...s };
  const levels: AssistLevel[] = ['off', 'light', 'standard', 'full'];
  const modes: ColorMode[] = ['default', 'deuteranopia', 'protanopia', 'tritanopia', 'high-contrast'];
  return {
    ...merged,
    assist: levels.includes(merged.assist) ? merged.assist : 'off',
    colorMode: modes.includes(merged.colorMode) ? merged.colorMode : 'default',
    textScale: Math.min(2, Math.max(1, Number(merged.textScale) || 1)),
    bindings: typeof merged.bindings === 'object' && merged.bindings ? merged.bindings : {},
  };
}

type Listener = (s: A11ySettings) => void;

/**
 * The settings store.
 *
 * A singleton on purpose: accessibility that applies to one mode and not the
 * next is not accessibility. Modes read it, they never own it.
 */
export class A11yStore {
  private settings: A11ySettings = DEFAULT_A11Y;
  private listeners = new Set<Listener>();

  /** OS preferences, then anything the player saved. Player wins. */
  load(storage?: Pick<Storage, 'getItem' | 'setItem'>): A11ySettings {
    const store = storage ?? (typeof localStorage !== 'undefined' ? localStorage : undefined);
    let saved: Partial<A11ySettings> = {};
    try {
      const raw = store?.getItem(STORAGE_KEY);
      if (raw) saved = JSON.parse(raw) as Partial<A11ySettings>;
    } catch {
      // Corrupt settings must never stop a game booting. Defaults are fine.
      console.warn('[FEL-A11Y] stored settings unreadable; using defaults.');
    }
    this.settings = normalise({ ...osPreferences(), ...saved });
    return this.settings;
  }

  get(): A11ySettings { return this.settings; }

  set(patch: Partial<A11ySettings>, storage?: Pick<Storage, 'getItem' | 'setItem'>): A11ySettings {
    this.settings = normalise({ ...this.settings, ...patch });
    const store = storage ?? (typeof localStorage !== 'undefined' ? localStorage : undefined);
    try { store?.setItem(STORAGE_KEY, JSON.stringify(this.settings)); } catch { /* private mode */ }
    for (const fn of this.listeners) fn(this.settings);
    return this.settings;
  }

  /** Live updates — a change must apply without restarting the mode. */
  subscribe(fn: Listener): () => void {
    this.listeners.add(fn);
    return () => this.listeners.delete(fn);
  }
}

export const a11y = new A11yStore();

// ── helpers modes call, so no mode reads a raw flag ──────────────────────

/** Scale a camera shake amplitude. Returns 0 under reduced motion. */
export function shakeAmount(base: number, s: A11ySettings = a11y.get()): number {
  return s.reducedMotion ? 0 : base;
}

/**
 * Should this flash be shown?
 *
 * Anything above 3Hz is the documented photosensitive-seizure threshold, and
 * large red flashes are worse. This is the one accessibility setting where
 * getting it wrong can hurt somebody, so the check is a hard gate rather than
 * a scale.
 */
export function allowFlash(hz: number, s: A11ySettings = a11y.get()): boolean {
  if (s.noFlashing) return false;
  return hz <= 3;
}

/** Final timing window: base × DDA × assist. One number, one place. */
export function finalWindow(
  baseMs: number, ddaScale: number, s: A11ySettings = a11y.get(),
): number {
  return baseMs * ddaScale * assistWindowScale(s.assist);
}
