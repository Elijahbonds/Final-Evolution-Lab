// modeVerbs — the ONLY source of touch-control layouts. TouchOverlay consumes
// this; no mode may render its own buttons.

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
  default: { stick: true, buttons: [{ label: 'ACTION', color: '#22d3ee', emit: A('A') }] },
};
