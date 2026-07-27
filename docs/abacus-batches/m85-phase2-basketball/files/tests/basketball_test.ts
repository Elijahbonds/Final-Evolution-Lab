// node --experimental-strip-types --import ./tools/ts_resolve.mjs \
//   --import ./tools/fel_batch_alias.mjs tests/basketball_test.ts
//
// Phase 2. Two claims under test:
//
//   1. Your real vertical decides what you can do in the dunk contest — and
//      it does so WITHOUT locking most people out of the flagship mode.
//   2. The defender can be beaten by a move rather than only by speed, reads
//      a predictable player, and does it all deterministically.

import {
  RIM_HEIGHT_CM, MIN_CONTROL_CLEARANCE_CM, estimateStandingReach, rimClearanceCm,
  physicalTier, availableDunks, scoreCeiling, nextUnlock, athleteSummary,
  profileFromIrl, DUNK_LIBRARY, TIER_ORDER,
  type AthleteProfile,
} from '../core/DunkTiers.ts';
import {
  DefenseRead, TendencyTracker, defenderFor, COMMIT_MS, RECOVER_MS,
  type HandlerState,
} from '../core/DefenseRead.ts';
import { Rng } from '../../../m83-determinism-and-ghosts/files/core/Rng.ts';
import { PRQDrivenDDA } from '../../../m81-feel-foundation/files/core/DDA.ts';

let pass = 0, fail = 0;
const ok = (n: string, c: boolean, x = '') => { c ? (pass++, console.log(`  ok   ${n}`)) : (fail++, console.log(`  FAIL ${n} ${x}`)); };

// Three real bodies, spanning the range that actually installs this app.
// Fixtures are checked against the model rather than asserted from intuition.
// The first draft had a 188cm/76cm-vertical "serious athlete" expected to
// windmill — and the model correctly said one-hand. A 30-inch vertical at 6'2"
// IS a one-hand dunker; that honesty is the whole point, so the fixture moved,
// not the model.
const AVERAGE: AthleteProfile = { heightCm: 178, verticalCm: 45, hangTimeMs: 420 };
const ATHLETE: AthleteProfile = { heightCm: 188, verticalCm: 95, hangTimeMs: 700 };
const ELITE: AthleteProfile = { heightCm: 196, verticalCm: 96, hangTimeMs: 820 };

// ── the physics ──────────────────────────────────────────────────────────
ok('rim is 305cm', RIM_HEIGHT_CM === 305);
ok('reach estimate is ~1.325x height', estimateStandingReach(180) === 239);
ok('a measured reach overrides the estimate',
  rimClearanceCm({ ...AVERAGE, standingReachCm: 250 })
  !== rimClearanceCm(AVERAGE));

ok('an average adult does NOT clear the rim', rimClearanceCm(AVERAGE) < 0);
ok('a serious athlete does', rimClearanceCm(ATHLETE) > MIN_CONTROL_CLEARANCE_CM);
ok('an elite athlete clears it by a lot', rimClearanceCm(ELITE) > 40);

ok('height and vertical trade off — a taller body needs less spring',
  rimClearanceCm({ heightCm: 200, verticalCm: 50, hangTimeMs: 500 })
  > rimClearanceCm({ heightCm: 170, verticalCm: 60, hangTimeMs: 500 }));

// ── tiers ────────────────────────────────────────────────────────────────
ok('an average adult tops out at rim touch', physicalTier(AVERAGE) === 'rim_touch');
ok('a serious athlete reaches aerial or better',
  TIER_ORDER.indexOf(physicalTier(ATHLETE)) >= TIER_ORDER.indexOf('aerial'),
  physicalTier(ATHLETE));
ok('an elite athlete reaches elite', physicalTier(ELITE) === 'elite');
ok('someone who cannot get near the rim is no_rim',
  physicalTier({ heightCm: 160, verticalCm: 20, hangTimeMs: 250 }) === 'no_rim');

