// Legibility — a mechanic the player cannot see is a mechanic that does not
// exist.
//
// THE DEBT THIS PAYS
// Phases 2 through 8 added real depth, and I flagged the same risk three times
// without fixing it:
//
//   Phase 3  spacing zones and frame advantage — "the tip zone should be
//            visible; a player cannot learn footsies from a mechanic they
//            cannot see"
//   Phase 4  pitch tells — "recognitionAt() returns a number; without
//            something showing it the mode is GUESSING, not reading, which is
//            strictly worse than the timing bar it replaces"
//   Phase 5  wave sections — "WaveModel describes a wave, it does not render
//            one; the player reads a HUD instead of a wave"
//
// Every one of those shipped as half a mechanic. The model was right, tested,
// and invisible. A defender that commits and can be baited is indistinguishable
// from a random defender unless the commitment READS.
//
// So this is not a polish pass. It is the other half of six phases of work.
//
// THE RULE THAT FOLLOWS FROM IT
// A tell is not an effect. Effects are cosmetic and may be shed to hold frame
// rate; tells carry information the player needs to make a decision, and
// shedding one silently removes a mechanic. `AdaptiveQuality` never sheds a
// tell — that separation is the whole reason this file declares them as data
// rather than leaving each mode to draw its own.
//
// AND EVERY TELL HAS THREE CHANNELS
// Visual, audible, and haptic — because M82 established that colour alone is
// never a signal, and the same argument applies one level up: a tell that
// exists only as a colour flash is invisible to a colourblind player, one that
// exists only as a sound is invisible to a deaf player, and one that exists
// only on screen is missed by anyone looking at their own character.

export type TellChannel = 'visual' | 'audio' | 'haptic';

export type TellUrgency =
  /** The player must act NOW. Parry windows, incoming sections. */
  | 'act'
  /** Information that changes the next decision. Spacing, pitch identity. */
  | 'read'
  /** Confirms something that already happened. */
  | 'confirm';

export interface Tell {
  id: string;
  /** Which mode(s) it belongs to. `'*'` for anything. */
  modes: string[];
  urgency: TellUrgency;
  /** What the player learns. Written as the thing they should conclude. */
  meaning: string;
  /**
   * Where it must appear. `'subject'` means on the thing it is about — a
   * defender's commitment must read ON THE DEFENDER, not in a corner. A HUD
   * readout for a spatial mechanic is a stat, not a tell.
   */
  anchor: 'subject' | 'player' | 'hud' | 'world';
  /** The visual form. Never colour alone — see M82's palette. */
  visual: {
    form: 'outline' | 'ground_marker' | 'arc' | 'trail' | 'icon' | 'bar' | 'flash';
    /** A shape or glyph so the tell survives any colour vision. */
    glyph?: string;
    /** ms. `0` means it persists while the condition holds. */
    durationMs: number;
  };
  /** Caption text, required. Passed to M82's caption bus. */
  caption: string;
  /** Haptic pattern in ms, or null where a buzz would be noise. */
  haptic: number[] | null;
  /** True if losing this tell removes a mechanic rather than some polish. */
  loadBearing: boolean;
}

/**
 * The tells six phases of mechanics have been missing.
 *
 * This is a specification, not a renderer — the mode owns the drawing. What it
 * fixes is that nobody could previously say WHAT needed drawing, so it never
 * got drawn.
 */
