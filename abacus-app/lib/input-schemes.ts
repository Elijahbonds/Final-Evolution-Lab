/**
 * FEL Unified Input Schemes
 * ─────────────────────────
 * A single source of truth mapping every game `mode` to an on-screen virtual
 * controller layout AND a physical-gamepad mapping. Both the on-screen
 * VirtualController and the physical gamepad poller funnel through the SAME
 * synthetic-keyboard bridge so all 20+ modes respond identically — the keyboard
 * path is the battle-tested one every game already implements.
 *
 * This is an ORIGINAL controller design for FEL. It is NOT an emulator and does
 * not replicate any console/BIOS/system software.
 */

export type FacePos = 'a' | 'b' | 'x' | 'y';

export interface VCButton {
  /** Diamond position (also drives physical face-button mapping: a=0,b=1,x=2,y=3). */
  pos: FacePos;
  label: string;
  /** KeyboardEvent.key value to synthesize (' ' for space, 'ArrowLeft', 'j', '1', ';' ...). */
  key: string;
  color: string;
  /** When true the button is a HOLD (keydown on press, keyup on release). Taps also send both. */
  hold?: boolean;
}

export interface VCTrigger {
  label: string;
  key: string;
  color: string;
  hold?: boolean;
}

export interface VCDir {
  up?: string;
  down?: string;
  left?: string;
  right?: string;
}

export interface VCScheme {
  /** D-pad key map, or null to hide the D-pad. */
  dir: VCDir | null;
  buttons: VCButton[];
  /** Single shoulder trigger (e.g. BLOCK / GUARD), or null. */
  trigger?: VCTrigger | null;
  /** Multiple triggers (board modes: spin-left/spin-right). */
  triggers?: VCTrigger[];
  /** One-line documented control scheme shown in the legend. */
  hint: string;
}

const CYAN = '#00E5FF';
const RED = '#FF3366';
const GREEN = '#00FF9D';
const PURPLE = '#A855F7';
const GOLD = '#FFD700';