// THE MODEL THAT MAKES THIS INTERESTING
{
  const tall = { heightCm: 210, verticalCm: 62, hangTimeMs: 460 };    // clearance, no air
  const springy = { heightCm: 172, verticalCm: 110, hangTimeMs: 800 }; // air, less clearance
  const t = availableDunks(tall, 'true').map((d) => d.id);
  const s = availableDunks(springy, 'true').map((d) => d.id);
  ok('clearance and hang time are DIFFERENT axes, unlocking different dunks',
    t.join() !== s.join(), `${t.join()} / ${s.join()}`);
  ok('a tall low-hang player gets power but not a 360',
    t.includes('dunk_power') && !t.includes('dunk_360'));
  ok('a springy player gets the 360 despite less clearance',
    s.includes('dunk_360'));
  ok('a 360 needs LESS clearance than a windmill but more hang',
    DUNK_LIBRARY.find((d) => d.id === 'dunk_360').clearanceCm
      < DUNK_LIBRARY.find((d) => d.id === 'dunk_windmill').clearanceCm
    && DUNK_LIBRARY.find((d) => d.id === 'dunk_360').hangMs
      > DUNK_LIBRARY.find((d) => d.id === 'dunk_windmill').hangMs);
}

// ── the gate: nobody is locked out of the flagship by default ────────────
ok('THE PRODUCT CALL: arcade is the default and unlocks everything',
  availableDunks(AVERAGE).length === DUNK_LIBRARY.length);
ok('an average adult can throw a windmill in arcade',
  availableDunks(AVERAGE).some((d) => d.id === 'dunk_windmill'));
ok('true vertical gates honestly',
  availableDunks(AVERAGE, 'true').every((d) => d.tier === 'rim_touch'));
ok('assisted sits between the two',
  availableDunks(AVERAGE, 'assisted').length > availableDunks(AVERAGE, 'true').length
  && availableDunks(AVERAGE, 'assisted').length < DUNK_LIBRARY.length);
ok('assisted only withholds the elite tier',
  availableDunks(AVERAGE, 'assisted').every((d) => d.tier !== 'elite'));
ok('an elite athlete has everything in every mode',
  availableDunks(ELITE, 'true').length === DUNK_LIBRARY.length);

// ── scoring ceiling: arcade stays honest ────────────────────────────────
{
  const windmill = DUNK_LIBRARY.find((d) => d.id === 'dunk_windmill');
  ok('THE HONESTY MECHANISM: a real windmill scores higher than a borrowed one',
    scoreCeiling(ELITE, windmill) > scoreCeiling(AVERAGE, windmill));
  ok('but attempting above your tier is not a fail state',
    scoreCeiling(AVERAGE, windmill) >= 0.7);
  ok('the ceiling never runs away', scoreCeiling(ELITE, windmill) <= 1.15);
  const layup = DUNK_LIBRARY.find((d) => d.id === 'layup');
  ok('an easy dunk well within your range scores at or above par',
    scoreCeiling(ATHLETE, layup) >= 1);
}

// ── the retention loop ──────────────────────────────────────────────────
{
  const n = nextUnlock(AVERAGE);
  ok('there is always a next thing to train for', n !== null);
  // finger_roll, not the one-hander: an average adult cannot yet control a
  // finger roll either, and the next unlock must be the genuinely nearest one
  // or the number it quotes is a lie.
  ok('and it is the EASIEST locked dunk, not a random one',
    n.dunk.id === 'finger_roll', n.dunk.id);
  ok('it states the exact gap', n.needCm > 0);
  ok('in language a person can act on', /cm more vertical/.test(n.summary));
  ok('an elite athlete has nothing left to unlock', nextUnlock(ELITE) === null);

  // Plenty of clearance, not enough air: the shortfall must be reported as
  // the thing that is actually short.
  const nearly: AthleteProfile = { heightCm: 210, verticalCm: 62, hangTimeMs: 460 };
  const nn = nextUnlock(nearly);
  ok('a hang-time shortfall is reported as hang time, not vertical',
    /hang time/.test(nn.summary), nn.summary);
}

