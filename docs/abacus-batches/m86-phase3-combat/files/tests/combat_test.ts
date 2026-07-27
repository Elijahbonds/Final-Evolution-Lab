// node --experimental-strip-types --import ./tools/ts_resolve.mjs \
//   --import ./tools/fel_batch_alias.mjs tests/combat_test.ts
//
// Phase 3. The claim: combat has a neutral game — spacing and whiff punish —
// rather than combo memorisation.
//
// A fighting game's depth lives entirely in relationships between numbers, and
// those relationships are invisible to playtesting until someone has already
// found the degenerate strategy. So they are asserted here: that whiffing
// costs you, that no attack is always correct, that blocking is not free, and
// that a parry beats a block.

import {
  KARATE_FRAMES, STAFF_FRAMES, IDLE_STATE, FRAME_MS,
  COMBAT_REACTION_FACTOR, MIN_REACTION_FRAMES, MAX_REACTION_FRAMES,
  canAct, isPunishable, punishWindow, punishLands, startAttack, tickAttack,
  enterRecovery, resolveExchange, spacingZone, idealSpacing, maxReach,
  NeutralBrain, rivalFor, coachingNote,
  type AttackState, type NeutralInput,
} from '../core/NeutralGame.ts';
import { Rng } from '../../../m83-determinism-and-ghosts/files/core/Rng.ts';
import { PRQDrivenDDA } from '../../../m81-feel-foundation/files/core/DDA.ts';

let pass = 0, fail = 0;
const ok = (n: string, c: boolean, x = '') => { c ? (pass++, console.log(`  ok   ${n}`)) : (fail++, console.log(`  FAIL ${n} ${x}`)); };

// ── frame data relationships: the design, asserted ──────────────────────
{
  const { jab, kick, heavy } = KARATE_FRAMES;
  ok('a jab is the fastest thing you own', jab.startup < kick.startup && kick.startup < heavy.startup);
  ok('THE SAFETY LADDER: jab is plus, kick is slightly minus, heavy is deeply minus',
    jab.onBlock > 0 && kick.onBlock < 0 && heavy.onBlock < kick.onBlock);
  ok('recovery scales with commitment', jab.recovery < kick.recovery && kick.recovery < heavy.recovery);
  ok('NO ATTACK IS ALWAYS CORRECT: the heavy reaches no further than the kick',
    heavy.range <= kick.range,
    'if the biggest attack also had the most reach, nothing else would ever be thrown');
  ok('a heavy is worth more when it lands', heavy.onHit > jab.onHit);
}
{
  ok('staff outranges karate at every tool',
    Object.keys(KARATE_FRAMES).every((k) => STAFF_FRAMES[k].range > KARATE_FRAMES[k].range));
  ok('and pays for it in startup',
    Object.keys(KARATE_FRAMES).every((k) => STAFF_FRAMES[k].startup > KARATE_FRAMES[k].startup));
  ok('and in recovery — reach is not free',
    Object.keys(KARATE_FRAMES).every((k) => STAFF_FRAMES[k].recovery > KARATE_FRAMES[k].recovery));
  ok('THE MATCHUP: staff wins at range, karate wins inside',
    maxReach(STAFF_FRAMES) > maxReach(KARATE_FRAMES)
    && KARATE_FRAMES.jab.startup < STAFF_FRAMES.jab.startup);
}
ok('a frame is 16.67ms — meaningful only because M83 fixed the tick',
  Math.abs(FRAME_MS - 16.667) < 0.01);

