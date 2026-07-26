// inputCore — the decisions InputBus makes, with no DOM attached.
//
// Split out for the same reason MotionModel is pure: these are small rules
// that are impossible to eyeball and easy to get subtly wrong, and a
// keyboard-and-browser test is not a thing this project can run in CI. Here
// they are arithmetic, and arithmetic can be pinned.
//
// InputBus.ts owns the listeners, the gamepad polling and the timing. It owns
// no rules.

export type FelButton = 'A' | 'B' | 'X' | 'Y' | 'L1' | 'R1' | 'SELECT' | 'START';

export type FelInput =
  | { t: 'stick'; side: 'L' | 'R'; x: number; y: number }
  | { t: 'dpad'; dir: 'up' | 'down' | 'left' | 'right'; pressed: boolean }
  | { t: 'button'; btn: FelButton; pressed: boolean }
  | { t: 'trigger'; side: 'L' | 'R'; value: number };

/**
 * Default key→button table. A TABLE, not a switch — which is what makes
 * remapping nearly free, and remapping is a hard accessibility requirement
 * rather than a nice-to-have.
 */
export const DEFAULT_BINDINGS: Record<string, FelButton> = {
  j: 'A', k: 'B', l: 'X', i: 'Y',
  q: 'L1', e: 'R1', c: 'SELECT', escape: 'START',
};

export const DPAD_KEYS: Record<string, 'up' | 'down' | 'left' | 'right'> = {
  arrowup: 'up', arrowdown: 'down', arrowleft: 'left', arrowright: 'right',
};

export const MOVE_KEYS = ['w', 'a', 's', 'd'] as const;

/** Keys the browser does something unhelpful with while a game is running. */
export const SWALLOW = new Set([' ', 'arrowup', 'arrowdown', 'arrowleft', 'arrowright', 'tab', "'", '/']);

/**
 * A press shorter than this is a TAP; longer is a CHARGE RELEASE.
 *
 * v2 emitted BOTH a trigger-zero and a button-A on every release, so no mode
 * could tell "I finished charging" from "I tapped jump". Duration
 * disambiguates them, which is both correct and what a player already
 * expects. 150ms sits comfortably above an intentional tap (~60-100ms) and
 * well below anything anyone would call holding.
 */
export const TAP_MAX_MS = 150;

/** Full charge depth takes this long. Matches the shot meters modes draw. */
export const CHARGE_FULL_MS = 1100;

export type ReleaseKind = 'tap' | 'charge';

export function classifyRelease(heldMs: number): ReleaseKind {
  return heldMs < TAP_MAX_MS ? 'tap' : 'charge';
}

/**
 * Held keys → a stick vector.
 *
 * Deliberately NOT normalised. MotionModel owns magnitude; normalising in two
 * places is how the two end up disagreeing, and a disagreement here is the
 * 41%-faster-diagonal bug coming back through a different door.
 */
export function stickFromKeys(held: Set<string>): { x: number; y: number } {
  return {
    x: (held.has('d') ? 1 : 0) - (held.has('a') ? 1 : 0),
    y: (held.has('w') ? 1 : 0) - (held.has('s') ? 1 : 0),
  };
}

/** Is this a key the game cares about at all? */
export function isGameKey(key: string, bindings: Record<string, FelButton>): boolean {
  return (MOVE_KEYS as readonly string[]).includes(key)
    || key === ' ' || key === 'shift'
    || key in DPAD_KEYS || key in bindings;
}

/**
 * Should the browser's default be suppressed?
 *
 * Only for keys the game uses AND that the browser would otherwise act on —
 * and never for a modifier chord, because those are the user's shortcuts, not
 * gameplay. Swallowing Cmd-R would be a worse bug than the one being fixed.
 */
export function shouldPreventDefault(
  key: string, hasModifier: boolean, bindings: Record<string, FelButton>,
): boolean {
  if (hasModifier) return false;
  return SWALLOW.has(key) && isGameKey(key, bindings);
}