// ── the summary is honest without being discouraging ────────────────────
{
  const s = athleteSummary(AVERAGE);
  ok('it states the real shortfall', /below the rim/.test(s), s);
  ok('AND says the flagship is still playable',
    /Arcade/.test(s), 'telling someone they cannot dunk needs the other half');
  ok('an elite summary is a compliment, not a stat dump',
    /dunker/.test(athleteSummary(ELITE)));
}

// ── measurement failures degrade to playable, never to zero ─────────────
{
  const blind = profileFromIrl({ jumpHeightCm: null, hangTimeMs: null, confidence: 0.2 }, 178);
  ok('A FAILED MEASUREMENT DOES NOT REPORT YOU AS UNABLE TO JUMP',
    blind.verticalCm > 0 && blind.hangTimeMs > 0);
  ok('low confidence is not trusted even when values came back',
    profileFromIrl({ jumpHeightCm: 200, hangTimeMs: 2000, confidence: 0.1 }, 178).verticalCm === 45);
  ok('a confident measurement IS used',
    profileFromIrl({ jumpHeightCm: 81, hangTimeMs: 700, confidence: 0.9 }, 188).verticalCm === 81);
}

// ── the defender ────────────────────────────────────────────────────────
const handler = (o: Partial<HandlerState> = {}): HandlerState => ({
  lateralOffset: 0, lateralVelocity: 0, hoopDistance: 6,
  crossover: false, shooting: false, ...o,
});
const DT = 1 / 60;
const cfg = { aggression: 0.4, reactionSec: 0.15, readSkill: 0.6 };

{
  const d = new DefenseRead(new Rng(1), cfg);
  const out = d.update(handler(), DT);
  ok('a still handler is contained, not committed against', out.stance === 'contain');
  ok('containing is not "beaten"', !out.beaten);
}
{
  // The core mechanic: commit, get crossed, be beaten.
  const d = new DefenseRead(new Rng(7), { ...cfg, readSkill: 0 });  // always guesses wrong
  d.update(handler({ lateralVelocity: 2.5 }), DT);                  // threat → commit
  let beaten = false;
  for (let i = 0; i < 40 && !beaten; i++) {
    beaten = d.update(handler({ lateralVelocity: -2.5, lateralOffset: -1.2 }), DT).beaten;
  }
  ok('THE MECHANIC: a defender that commits the wrong way IS BEATEN', beaten);
}
{
  // Immediately after being beaten, not 40 frames later — RECOVER_MS is 380ms,
  // so by frame 40 it has already recovered. The first draft measured the
  // wrong moment and read a correct recovery as a missing one.
  const d = new DefenseRead(new Rng(7), { ...cfg, readSkill: 0 });
  d.update(handler({ lateralVelocity: 2.5 }), DT);
  let sawRecover = false;
  for (let i = 0; i < 12; i++) {
    const o = d.update(handler({ lateralVelocity: -2.5, lateralOffset: -1.2 }), DT);
    if (o.stance === 'recover') { sawRecover = true; ok('and it pays for it — reduced speed while recovering', Math.abs(o.moveLateral) < 1); break; }
  }
  ok('recovery actually happens', sawRecover);
}
{
  // Seed-ROBUST. readSkill 1 still caps at a 0.92 correct-guess rate — a
  // defender that reads perfectly would be unbeatable and therefore not a
  // game. So assert the rate across many seeds instead of trusting one.
  let correct = 0;
  const N = 60;
  for (let seed = 0; seed < N; seed++) {
    const d = new DefenseRead(new Rng(seed), { ...cfg, readSkill: 1 });
    d.update(handler({ lateralVelocity: 2.5 }), DT);
    const held = d.update(handler({ lateralVelocity: 2.5, lateralOffset: 1.0 }), DT);
    if (!held.beaten && Math.abs(held.moveLateral) > 1) correct++;
  }
  ok('a maximally skilled defender reads it most of the time', correct > N * 0.7, `${correct}/${N}`);
  ok('but NOT every time — a perfect read is unbeatable and unbeatable is not a game',
    correct < N);

  const d = new DefenseRead(new Rng(3), { ...cfg, readSkill: 1 });
  d.update(handler({ lateralVelocity: 2.5 }), DT);
  ok('it explains itself — debuggable AI is maintainable AI',
    d.update(handler({ lateralVelocity: 2.5, lateralOffset: 1.0 }), DT).reason.length > 0);
}
{
  const d = new DefenseRead(new Rng(5), cfg);
  d.update(handler({ lateralVelocity: 2.5 }), DT);
  let ms = 0;
  while (ms < COMMIT_MS + 100) { d.update(handler({ lateralVelocity: 2.5, lateralOffset: 0.9 }), DT); ms += DT * 1000; }
  // Stop feeding it a threat — otherwise it correctly re-commits the instant
  // the old commitment expires, and the test reads a working defender as a
  // stuck one.
  let settled = 'commit';
  for (let i = 0; i < 30; i++) settled = d.update(handler(), DT).stance;
  ok('a commitment EXPIRES — a defender frozen forever is broken, not hard',
    settled === 'contain', settled);
}