// ── the attack state machine ────────────────────────────────────────────
{
  ok('an idle fighter can act', canAct(IDLE_STATE));
  const s = startAttack(IDLE_STATE, 'heavy', KARATE_FRAMES.heavy);
  ok('starting an attack enters startup', s.phase === 'startup');
  ok('with the right frame count', s.framesLeft === KARATE_FRAMES.heavy.startup);
  ok('you cannot act mid-attack', !canAct(s));
  ok('and you cannot start a second one', startAttack(s, 'jab', KARATE_FRAMES.jab) === null);
}
{
  let s: AttackState = startAttack(IDLE_STATE, 'jab', KARATE_FRAMES.jab);
  let activeFired = 0;
  for (let i = 0; i < KARATE_FRAMES.jab.startup; i++) {
    s = tickAttack(s, () => { activeFired++; });
  }
  ok('the hitbox goes live exactly once', activeFired === 1,
    'firing every active frame is how an attack hits three times');
  ok('and the state is active', s.phase === 'active');
}
{
  let s = enterRecovery(startAttack(IDLE_STATE, 'heavy', KARATE_FRAMES.heavy), KARATE_FRAMES.heavy);
  ok('recovery is punishable', isPunishable(s));
  ok('and the window is the recovery length', punishWindow(s) === KARATE_FRAMES.heavy.recovery);
  for (let i = 0; i < KARATE_FRAMES.heavy.recovery; i++) s = tickAttack(s);
  ok('recovery ends', s.phase === 'idle' && canAct(s));
}

// ── THE CORE CLAIM: whiffing costs you ──────────────────────────────────
{
  const attacker = startAttack(IDLE_STATE, 'heavy', KARATE_FRAMES.heavy);
  const ex = resolveExchange(attacker, IDLE_STATE, KARATE_FRAMES.heavy, 'whiff');
  ok('THE WHOLE FILE: a whiffed heavy puts you in recovery', ex.attacker.phase === 'recovery');
  ok('and it is punishable', isPunishable(ex.attacker));
  ok('for 24 frames — 400ms of being unable to defend',
    punishWindow(ex.attacker) === 24);
  ok('the defender is untouched', ex.defender.phase === 'idle');
  ok('and the system explains itself', /punishable/.test(ex.summary));
}
{
  const w = punishWindow(resolveExchange(
    startAttack(IDLE_STATE, 'heavy', KARATE_FRAMES.heavy), IDLE_STATE, KARATE_FRAMES.heavy, 'whiff',
  ).attacker);
  ok('a jab punishes a whiffed heavy', punishLands(w, KARATE_FRAMES.jab));
  ok('so does another heavy — a big mistake deserves a big answer',
    punishLands(w, KARATE_FRAMES.heavy));

  const jw = punishWindow(resolveExchange(
    startAttack(IDLE_STATE, 'jab', KARATE_FRAMES.jab), IDLE_STATE, KARATE_FRAMES.jab, 'whiff',
  ).attacker);
  ok('but a whiffed JAB is only punishable by a jab',
    punishLands(jw, KARATE_FRAMES.jab) && !punishLands(jw, KARATE_FRAMES.heavy),
    'choosing the wrong punish means YOU whiff and get punished back');
}

// ── frame advantage on block ────────────────────────────────────────────
{
  const ex = resolveExchange(
    startAttack(IDLE_STATE, 'jab', KARATE_FRAMES.jab), IDLE_STATE, KARATE_FRAMES.jab, 'blocked');
  ok('a plus-on-block jab keeps the attacker free', canAct(ex.attacker));
  ok('and locks the defender in blockstun', ex.defender.phase === 'blockstun');
  ok('so pressure continues', /pressure/.test(ex.summary));
}
{
  const ex = resolveExchange(
    startAttack(IDLE_STATE, 'heavy', KARATE_FRAMES.heavy), IDLE_STATE, KARATE_FRAMES.heavy, 'blocked');
  ok('BLOCKING IS NOT FREE FOR THE ATTACKER: a blocked heavy is minus 12',
    ex.attacker.advantage === -12);
  ok('the attacker cannot act', !canAct(ex.attacker));
  ok('and IS punishable', isPunishable(ex.attacker) && punishWindow(ex.attacker) === 12);
  ok('the defender is free immediately', canAct(ex.defender));
  ok('a jab punishes it', punishLands(punishWindow(ex.attacker), KARATE_FRAMES.jab));
  ok('a heavy does NOT — the window is too short',
    !punishLands(punishWindow(ex.attacker), KARATE_FRAMES.heavy));
}
{
  // Frame disadvantage must actually tick away, or a fighter is stuck forever.
  let s = resolveExchange(
    startAttack(IDLE_STATE, 'heavy', KARATE_FRAMES.heavy), IDLE_STATE, KARATE_FRAMES.heavy, 'blocked').attacker;
  for (let i = 0; i < 12; i++) s = tickAttack(s);
  ok('frame disadvantage expires', canAct(s));
}

