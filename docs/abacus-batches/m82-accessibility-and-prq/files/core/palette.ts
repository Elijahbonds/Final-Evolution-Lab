// palette — colour that survives colourblindness, and never carries meaning alone.
//
// Roughly 8% of men and 0.5% of women have some colour-vision deficiency;
// deuteranopia alone is about 6% of men. A red/green success-fail pair — the
// most common choice in games — is the single worst pick available, because it
// is precisely the axis those players cannot separate.
//
// TWO RULES, AND THE SECOND MATTERS MORE
//
// 1. Substitute the palette. Easy, mechanical, done below.
// 2. NEVER LET COLOUR BE THE ONLY SIGNAL. A green flash and a red flash that
//    differ only in hue are the same flash to a deuteranope, whatever palette
//    you pick. Every state must also differ in SHAPE, ICON, or POSITION.
//    `signalFor()` returns all three together so a call site cannot take the
//    colour and forget the rest.

import type { ColorMode } from './a11y';

export type Signal = 'success' | 'failure' | 'warning' | 'neutral' | 'perfect';

export interface SignalStyle {
  color: string;
  /** Redundant encoding — this is what makes it work without colour at all. */
  glyph: string;
  /** A shape name the HUD maps to a border/outline treatment. */
  shape: 'circle' | 'cross' | 'triangle' | 'square' | 'diamond';
  /** Short label. Never rely on the glyph alone either — icons are learned. */
  label: string;
}

/**
 * Default palette. Note it is NOT red/green: the success/failure axis is
 * blue/orange, which separates under every common deficiency. That choice
 * costs nothing and removes the problem at the source rather than patching it
 * per-user.
 */
const DEFAULT: Record<Signal, string> = {
  success: '#3B82F6',   // blue
  failure: '#F97316',   // orange
  warning: '#EAB308',   // amber
  neutral: '#94A3B8',   // slate
  perfect: '#A855F7',   // violet
};

/**
 * Per-deficiency substitutions.
 *
 * Only the hues that actually collide are replaced. Swapping the whole palette
 * for every mode would make the game look wrong to people who did not ask for
 * a different look, which is its own kind of failure.
 */
const SUBSTITUTIONS: Record<ColorMode, Partial<Record<Signal, string>>> = {
  default: {},
  // red/green axis compressed → push failure well into orange, perfect to a
  // blue-violet so it does not read as success.
  deuteranopia: { failure: '#E85D04', perfect: '#7C3AED', warning: '#FFD60A' },
  protanopia: { failure: '#D96704', perfect: '#6D28D9', warning: '#FFCB05' },
  // blue/yellow axis compressed → move success off blue entirely.
  tritanopia: { success: '#12B886', failure: '#E03131', warning: '#F76707', perfect: '#C2255C' },
  'high-contrast': {
    success: '#FFFFFF', failure: '#FFFFFF', warning: '#FFFFFF',
    neutral: '#FFFFFF', perfect: '#FFFFFF',
  },
};

/** Redundant encodings. Identical across every palette on purpose — a player
 *  who learns the glyph keeps it when they change colour mode. */
const ENCODING: Record<Signal, Omit<SignalStyle, 'color'>> = {
  success: { glyph: '✓', shape: 'circle', label: 'GOOD' },
  failure: { glyph: '✕', shape: 'cross', label: 'MISS' },
  warning: { glyph: '!', shape: 'triangle', label: 'WARN' },
  neutral: { glyph: '·', shape: 'square', label: '' },
  perfect: { glyph: '★', shape: 'diamond', label: 'PERFECT' },
};

export function colorFor(signal: Signal, mode: ColorMode = 'default'): string {
  return SUBSTITUTIONS[mode]?.[signal] ?? DEFAULT[signal];
}

/**
 * Everything needed to render a signal accessibly, in one object.
 *
 * Returning the colour on its own would let a call site use just that, which
 * is the failure this module exists to prevent. It is a small piece of API
 * design doing the work a code review otherwise has to do every time.
 */
export function signalFor(signal: Signal, mode: ColorMode = 'default'): SignalStyle {
  return { color: colorFor(signal, mode), ...ENCODING[signal] };
}

// ── contrast, checkable rather than eyeballed ────────────────────────────

function channel(c: number): number {
  const s = c / 255;
  return s <= 0.04045 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
}

/** Relative luminance per WCAG 2.x. */
export function luminance(hex: string): number {
  const h = hex.replace('#', '');
  const full = h.length === 3 ? h.split('').map((c) => c + c).join('') : h;
  const r = parseInt(full.slice(0, 2), 16);
  const g = parseInt(full.slice(2, 4), 16);
  const b = parseInt(full.slice(4, 6), 16);
  return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b);
}

/** WCAG contrast ratio, 1:1 to 21:1. */
export function contrastRatio(a: string, b: string): number {
  const la = luminance(a);
  const lb = luminance(b);
  return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
}

/** AA: 4.5:1 for body text, 3:1 for large text and UI components. */
export function meetsAA(fg: string, bg: string, large = false): boolean {
  return contrastRatio(fg, bg) >= (large ? 3 : 4.5);
}

/**
 * Pick black or white text for a background.
 *
 * The HUD sits over venues that range from a night dojo to a noon beach, so
 * hard-coding either one guarantees an unreadable case. This picks per
 * background and is checked by test.
 */
export function textOn(bg: string): '#000000' | '#FFFFFF' {
  return contrastRatio('#000000', bg) >= contrastRatio('#FFFFFF', bg) ? '#000000' : '#FFFFFF';
}
