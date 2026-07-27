// node --experimental-strip-types --import ./tools/ts_resolve.mjs tests/modekit_test.ts
//
// The integration layer, tested.
//
// That phrase should be unremarkable and in this project it is not. Every
// piece of wiring shipped so far has been untestable by construction — it
// imported Babylon, so it could only be verified by deploying it, which is why
// `CameraStandoff` sat unintegrated for six batches without anyone knowing.
//
// ModeKit imports no Babylon and takes only plain numbers, so the wiring
// itself can be asserted. These tests are the difference between "the adapter
// should compose the five subsystems correctly" and "it does".

// Dependencies are imported from the batches that SHIP them, not copied in.
// A copy would hand Abacus two versions of MotionModel and let them drift —
// the same failure mode as the PRQ weight tables in M82. It also means this
// suite proves the batches COMPOSE, which is the actual claim of Phase 1.
import { ModeKit, MIGRATION_MARKERS } from '../core/ModeKit.ts';
import { a11y, DEFAULT_A11Y } from '../../../m82-accessibility-and-prq/files/core/a11y.ts';
import { captions } from '../../../m82-accessibility-and-prq/files/core/captions.ts';
import { FIXED_DT } from '../../../m83-determinism-and-ghosts/files/core/FixedStep.ts';
import { IDLE_INTENT } from '../../../m83-determinism-and-ghosts/files/core/Replay.ts';
import { GhostSource } from '../../../m83-determinism-and-ghosts/files/core/GhostSource.ts';

let pass = 0, fail = 0;
const ok = (n: string, c: boolean, x = '') => { c ? (pass++, console.log(`  ok   ${n}`)) : (fail++, console.log(`  FAIL ${n} ${x}`)); };
const near = (a: number, b: number, eps = 1e-9) => Math.abs(a - b) < eps;

type Intent = typeof IDLE_INTENT;
const intent = (o: Partial<Intent> = {}): Intent => ({ ...IDLE_INTENT, ...o });

/** Reset the module-level stores between blocks. */
const resetGlobals = () => { a11y.set({ ...DEFAULT_A11Y }, { getItem: () => null, setItem: () => {} }); captions.clear(); };

// ── construction ─────────────────────────────────────────────────────────
{
  const kit = ModeKit.neutral({ modeId: 'dunk' });
  ok('neutral() builds without a network', kit.dda.playerPRQ === 75);
  ok('it knows its mode', kit.modeId === 'dunk');
  ok('it starts at tick 0', kit.tick === 0);
  ok('and at rest', kit.motion.speed === 0);
  kit.dispose();
}
{
  const okFetch = (async () => ({ ok: true, json: async () => ({ overall_score: 92 }) })) as unknown as typeof fetch;
  const kit = await ModeKit.create({ modeId: 'karate', fetchImpl: okFetch });
  ok('create() reads real PRQ', kit.dda.playerPRQ === 92);
  ok('and derives a tier from it', kit.dda.tier === 'LEGENDARY');
  kit.dispose();
}
{
  const dead = (async () => { throw new Error('offline'); }) as unknown as typeof fetch;
  const kit = await ModeKit.create({ modeId: 'karate', fetchImpl: dead });
  ok('A GUEST OFFLINE STILL GETS A MATCH, at neutral difficulty',
    kit.dda.playerPRQ === 75);
  kit.dispose();
}

// ── the render loop is deterministic through the kit ─────────────────────
{
  const kit = ModeKit.neutral({ modeId: 'dunk' });
  let seen: number[] = [];
  let ticks = 0;
  for (const f of [1 / 60, 1 / 30, 1 / 144, 0.05, 1 / 60]) {
    kit.frame(f, (dt) => { seen.push(dt); ticks++; });
  }
  ok('the mode only ever sees the fixed dt', seen.every((d) => d === FIXED_DT));
  ok('tick count matches what ran', kit.tick === ticks);
  ok('alpha stays in range', kit.alpha >= 0 && kit.alpha < 1);
  kit.dispose();
}
{
  // Two kits on one seed must produce one match, or ghosts mean nothing.
  const a = ModeKit.neutral({ modeId: 'dunk', seed: 777 });
  const b = ModeKit.neutral({ modeId: 'dunk', seed: 777 });
  ok('two kits on one seed draw identically',
    Array.from({ length: 20 }, () => a.sim.rng.next()).join()
    === Array.from({ length: 20 }, () => b.sim.rng.next()).join());
  a.dispose(); b.dispose();
}

// ── movement: the always-sprinting bug must not come back ────────────────
{
  const kit = ModeKit.neutral({ modeId: 'onevone' });
  for (let i = 0; i < 60; i++) kit.move(intent({ moveY: 1, sprint: false }), 0);
  const walk = kit.motion.speed;
  ok('THE REGRESSION GUARD: full stick with no sprint button WALKS',
    near(walk, 0.45, 1e-6), `speed ${walk}`);

  for (let i = 0; i < 60; i++) kit.move(intent({ moveY: 1, sprint: true }), 0);
  ok('sprint reaches full speed', near(kit.motion.speed, 1, 1e-6));
  kit.dispose();
}
{
  const kit = ModeKit.neutral({ modeId: 'onevone' });
  for (let i = 0; i < 60; i++) kit.move(intent({ moveX: 1, moveY: 1, sprint: true }), 0);
  const diag = kit.motion.speed;
  const kit2 = ModeKit.neutral({ modeId: 'onevone' });
  for (let i = 0; i < 60; i++) kit2.move(intent({ moveY: 1, sprint: true }), 0);
  ok('diagonals are not faster', near(diag, kit2.motion.speed, 1e-6));
  kit.dispose(); kit2.dispose();
}
{
  const kit = ModeKit.neutral({ modeId: 'onevone' });
  for (let i = 0; i < 60; i++) kit.move(intent({ moveY: 1, sprint: true }), 90);
  ok('movement is camera-relative', near(kit.motion.dirX, 1, 1e-6));
  const v = kit.velocity(8);
  ok('velocity scales by top speed and the fixed dt',
    near(v.x, 1 * 8 * FIXED_DT, 1e-6) && near(v.z, 0, 1e-9));
  ok('facingRad converts for Babylon', near(kit.facingRad, Math.PI / 2, 1e-6));
  kit.dispose();
}