// ── parry beats block ───────────────────────────────────────────────────
{
  const blocked = resolveExchange(
    startAttack(IDLE_STATE, 'kick', KARATE_FRAMES.kick), IDLE_STATE, KARATE_FRAMES.kick, 'blocked');
  const parried = resolveExchange(
    startAttack(IDLE_STATE, 'kick', KARATE_FRAMES.kick), IDLE_STATE, KARATE_FRAMES.kick, 'parried');
  ok('A PARRY IS WORTH FAR MORE THAN A BLOCK',
    punishWindow(parried.attacker) > punishWindow(blocked.attacker) * 3,
    'otherwise blocking is the safe default and the parry window is decoration');
  ok('a parry punishes even a safe attack',
    punishLands(punishWindow(parried.attacker), KARATE_FRAMES.heavy));
}
{
  const hit = resolveExchange(
    startAttack(IDLE_STATE, 'heavy', KARATE_FRAMES.heavy), IDLE_STATE, KARATE_FRAMES.heavy, 'hit');
  ok('a clean hit leaves the attacker free', canAct(hit.attacker));
  ok('and the defender in hitstun', hit.defender.phase === 'hitstun');
  ok('hitstun is punishable', isPunishable(hit.defender));
}

// ── spacing ─────────────────────────────────────────────────────────────
ok('far apart is out of range', spacingZone(5, 1.9, 1.9) === 'out');
ok('THE ZONE THAT MATTERS: reach them without being reachable is the tip',
  spacingZone(2.4, 2.8, 1.9) === 'tip');
ok('both in range is threat', spacingZone(1.8, 1.9, 1.9) === 'threat');
ok('closed all the way down is inside', spacingZone(0.8, 2.8, 1.9) === 'inside');
ok('a staff fighter has a tip against karate',
  idealSpacing(maxReach(STAFF_FRAMES), maxReach(KARATE_FRAMES)) !== null);
ok('but karate has NO tip against staff — it must get inside',
  idealSpacing(maxReach(KARATE_FRAMES), maxReach(STAFF_FRAMES)) === null,
  'that asymmetry IS the matchup');
{
  const ideal = idealSpacing(2.8, 1.9);
  ok('ideal spacing sits between the two reaches', ideal > 1.9 && ideal < 2.8);
  ok('and standing there is the tip', spacingZone(ideal, 2.8, 1.9) === 'tip');
}
ok('equal reach means no free distance', idealSpacing(1.9, 1.9) === null);

// ── the rival plays neutral ─────────────────────────────────────────────
const cfg = { skill: 0.8, reactionFrames: 6, aggression: 0.5 };
const input = (o: Partial<NeutralInput> = {}): NeutralInput => ({
  distance: 2, opponent: IDLE_STATE, self: IDLE_STATE, ...o,
});
/** Let the reaction debt drain before measuring a decision. */
const settle = (b: NeutralBrain, i: NeutralInput, n = 10) => {
  let d = b.decide(i);
  for (let k = 0; k < n; k++) d = b.decide(i);
  return d;
};