export const TELLS: Tell[] = [
  // ── Phase 3: combat ────────────────────────────────────────────────────
  {
    id: 'spacing_tip',
    modes: ['karate', 'karate-vs', 'mixedcombat'],
    urgency: 'read',
    meaning: 'You can reach them and they cannot reach you. This is where you want to be.',
    anchor: 'world',
    visual: { form: 'ground_marker', glyph: '◆', durationMs: 0 },
    caption: 'IN RANGE — THEY ARE NOT',
    haptic: null,
    loadBearing: true,
  },
  {
    id: 'whiff_punish_window',
    modes: ['karate', 'karate-vs', 'mixedcombat'],
    urgency: 'act',
    meaning: 'They missed. You have frames to punish, and the window is closing.',
    anchor: 'subject',
    visual: { form: 'outline', glyph: '!', durationMs: 0 },
    caption: 'PUNISH NOW',
    haptic: [12],
    loadBearing: true,
  },
  {
    id: 'minus_on_block',
    modes: ['karate-vs', 'mixedcombat'],
    urgency: 'read',
    meaning: 'Your attack was blocked and you are the one who is late.',
    anchor: 'player',
    visual: { form: 'icon', glyph: '▼', durationMs: 400 },
    caption: 'BLOCKED — YOU ARE MINUS',
    haptic: null,
    loadBearing: true,
  },

  // ── Phase 2: basketball ────────────────────────────────────────────────
  {
    id: 'defender_committed',
    modes: ['onevone', 'threevthree'],
    urgency: 'act',
    meaning: 'They have committed to a side. Go the other way NOW.',
    anchor: 'subject',
    visual: { form: 'ground_marker', glyph: '→', durationMs: 0 },
    caption: 'THEY COMMITTED',
    haptic: [10],
    loadBearing: true,
  },
  {
    id: 'dunk_tier_reach',
    modes: ['dunk', 'dunkduel'],
    urgency: 'read',
    meaning: 'How far above the rim your vertical actually gets you.',
    anchor: 'world',
    visual: { form: 'arc', durationMs: 0 },
    caption: 'YOUR REACH',
    haptic: null,
    loadBearing: false,
  },

  // ── Phase 4: field & precision ─────────────────────────────────────────
  {
    id: 'pitch_tell',
    modes: ['baseball'],
    urgency: 'read',
    meaning: 'What the ball is doing out of the hand — spin, speed, release.',
    anchor: 'subject',
    visual: { form: 'trail', durationMs: 0 },
    caption: 'READ THE RELEASE',
    haptic: null,
    loadBearing: true,
  },
  {
    id: 'pursuit_angle',
    modes: ['football'],
    urgency: 'act',
    meaning: 'Which side the tackler is coming from — juke AWAY from it.',
    anchor: 'subject',
    visual: { form: 'ground_marker', glyph: '↗', durationMs: 0 },
    caption: 'PRESSURE FROM YOUR RIGHT',
    haptic: [8],
    loadBearing: true,
  },
  {
    id: 'rally_pressure',
    modes: ['tennis', 'volleyball'],
    urgency: 'read',
    meaning: 'How stretched your opponent is. Keep working them or go for it.',
    anchor: 'hud',
    visual: { form: 'bar', durationMs: 0 },
    caption: 'THEY ARE STRETCHED',
    haptic: null,
    loadBearing: true,
  },

  // ── Phase 5: board ─────────────────────────────────────────────────────
  {
    id: 'line_at_risk',
    modes: ['skateboard'],
    urgency: 'read',
    meaning: 'What you will lose if you bail. Bank it or push on.',
    anchor: 'hud',
    visual: { form: 'bar', durationMs: 0 },
    caption: 'BANKED — AT RISK',
    haptic: null,
    loadBearing: true,
  },
  {
    id: 'edge_state',
    modes: ['snowboard'],
    urgency: 'read',
    meaning: 'Carving or skidding. A skid is costing you speed right now.',
    anchor: 'player',
    visual: { form: 'trail', durationMs: 0 },
    caption: 'SKIDDING — LOSING SPEED',
    haptic: [6, 40, 6],
    loadBearing: true,
  },
  {
    id: 'wave_section',
    modes: ['surf'],
    urgency: 'act',
    meaning: 'A section is standing up ahead of you. Make it or pull off.',
    anchor: 'world',
    visual: { form: 'outline', glyph: '▲', durationMs: 0 },
    caption: 'SECTION AHEAD',
    haptic: [14],
    loadBearing: true,
  },

  // ── cross-mode ─────────────────────────────────────────────────────────
  {
    id: 'prq_effect',
    modes: ['*'],
    urgency: 'confirm',
    meaning: 'Your readiness today changed how this opponent plays.',
    anchor: 'hud',
    // The glyph is not decoration. `auditTell` caught this entry shipping as a
    // colour-only icon on its first run — which is precisely the failure M82
    // spent a whole batch arguing against, reappearing one level up in my own
    // registry.
    visual: { form: 'icon', glyph: '◈', durationMs: 2500 },
    caption: 'ELITE — OPPONENT REACTS FASTER',
    haptic: null,
    loadBearing: false,
  },
];

export function tellsFor(modeId: string): Tell[] {
  return TELLS.filter((t) => t.modes.includes(modeId) || t.modes.includes('*'));
}

export function tell(id: string): Tell | undefined {
  return TELLS.find((t) => t.id === id);
}

/** Tells that carry a mechanic. These may never be shed for performance. */
export function loadBearingTells(modeId: string): Tell[] {
  return tellsFor(modeId).filter((t) => t.loadBearing);
}

export class MissingTellError extends Error {}

/**
 * Does this tell survive every accessibility configuration?
 *
 * The check M82 argued for, applied to mechanics rather than to icons. A tell
 * that fails here is invisible to a real group of players — and because it is
 * load-bearing, those players are not playing a harder game, they are playing
 * one with a mechanic removed.
 */
export function auditTell(t: Tell): string[] {
  const problems: string[] = [];

  if (!t.caption) problems.push(`${t.id}: no caption — silent to a deaf player`);
  if (t.visual.form === 'flash' && t.urgency === 'act') {
    problems.push(`${t.id}: an "act" tell that is only a flash is lost under reduced motion, `
      + 'which is exactly when a player most needs the information');
  }
  if (!t.visual.glyph && ['outline', 'icon', 'ground_marker'].includes(t.visual.form)) {
    problems.push(`${t.id}: no glyph — distinguishable only by colour`);
  }
  if (t.urgency === 'act' && t.anchor === 'hud') {
    problems.push(`${t.id}: an urgent tell in the HUD will be missed by a player watching `
      + 'their character. Anchor it to the subject.');
  }
  if (t.loadBearing && t.visual.durationMs > 0 && t.visual.durationMs < 250) {
    problems.push(`${t.id}: ${t.visual.durationMs}ms is below the ~250ms a player can `
      + 'reliably notice while concentrating elsewhere');
  }
  return problems;
}

/** Every tell that a mode's mechanics need but which nothing draws yet. */
export function unimplementedTells(modeId: string, implemented: string[]): Tell[] {
  return loadBearingTells(modeId).filter((t) => !implemented.includes(t.id));
}

/**
 * Is this mode's depth actually reachable?
 *
 * The question Phase 9 exists to answer. A mode with three load-bearing tells
 * and none of them drawn has three mechanics the player cannot use, and it
 * will read as "random" no matter how good the model underneath is.
 */
export function legibilityReport(modeId: string, implemented: string[]): {
  ready: boolean; missing: Tell[]; note: string;
} {
  const missing = unimplementedTells(modeId, implemented);
  if (missing.length === 0) {
    return { ready: true, missing, note: `${modeId}: every load-bearing tell is drawn.` };
  }
  return {
    ready: false,
    missing,
    note: `${modeId} has ${missing.length} mechanic(s) the player cannot see: `
      + `${missing.map((t) => t.id).join(', ')}. Until these are drawn, the mode reads as `
      + 'random and the model underneath is wasted.',
  };
}
