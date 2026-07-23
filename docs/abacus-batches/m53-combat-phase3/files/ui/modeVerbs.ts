// modeVerbs v3 — REPLACES the M52 file (which replaced M35). Adds the two
// Phase 3 combat decks: 'karate-vs' (the rebuilt duel — same four verbs as
// Karate Endless) and 'mixedcombat' (the new ring-out weapon duel).
// Everything else is byte-identical to M52 (which added onevone/threevthree/
// carnival and fixed the shoot-impossible-on-touch gap).

import type { FelInput } from '../core/InputBus';

export interface VerbButton {
  label: string;                       // verb, not letter: "SLAM", "JAB"
  color: string;
  emit: FelInput;                      // press event (release auto-emitted for buttons)
  hold?: boolean;                      // analog hold → trigger stream (charge)
}
export interface ModeVerbConfig {
  stick: boolean;                      // left stick zone
  buttons: VerbButton[];               // up to 4, rendered as the right cluster
}

const A = (btn: 'A' | 'B' | 'X' | 'Y'): FelInput => ({ t: 'button', btn, pressed: true });
const RT = (value: number): FelInput => ({ t: 'trigger', side: 'R', value });

export const MODE_VERBS: Record<string, ModeVerbConfig> = {
  dunk: {
    stick: true,
    buttons: [
      { label: 'CHARGE', color: '#ffd75e', emit: RT(1), hold: true },
      { label: 'SLAM', color: '#22d3ee', emit: A('A') },
      { label: 'STYLE', color: '#a78bfa', emit: A('B') },
    ],
  },
  karate: {
    stick: true,
    buttons: [
      { label: 'JAB', color: '#22d3ee', emit: A('A') },
      { label: 'KICK', color: '#ff6b3d', emit: A('B') },
      { label: 'HEAVY', color: '#ffd75e', emit: A('Y') },
      { label: 'BLOCK', color: '#9aa7b4', emit: A('X') },
    ],
  },
  football: {
    stick: true,
    buttons: [
      { label: 'HURDLE', color: '#22d3ee', emit: A('A') },
      { label: 'SPIN', color: '#ffd75e', emit: A('B') },
      { label: 'JUKE L', color: '#a78bfa', emit: A('X') },
      { label: 'JUKE R', color: '#ff6b3d', emit: A('Y') },
    ],
  },
  skateboard: {
    stick: true,
    buttons: [
      { label: 'POP', color: '#22d3ee', emit: A('A') },
      { label: 'FLIP', color: '#ff6b3d', emit: A('B') },
      { label: 'GRAB', color: '#a78bfa', emit: A('X') },
      { label: 'PUMP', color: '#ffd75e', emit: RT(1), hold: true },
    ],
  },
  snowboard_slalom: {
    stick: true,
    buttons: [
      { label: 'JUMP', color: '#22d3ee', emit: A('A') },
      { label: 'GRAB', color: '#a78bfa', emit: A('B') },
      { label: 'TUCK', color: '#ffd75e', emit: RT(1), hold: true },
    ],
  },
  surf: {
    stick: true,
    buttons: [
      { label: 'AIR', color: '#22d3ee', emit: A('A') },
      { label: 'CARVE', color: '#ffd75e', emit: RT(1), hold: true },
    ],
  },
  tennis: { stick: true, buttons: [{ label: 'SWING', color: '#22d3ee', emit: A('A') }] },
  derby: { stick: true, buttons: [{ label: 'SWING', color: '#22d3ee', emit: A('A') }] },
  penalty: { stick: true, buttons: [{ label: 'STRIKE', color: '#22d3ee', emit: A('A') }] },
  golf: { stick: true, buttons: [{ label: 'SWING', color: '#22d3ee', emit: A('A') }] },

  // ── NEW (M52): the three modes that were falling through to `default` ──
  // 1v1 Hoops: shooting is HOLD-then-release on the trigger stream (shot
  // meter). Crossovers come from stick reversal, so no button needed there.
  onevone: {
    stick: true,
    buttons: [
      { label: 'SHOOT', color: '#ffd75e', emit: RT(1), hold: true },
    ],
  },
  // 3v3 Streetball: same held-trigger shot, plus PASS (B) and STEAL (X) —
  // the exact bindings LocalInputSource already reads.
  threevthree: {
    stick: true,
    buttons: [
      { label: 'SHOOT', color: '#ffd75e', emit: RT(1), hold: true },
      { label: 'PASS', color: '#22d3ee', emit: A('B') },
      { label: 'STEAL', color: '#a78bfa', emit: A('X') },
    ],
  },
  // Court Carnival: four rotating events share one deck. CHARGE covers Slam
  // Rush's held trigger + Trick Gauntlet's pump; GO is every event's A verb
  // (slam/jab/jump/shoot); TRICK is B (kick/flip A); POWER is Y (heavy/flip
  // B). The Gauntlet's X spin is the one verb that didn't fit the 4-button
  // budget — B/Y still give two distinct tricks, so variety scoring works.
  carnival: {
    stick: true,
    buttons: [
      { label: 'CHARGE', color: '#ffd75e', emit: RT(1), hold: true },
      { label: 'GO', color: '#22d3ee', emit: A('A') },
      { label: 'TRICK', color: '#ff6b3d', emit: A('B') },
      { label: 'POWER', color: '#a78bfa', emit: A('Y') },
    ],
  },

  // ── NEW (M53): the Phase 3 combat duels ──
  // Karate VS uses the exact same verb set as Karate Endless — BLOCK is
  // press-AND-release aware in the mode (hold to guard, tap to parry).
  'karate-vs': {
    stick: true,
    buttons: [
      { label: 'JAB', color: '#22d3ee', emit: A('A') },
      { label: 'KICK', color: '#ff6b3d', emit: A('B') },
      { label: 'HEAVY', color: '#ffd75e', emit: A('Y') },
      { label: 'BLOCK', color: '#9aa7b4', emit: A('X') },
    ],
  },
  mixedcombat: {
    stick: true,
    buttons: [
      { label: 'STRIKE', color: '#22d3ee', emit: A('A') },
      { label: 'KICK', color: '#ff6b3d', emit: A('B') },
      { label: 'HEAVY', color: '#ffd75e', emit: A('Y') },
      { label: 'GUARD', color: '#9aa7b4', emit: A('X') },
    ],
  },

  default: { stick: true, buttons: [{ label: 'ACTION', color: '#22d3ee', emit: A('A') }] },
};