// ── tendency reading ────────────────────────────────────────────────────
{
  const t = new TendencyTracker();
  ok('no read from nothing', t.bias === 0);
  t.record(1); t.record(1);
  ok('AND NO READ FROM TWO SAMPLES — being read in the first ten seconds is '
    + 'what makes people quit a mode', t.bias === 0);
  t.record(1);
  ok('three samples is a read', t.bias === 1);
  ok('and a one-sided player is flagged predictable', t.isPredictable);
  t.record(-1); t.record(-1); t.record(-1);
  ok('mixing it up neutralises the read', Math.abs(t.bias) < 0.4);
  for (let i = 0; i < 20; i++) t.record(1);
  ok('the window is bounded — it reads a habit, it does not hold a grudge',
    t.samples <= 8);
}
{
  const d = new DefenseRead(new Rng(11), cfg);
  ok('no scouting report before there is a read', d.scoutingReport === null);
  for (let i = 0; i < 6; i++) d.tendencies.record(1);
  ok('a predictable player is TOLD, so being read is a lesson not a mystery',
    /Go left/.test(d.scoutingReport ?? ''));
}

// ── determinism: the reason this replaces DefenderBrain ─────────────────
{
  const run = () => {
    const d = new DefenseRead(new Rng(999), cfg);
    const out: string[] = [];
    for (let i = 0; i < 200; i++) {
      const h = handler({
        lateralVelocity: Math.sin(i / 7) * 3,
        lateralOffset: Math.sin(i / 9) * 1.5,
        crossover: i % 31 === 0,
      });
      out.push(d.update(h, DT).stance);
    }
    return out.join();
  };
  ok('THE REPLAY FIX: two runs on one seed are identical — the old '
    + 'DefenderBrain called Math.random() per frame and could never replay',
    run() === run());
}

// ── PRQ reaches the court ───────────────────────────────────────────────
{
  const rookie = defenderFor(new Rng(1), new PRQDrivenDDA({ playerPRQ: 20, modeId: 'onevone' }));
  const legend = defenderFor(new Rng(1), new PRQDrivenDDA({ playerPRQ: 95, modeId: 'onevone' }));
  let rookieCommits = 0; let legendCommits = 0;
  for (let i = 0; i < 300; i++) {
    const h = handler({ lateralVelocity: Math.sin(i / 5) * 3, lateralOffset: Math.sin(i / 5) * 1.4 });
    if (rookie.update(h, DT).stance.startsWith('commit')) rookieCommits++;
    if (legend.update(h, DT).stance.startsWith('commit')) legendCommits++;
  }
  ok('a high-PRQ player faces a defender that commits more confidently',
    legendCommits >= rookieCommits, `${legendCommits} vs ${rookieCommits}`);
}

console.log(`\n${pass} passed, ${fail} failed`);
if (fail) process.exit(1);
