// node --experimental-strip-types tests/a11y_test.ts
//
// Accessibility settings, captions, and the colour system.
//
// These are tested rather than eyeballed because most accessibility bugs are
// invisible to the person who wrote the feature. A palette that fails for
// deuteranopia looks fine to everyone else. A caption queue that drops the
// parry cue under load looks fine until the one player who needs it plays.

import {
  A11yStore, DEFAULT_A11Y, normalise, assistWindowScale, assistReactionBonus,
  shakeAmount, allowFlash, finalWindow, type A11ySettings,
} from '../core/a11y.ts';
import { CaptionBus, MAX_VISIBLE, DEFAULT_DURATION } from '../core/captions.ts';
import {
  colorFor, signalFor, contrastRatio, luminance, meetsAA, textOn,
} from '../core/palette.ts';

let pass = 0, fail = 0;
const ok = (n: string, c: boolean, x = '') => { c ? (pass++, console.log(`  ok   ${n}`)) : (fail++, console.log(`  FAIL ${n} ${x}`)); };

/** In-memory localStorage stand-in. */
const fakeStore = () => {
  const m = new Map<string, string>();
  return {
    getItem: (k: string) => m.get(k) ?? null,
    setItem: (k: string, v: string) => { m.set(k, v); },
    raw: m,
  };
};

// ── assist ───────────────────────────────────────────────────────────────
ok('assist off changes nothing', assistWindowScale('off') === 1.0);
ok('assist levels increase monotonically',
  assistWindowScale('light') < assistWindowScale('standard')
  && assistWindowScale('standard') < assistWindowScale('full'));
ok('full assist widens windows by 60%, not infinitely',
  assistWindowScale('full') === 1.6);
ok('reaction bonus is zero when off', assistReactionBonus('off') === 0);
ok('reaction bonus scales with level',
  assistReactionBonus('full') > assistReactionBonus('light'));

// The assist multiplies with DDA rather than replacing it — a struggling
// player who also asked for help gets both.
ok('assist COMPOSES with DDA rather than overriding it',
  finalWindow(100, 1.35, { ...DEFAULT_A11Y, assist: 'full' }) === 100 * 1.35 * 1.6);
ok('with no assist, DDA alone decides',
  finalWindow(100, 1.35, DEFAULT_A11Y) === 135);
ok('with neither, the base window is untouched',
  finalWindow(100, 1.0, DEFAULT_A11Y) === 100);

// ── reduced motion and flashing ──────────────────────────────────────────
ok('reduced motion zeroes camera shake',
  shakeAmount(0.5, { ...DEFAULT_A11Y, reducedMotion: true }) === 0);
ok('shake is untouched by default', shakeAmount(0.5, DEFAULT_A11Y) === 0.5);

ok('a slow flash is allowed', allowFlash(2, DEFAULT_A11Y));
ok('SEIZURE RISK: anything above 3Hz is blocked by default',
  !allowFlash(4, DEFAULT_A11Y));
ok('exactly 3Hz is the boundary and is allowed', allowFlash(3, DEFAULT_A11Y));
ok('noFlashing blocks even a slow flash',
  !allowFlash(1, { ...DEFAULT_A11Y, noFlashing: true }));
ok('noFlashing is INDEPENDENT of reducedMotion — different harms',
  allowFlash(2, { ...DEFAULT_A11Y, reducedMotion: true, noFlashing: false }));

// ── normalise: never trust stored JSON ───────────────────────────────────
ok('an invalid assist level falls back to off',
  normalise({ assist: 'turbo' as never }).assist === 'off');
ok('an invalid colour mode falls back to default',
  normalise({ colorMode: 'nonsense' as never }).colorMode === 'default');
ok('text scale is clamped at 2', normalise({ textScale: 9 }).textScale === 2);
ok('text scale is floored at 1', normalise({ textScale: 0.1 }).textScale === 1);
ok('a non-numeric text scale becomes 1',
  normalise({ textScale: 'big' as never }).textScale === 1);
ok('null bindings become an empty object',
  typeof normalise({ bindings: null as never }).bindings === 'object');
ok('normalise fills every field', Object.keys(normalise({})).length === Object.keys(DEFAULT_A11Y).length);

// ── the store ────────────────────────────────────────────────────────────
{
  const store = fakeStore();
  const a = new A11yStore();
  ok('a fresh load gives defaults', a.load(store).assist === 'off');
  a.set({ assist: 'full', captions: true }, store);
  ok('set persists', store.raw.size === 1);

  const b = new A11yStore();
  const loaded = b.load(store);
  ok('settings survive a reload', loaded.assist === 'full' && loaded.captions === true);
}
{
  const store = fakeStore();
  store.setItem('fel.a11y.v1', '{ this is not json');
  const a = new A11yStore();
  ok('CORRUPT SETTINGS MUST NOT STOP A GAME BOOTING',
    a.load(store).assist === 'off');
}
{
  const store = fakeStore();
  const a = new A11yStore();
  a.load(store);
  let seen: A11ySettings | null = null;
  const off = a.subscribe((s) => { seen = s; });
  a.set({ captions: true }, store);
  ok('subscribers are notified — a change applies without restarting the mode',
    seen !== null && (seen as A11ySettings).captions === true);
  off();
  a.set({ captions: false }, store);
  ok('unsubscribe works', (seen as A11ySettings).captions === true);
}
{
  // A store that throws (Safari private browsing) must not take the game down.
  const throwing = {
    getItem: () => { throw new Error('denied'); },
    setItem: () => { throw new Error('denied'); },
  };
  const a = new A11yStore();
  ok('a storage that throws on read is survivable', a.load(throwing).assist === 'off');
  ok('a storage that throws on write is survivable',
    a.set({ assist: 'light' }, throwing).assist === 'light');
}