{
  const b = new NeutralBrain(new Rng(1), cfg);
  const whiffed = enterRecovery(
    startAttack(IDLE_STATE, 'heavy', KARATE_FRAMES.heavy), KARATE_FRAMES.heavy);
  const d = settle(b, input({ distance: 1.5, opponent: whiffed }));
  ok('IT PUNISHES A WHIFF', d.attack !== null, d.reason);
  ok('and says so', /punish/.test(d.reason));
}
{
  // Only with an attack that actually fits the window.
  const b = new NeutralBrain(new Rng(2), { ...cfg, skill: 1 });
  const smallWindow: AttackState = { phase: 'recovery', framesLeft: 5, attackId: 'jab', advantage: 0 };
  const d = settle(b, input({ distance: 1.5, opponent: smallWindow }));
  ok('a 5-frame window is punished with a jab, not a heavy',
    d.attack === null || d.attack === 'jab', d.attack ?? 'none');
}
{
  const b = new NeutralBrain(new Rng(3), cfg);
  const d = settle(b, input({ distance: 6 }));
  ok('it closes from out of range', d.approach === 1, d.reason);
}
{
  const b = new NeutralBrain(new Rng(4), { ...cfg, skill: 1, aggression: 0 }, STAFF_FRAMES);
  const ideal = idealSpacing(maxReach(STAFF_FRAMES), maxReach(KARATE_FRAMES));
  const d = settle(b, input({ distance: ideal }));
  ok('a staff rival HOLDS the tip rather than closing', d.approach === 0, d.reason);
  ok('and knows why', /tip/.test(d.reason));
}
{
  const b = new NeutralBrain(new Rng(5), { ...cfg, skill: 1 }, STAFF_FRAMES);
  const d = settle(b, input({ distance: 0.9 }));
  ok('a skilled staff rival BACKS OUT when you get inside', d.approach === -1, d.reason);
}
{
  const b = new NeutralBrain(new Rng(6), { ...cfg, skill: 0 }, STAFF_FRAMES);
  const d = settle(b, input({ distance: 0.9 }));
  ok('an unskilled one panics and swings instead', d.attack !== null, d.reason);
}
{
  const b = new NeutralBrain(new Rng(7), cfg);
  const busy: AttackState = { phase: 'startup', framesLeft: 8, attackId: 'heavy', advantage: 0 };
  const d = b.decide(input({ self: busy }));
  ok('a busy fighter does nothing', d.attack === null && d.approach === 0);
  ok('and reports why', /busy/.test(d.reason));
}
{
  // The reaction delay must be real, or a whiff is never safe.
  const b = new NeutralBrain(new Rng(8), { ...cfg, reactionFrames: 20 });
  const whiffed = enterRecovery(
    startAttack(IDLE_STATE, 'heavy', KARATE_FRAMES.heavy), KARATE_FRAMES.heavy);
  const first = b.decide(input({ distance: 1.5, opponent: whiffed }));
  ok('IT CANNOT PUNISH INSTANTLY — a whiff at the edge of its vision is safe',
    first.attack === null, first.reason);
}

// ── determinism ─────────────────────────────────────────────────────────
{
  const run = () => {
    const b = new NeutralBrain(new Rng(4242), cfg);
    const out: string[] = [];
    for (let i = 0; i < 300; i++) {
      out.push(b.decide(input({
        distance: 1.2 + Math.sin(i / 11) * 1.8,
        opponent: i % 23 === 0
          ? { phase: 'recovery', framesLeft: 20, attackId: 'heavy', advantage: 0 }
          : IDLE_STATE,
      })).reason);
    }
    return out.join('|');
  };
  ok('THE REPLAY FIX: two runs on one seed are identical — RivalFightBrain '
    + 'called Math.random() four times a frame and could never replay',
    run() === run());
}