// ── window(): DDA and assist composed, in the right order ────────────────
{
  resetGlobals();
  const kit = ModeKit.neutral({ modeId: 'baseball' });
  const base = kit.window(100);
  ok('a level match at neutral PRQ is close to the base window',
    Math.abs(base - 100 * kit.dda.qteWindowScale(0, 0, 10)) < 1e-9);

  a11y.set({ assist: 'full' }, { getItem: () => null, setItem: () => {} });
  const assisted = kit.window(100);
  ok('THE COMPOSITION: assist widens the window on top of DDA',
    assisted > base, `${base} → ${assisted}`);
  ok('and it is exactly 1.6x, not a replacement', near(assisted, base * 1.6, 1e-9));

  const losing = kit.window(100, 0, 9, 10);
  ok('losing badly widens it further still', losing > assisted);
  resetGlobals();
  kit.dispose();
}
{
  resetGlobals();
  const kit = ModeKit.neutral({ modeId: 'karate' });
  const plain = kit.reactionDelay();
  a11y.set({ assist: 'full' }, { getItem: () => null, setItem: () => {} });
  ok('assist also buys reaction time — a wider window does not help against '
    + 'an opponent you cannot perceive', kit.reactionDelay() > plain);
  resetGlobals();
  kit.dispose();
}

// ── accessibility passes through, live ───────────────────────────────────
{
  resetGlobals();
  const kit = ModeKit.neutral({ modeId: 'dunk' });
  ok('shake is unmodified by default', kit.shake(0.5) === 0.5);
  a11y.set({ reducedMotion: true }, { getItem: () => null, setItem: () => {} });
  ok('A SETTINGS CHANGE APPLIES WITHOUT RESTARTING THE MODE', kit.shake(0.5) === 0);
  resetGlobals();
  ok('and it goes back', kit.shake(0.5) === 0.5);

  ok('a slow flash is allowed', kit.flash(2));
  ok('SEIZURE RISK: above 3Hz is blocked', !kit.flash(8));
  kit.dispose();
}
{
  resetGlobals();
  const kit = ModeKit.neutral({ modeId: 'karate' });
  kit.cue('PARRY', 'critical');
  ok('captions are silent while disabled', captions.visible().length === 0);

  a11y.set({ captions: true }, { getItem: () => null, setItem: () => {} });
  let played = false;
  kit.sound(() => { played = true; }, 'BUZZER', 'critical');
  ok('sound() plays the audio', played);
  ok('and captions it in the same call', captions.visible().some((c) => c.text === 'BUZZER'));
  resetGlobals();
  kit.dispose();
}

// ── scoring ──────────────────────────────────────────────────────────────
{
  const kit = ModeKit.neutral({ modeId: 'football' });
  ok('the kit knows what the mode is worth', kit.prqWeight === 1.5);
  const shop = ModeKit.neutral({ modeId: 'market_browse' });
  ok('and that a shop is worth exactly nothing', shop.prqWeight === 0);
  ok('so a shop visit estimates zero PRQ', shop.estimatedPrq(999) === 0);
  kit.dispose(); shop.dispose();
}

// ── finish(): one exit path ──────────────────────────────────────────────
{
  const kit = ModeKit.neutral({ modeId: 'dunk', record: true, seed: 4242 });
  for (let i = 0; i < 120; i++) {
    kit.frame(FIXED_DT, () => {}, () => intent({ moveY: 1 }));
  }
  const replay = kit.finish(31, 'WIN');
  ok('finishing yields a ghost recording', replay !== null);
  ok('with the right tick count', replay.header.totalTicks === 120);
  ok('DOUBLE-FINISH IS A NO-OP — a mode ending on both a timer and a score '
    + 'condition must not double-report', kit.finish(31, 'WIN') === null);

  const ghost = GhostSource.from(replay, 'dunk', FIXED_DT);
  ok('and the recording is immediately playable as a ghost', ghost !== null);
  ok('carrying the PRQ it was recorded at', ghost.recordedPRQ === 75);
  kit.dispose();
}
{
  const kit = ModeKit.neutral({ modeId: 'dunk' });
  kit.frame(FIXED_DT, () => {});
  ok('recording is off by default', kit.finish(1, 'WIN') === null);
  kit.dispose();
}

// ── the migration contract ───────────────────────────────────────────────
ok('the migration markers name every subsystem a mode must adopt',
  MIGRATION_MARKERS.length === 5);
ok('and each maps to a real method on the kit',
  MIGRATION_MARKERS.every((m) => {
    const method = m.replace('kit.', '');
    return typeof (ModeKit.neutral({ modeId: 'x' }) as unknown as Record<string, unknown>)[method] === 'function';
  }),
  'a marker with no method is a checklist item nobody can satisfy');

console.log(`\n${pass} passed, ${fail} failed`);
if (fail) process.exit(1);