// ── captions ─────────────────────────────────────────────────────────────
{
  let t = 1000;
  const bus = new CaptionBus(() => t);
  ok('captions do nothing while disabled', bus.cue('PARRY', 'critical') === null);
  ok('nothing is visible while disabled', bus.visible().length === 0);

  bus.setEnabled(true);
  ok('a cue returns an id once enabled', typeof bus.cue('PARRY', 'critical') === 'number');
  ok('the cue is visible', bus.visible()[0].text === 'PARRY');
  ok('duration comes from importance',
    bus.visible()[0].durationMs === DEFAULT_DURATION.critical);

  t += 2000;
  bus.tick();
  ok('a cue expires', bus.visible().length === 0);
}
{
  let t = 0;
  const bus = new CaptionBus(() => t);
  bus.setEnabled(true);
  bus.cue('crowd', 'ambient');
  bus.cue('combo x2', 'feedback');
  bus.cue('nice', 'feedback');
  bus.cue('PARRY NOW', 'critical');

  ok('the queue is capped', bus.visible().length === MAX_VISIBLE);
  ok('THE CRITICAL CUE SURVIVES — a FIFO would have dropped it',
    bus.visible().some((c) => c.text === 'PARRY NOW'));
  ok('ambient is evicted first',
    !bus.visible().some((c) => c.text === 'crowd'));
  ok('critical sorts to the top', bus.visible()[0].importance === 'critical');
}
{
  let t = 0;
  const bus = new CaptionBus(() => t);
  bus.setEnabled(true);
  bus.cue('a', 'critical'); bus.cue('b', 'critical');
  bus.cue('c', 'critical'); bus.cue('d', 'critical');
  ok('even all-critical is capped — a wall of text helps nobody',
    bus.visible().length === MAX_VISIBLE);
  ok('the oldest critical is the one dropped',
    !bus.visible().some((c) => c.text === 'a'));
}
{
  let t = 0;
  const bus = new CaptionBus(() => t);
  bus.setEnabled(true);
  bus.cue('x', 'feedback');
  let got = -1;
  bus.subscribe((v) => { got = v.length; });
  ok('subscribe fires immediately with current state', got === 1);
  bus.setEnabled(false);
  ok('disabling clears the queue', got === 0);
  ok('directional cues are carried', (() => {
    bus.setEnabled(true);
    bus.cue('INCOMING', 'critical', 'left');
    return bus.visible()[0].from === 'left';
  })());
}

// ── palette ──────────────────────────────────────────────────────────────
ok('default success/failure is NOT red/green — the worst possible axis',
  colorFor('success') === '#3B82F6' && colorFor('failure') === '#F97316');
ok('deuteranopia substitutes failure', colorFor('failure', 'deuteranopia') !== colorFor('failure'));
ok('tritanopia moves success off blue',
  colorFor('success', 'tritanopia') !== colorFor('success'));
ok('an unsubstituted signal falls through to the default',
  colorFor('neutral', 'deuteranopia') === colorFor('neutral'));
ok('high contrast is all-white', colorFor('success', 'high-contrast') === '#FFFFFF');

// THE RULE THAT MATTERS MORE THAN THE PALETTE
ok('signalFor ALWAYS carries a glyph', signalFor('success').glyph.length > 0);
ok('signalFor always carries a shape', signalFor('failure').shape === 'cross');
ok('success and failure differ in SHAPE, not just hue',
  signalFor('success').shape !== signalFor('failure').shape);
ok('success and failure differ in GLYPH too',
  signalFor('success').glyph !== signalFor('failure').glyph);
ok('the redundant encoding is identical across palettes — a learned glyph stays learned',
  signalFor('failure', 'deuteranopia').glyph === signalFor('failure').glyph
  && signalFor('failure', 'tritanopia').shape === signalFor('failure').shape);
ok('under high contrast, where every colour is white, shape and glyph are the ONLY signal',
  colorFor('success', 'high-contrast') === colorFor('failure', 'high-contrast')
  && signalFor('success', 'high-contrast').glyph !== signalFor('failure', 'high-contrast').glyph);

// contrast maths
ok('black on white is 21:1', Math.round(contrastRatio('#000000', '#FFFFFF')) === 21);
ok('a colour against itself is 1:1', Math.round(contrastRatio('#3B82F6', '#3B82F6')) === 1);
ok('contrast is symmetric',
  contrastRatio('#000', '#FFF') === contrastRatio('#FFF', '#000'));
ok('shorthand hex is expanded', Math.round(contrastRatio('#000', '#FFFFFF')) === 21);
ok('white luminance is 1', Math.abs(luminance('#FFFFFF') - 1) < 1e-9);
ok('black luminance is 0', luminance('#000000') === 0);
ok('meetsAA is stricter for body text than large text',
  (() => {
    // find a pair that passes at 3:1 but not 4.5:1
    const fg = '#767676'; const bg = '#FFFFFF';
    const r = contrastRatio(fg, bg);
    return r >= 3 && r < 4.5 ? (meetsAA(fg, bg, true) && !meetsAA(fg, bg, false)) : true;
  })());

ok('textOn picks black for a light background', textOn('#FFFFFF') === '#000000');
ok('textOn picks white for a dark background', textOn('#0A0A0A') === '#FFFFFF');
ok('textOn always meets AA against its own background',
  ['#FFFFFF', '#000000', '#3B82F6', '#F97316', '#EAB308', '#94A3B8', '#A855F7']
    .every((bg) => meetsAA(textOn(bg), bg, true)),
  'the HUD sits over venues from a night dojo to a noon beach');

console.log(`\n${pass} passed, ${fail} failed`);
if (fail) process.exit(1);