// ── PRQ decides how well it plays ───────────────────────────────────────
{
  // One whiff, held open long enough to be perceivable, repeated across
  // independent trials.
  //
  // The first draft flipped the opponent's phase every three ticks while the
  // rival's reaction time was thirty frames, and then read zero punishes as a
  // bug. It was not: a fighter cannot react to something changing faster than
  // it can see. Correct model, unrealistic scenario — the scenario moved.
  // Punish attempts within the window a whiff ACTUALLY opens — 24 frames of
  // heavy recovery, not an artificially long one.
  const punishRate = (prq: number, trials = 60) => {
    let punished = 0;
    for (let t = 0; t < trials; t++) {
      const b = rivalFor(new Rng(1000 + t), new PRQDrivenDDA({ playerPRQ: prq, modeId: 'karate-vs' }));
      const whiffed = enterRecovery(
        startAttack(IDLE_STATE, 'heavy', KARATE_FRAMES.heavy), KARATE_FRAMES.heavy);
      let hit = false;
      for (let i = 0; i < KARATE_FRAMES.heavy.recovery && !hit; i++) {
        if (/punish/.test(b.decide(input({ distance: 1.5, opponent: whiffed })).reason)) hit = true;
      }
      if (hit) punished++;
    }
    return punished;
  };

  // THE REGRESSION GUARD FOR A REAL BUG.
  //
  // Using dda.aiReactionSpeed() directly gives 31-44 frames, which is LONGER
  // than the 24 frames a whiffed heavy opens — so no rival at any PRQ could
  // ever punish anything, silently deleting the mechanic this whole file adds.
  // DDA measures a basketball DECISION latency; combat needs a PERCEPTION
  // latency. These assertions stop that scale mismatch coming back.
  const reactionFrames = (prq: number) => {
    const raw = new PRQDrivenDDA({ playerPRQ: prq, modeId: 'karate-vs' }).aiReactionSpeed(0, 0)
      * 60 * COMBAT_REACTION_FACTOR;
    return Math.round(Math.min(MAX_REACTION_FRAMES, Math.max(MIN_REACTION_FRAMES, raw)));
  };

  ok('EVERY tier reacts inside the window a whiff opens, or the mechanic is dead',
    reactionFrames(95) < KARATE_FRAMES.heavy.recovery
    && reactionFrames(20) < KARATE_FRAMES.heavy.recovery,
    `${reactionFrames(95)} / ${reactionFrames(20)} frames vs ${KARATE_FRAMES.heavy.recovery}`);
  ok('reaction times land in the human range — 100ms to 500ms',
    reactionFrames(95) >= MIN_REACTION_FRAMES && reactionFrames(20) <= MAX_REACTION_FRAMES);
  ok('a high-PRQ player faces the faster eyes',
    reactionFrames(95) <= reactionFrames(20),
    `${reactionFrames(95)} vs ${reactionFrames(20)}`);

  const legend = punishRate(95);
  const rookie = punishRate(20);
  ok('a legend-tier rival punishes more of your whiffs than a rookie-tier one',
    legend > rookie, `${legend} vs ${rookie} of 60`);
  ok('but a rookie-tier rival still punishes SOMETIMES — a free mistake is '
    + 'still a mistake', rookie > 0, `${rookie}`);
  // A legend punishing EVERY whiffed heavy thrown inside its range is correct,
  // not oppressive — that is what elite play looks like and it is precisely
  // what makes spacing matter. An earlier assertion here wanted the punish to
  // be unreliable, which would have made whiffing a dice roll instead of a
  // mistake. What must stay true is that DISTANCE, not luck, is the thing that
  // makes a whiff safe.
  ok('a whiff inside their range is reliably punished by an elite rival',
    legend >= 55, `${legend}/60`);

  const outOfRange = (() => {
    let punished = 0;
    for (let t = 0; t < 60; t++) {
      const b = rivalFor(new Rng(2000 + t), new PRQDrivenDDA({ playerPRQ: 95, modeId: 'karate-vs' }));
      const whiffed = enterRecovery(
        startAttack(IDLE_STATE, 'heavy', KARATE_FRAMES.heavy), KARATE_FRAMES.heavy);
      for (let i = 0; i < KARATE_FRAMES.heavy.recovery; i++) {
        // 4.5m: far outside every karate tool.
        if (/punishing/.test(b.decide(input({ distance: 4.5, opponent: whiffed })).reason)) { punished++; break; }
      }
    }
    return punished;
  })();
  ok('THE LESSON THE MODE TEACHES: the same whiff at range is untouchable',
    outOfRange === 0, `${outOfRange}/60`);
}

// ── coaching ────────────────────────────────────────────────────────────
ok('no advice from too small a sample',
  coachingNote({ whiffs: 1, punishesTaken: 0, blocked: 1, landed: 1 }) === null);
ok('a whiff-heavy round is named as a spacing problem',
  /too far out/.test(coachingNote({ whiffs: 8, punishesTaken: 2, blocked: 2, landed: 3 }) ?? ''));
ok('repeated punishes are named as unsafe attacks',
  /unsafe/.test(coachingNote({ whiffs: 1, punishesTaken: 5, blocked: 3, landed: 4 }) ?? ''));
ok('being read is named as predictability',
  /reading your attacks/.test(coachingNote({ whiffs: 1, punishesTaken: 0, blocked: 9, landed: 2 }) ?? ''));
ok('a clean round gets no lecture',
  coachingNote({ whiffs: 1, punishesTaken: 0, blocked: 2, landed: 8 }) === null,
  'a coach that always has notes is one people stop reading');

console.log(`\n${pass} passed, ${fail} failed`);
if (fail) process.exit(1);