export const SCHEMES: Record<string, VCScheme> = {
  dunkContest: {
    dir: { up: 'ArrowUp', down: 'ArrowDown', left: 'ArrowLeft', right: 'ArrowRight' },
    buttons: [{ pos: 'a', label: 'DUNK', key: ' ', color: GREEN, hold: true }],
    hint: 'D-Pad sets your approach & style · A charges then throws it down.',
  },
  hoops1v1: {
    dir: { left: 'ArrowLeft', up: 'ArrowUp', right: 'ArrowRight' },
    buttons: [{ pos: 'a', label: 'DRIVE', key: ' ', color: GREEN }],
    hint: 'D-Pad guards left / center / right · A drives and shoots.',
  },
  hoops3v3: {
    dir: { left: 'ArrowLeft', up: 'ArrowUp', right: 'ArrowRight' },
    buttons: [{ pos: 'a', label: 'DRIVE', key: ' ', color: GREEN }],
    hint: 'D-Pad guards left / center / right · A drives and shoots.',
  },
  threePoint: {
    dir: null,
    buttons: [{ pos: 'a', label: 'SHOOT', key: ' ', color: GREEN }],
    hint: 'A releases the shot — nail the timing bar in the sweet zone.',
  },
  karateEndless: {
    dir: { left: 'a', right: 'd' },
    buttons: [
      { pos: 'x', label: 'JAB', key: 'j', color: CYAN },
      { pos: 'y', label: 'KICK', key: 'k', color: RED },
      { pos: 'b', label: 'SPCL', key: ';', color: PURPLE },
    ],
    trigger: { label: 'BLOCK', key: 'l', color: GOLD, hold: true },
    hint: 'D-Pad steps · X jab · Y kick · B special · hold L/R to block.',
  },
  karateVersus: {
    dir: null,
    buttons: [
      { pos: 'a', label: 'STRIKE', key: ' ', color: GREEN },
      { pos: 'y', label: 'SPCL', key: 'ArrowUp', color: RED },
    ],
    trigger: { label: 'BLOCK', key: 'ArrowDown', color: GOLD, hold: true },
    hint: 'A strike · Y special · hold L/R to block incoming hits.',
  },
  tennis: {
    dir: null,
    buttons: [{ pos: 'a', label: 'SERVE / SWING', key: ' ', color: GREEN }],
    hint: 'A serves, then times your swing on the return.',
  },
  tiebreak: {
    dir: null,
    buttons: [
      { pos: 'x', label: '\u25C0 BACKHAND', key: 'ArrowLeft', color: CYAN },
      { pos: 'b', label: 'FOREHAND \u25B6', key: 'ArrowRight', color: RED },
    ],
    hint: 'Tap the swing that matches the incoming ball — left or right.',
  },
  sprint: {
    dir: null,
    buttons: [
      { pos: 'x', label: '\u25C0 STEP', key: 'ArrowLeft', color: CYAN },
      { pos: 'b', label: 'STEP \u25B6', key: 'ArrowRight', color: RED },
    ],
    hint: 'Alternate \u25C0 \u25B6 as fast as you can to sprint the line.',
  },
  skateboarding: {
    dir: { up: 'ArrowUp', down: 'ArrowDown', left: 'ArrowLeft', right: 'ArrowRight' },
    buttons: [
      { pos: 'a', label: 'OLLIE', key: ' ', color: GREEN, hold: true },
      { pos: 'x', label: 'FLIP', key: 'j', color: CYAN },
      { pos: 'y', label: 'GRAB', key: 'k', color: PURPLE },
      { pos: 'b', label: 'GRIND', key: 'i', color: RED, hold: true },
    ],
    triggers: [
      { label: 'SPIN ◀', key: 'q', color: CYAN },
      { label: 'SPIN ▶', key: 'e', color: CYAN },
    ],
    hint: 'D-Pad carve · A ollie · X flip · Y grab · B grind · L1/R1 spin · Shift boost.',
  },
  snowboarding: {
    dir: { up: 'ArrowUp', down: 'ArrowDown', left: 'ArrowLeft', right: 'ArrowRight' },
    buttons: [
      { pos: 'a', label: 'JUMP', key: ' ', color: GREEN, hold: true },
      { pos: 'x', label: 'FLIP', key: 'j', color: CYAN },
      { pos: 'y', label: 'GRAB', key: 'k', color: PURPLE },
      { pos: 'b', label: 'GRIND', key: 'i', color: RED, hold: true },
    ],
    triggers: [
      { label: 'SPIN ◀', key: 'q', color: CYAN },
      { label: 'SPIN ▶', key: 'e', color: CYAN },
    ],
    hint: 'D-Pad carve · A jump · X flip · Y grab · B rail jib · L1/R1 spin · Shift boost.',
  },
  surfing: {
    dir: { up: 'ArrowUp', down: 'ArrowDown', left: 'ArrowLeft', right: 'ArrowRight' },
    buttons: [
      { pos: 'a', label: 'PUMP', key: ' ', color: GREEN, hold: true },
      { pos: 'x', label: 'FLIP', key: 'j', color: CYAN },
      { pos: 'y', label: 'GRAB', key: 'k', color: PURPLE },
    ],
    triggers: [
      { label: 'SPIN ◀', key: 'q', color: CYAN },
      { label: 'SPIN ▶', key: 'e', color: CYAN },
    ],
    hint: 'D-Pad lean · A pump/pop · X flip · Y grab · L1/R1 spin · Shift boost.',
  },
  bigAir: {
    dir: null,
    buttons: [{ pos: 'a', label: 'CHARGE / SPIN', key: ' ', color: GREEN, hold: true }],
    hint: 'Hold A to charge the ramp, release to launch and spin.',
  },
  soccer: {
    dir: { left: 'ArrowLeft', down: 'ArrowDown', right: 'ArrowRight' },
    buttons: [{ pos: 'a', label: 'SHOOT / DIVE', key: ' ', color: GREEN }],
    hint: 'A locks aim then power · when keeping, D-Pad picks the dive.',
  },
  baseball: {
    dir: null,
    buttons: [{ pos: 'a', label: 'SWING', key: ' ', color: GREEN }],
    hint: 'A swings — time it as the ball enters the hit zone.',
  },
  golf: {
    dir: null,
    buttons: [{ pos: 'a', label: 'STROKE', key: ' ', color: GREEN }],
    hint: 'A sets aim, then power — land it close to the pin.',
  },
  gymnastics: {
    dir: { up: 'ArrowUp', down: 'ArrowDown', left: 'ArrowLeft', right: 'ArrowRight' },
    buttons: [],
    hint: 'Hit the D-Pad arrow that matches each cue in rhythm.',
  },
  training: {
    dir: null,
    buttons: [{ pos: 'a', label: 'LIFT (HOLD)', key: ' ', color: GREEN, hold: true }],
    hint: 'Hold A to build power, release inside the green zone.',
  },
  storyMode: {
    dir: { up: 'ArrowUp', down: 'ArrowDown', left: 'ArrowLeft', right: 'ArrowRight' },
    buttons: [
      { pos: 'a', label: 'JUMP', key: ' ', color: GREEN },
      { pos: 'x', label: 'ATTACK', key: 'j', color: CYAN },
      { pos: 'y', label: 'STRIKE', key: 'k', color: RED },
    ],
    trigger: { label: 'GUARD', key: 'l', color: GOLD, hold: true },
    hint: 'D-Pad move · A jump · X attack · Y strike · hold L/R to guard.',
  },
};

export function getScheme(mode: string): VCScheme | null {
  return SCHEMES[mode] ?? null;
}
