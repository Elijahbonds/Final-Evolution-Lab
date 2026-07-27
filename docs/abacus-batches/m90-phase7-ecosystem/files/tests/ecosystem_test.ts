// node --experimental-strip-types --import ./tools/ts_resolve.mjs \
//   --import ./tools/fel_batch_alias.mjs tests/ecosystem_test.ts
//
// Phase 7. Two claims:
//
//   1. A score is believed in proportion to the evidence for it, and real
//      money requires the server to have re-run the match itself.
//   2. XP arrives somewhere, and nothing behind the paywall touches gameplay.

import {
  TRUST_ORDER, PAYOUT_BY_TRUST, MODE_BOUNDS, CASH_ELIGIBLE_MODES,
  atLeast, boundsFor, plausibilityFlags, replayFlags, assessReceipt, cashEligible,
  type ClaimedReceipt,
} from '../core/ReceiptIntegrity.ts';
import {
  XP_CAP_PER_SESSION, XP_MIN_PER_SESSION, TIERS_PER_SEASON, XP_PER_TIER,
  OBJECTIVE_XP, PayToWinError, MAX_LEVEL,
  sessionXp, xpForLevel, totalXpForLevel, levelFromXp, buildSeason,
  tierFromSeasonXp, claimable, retroactiveGrant, assertNotPayToWin,
  pickObjectives, seasonFeasibility, nextMilestone,
  type Reward,
} from '../core/Progression.ts';
import { Rng } from '../../../m83-determinism-and-ghosts/files/core/Rng.ts';

let pass = 0, fail = 0;
const ok = (n: string, c: boolean, x = '') => { c ? (pass++, console.log(`  ok   ${n}`)) : (fail++, console.log(`  FAIL ${n} ${x}`)); };

// ══ RECEIPT INTEGRITY ════════════════════════════════════════════════════
const claim = (o: Partial<ClaimedReceipt> = {}): ClaimedReceipt => ({
  modeId: 'dunk', score: 120, outcome: 'win', durationSeconds: 90,
  completed: true, comboCount: 5, criticalCount: 3, ...o,
});
const withReplay = (o: Partial<ClaimedReceipt> = {}): ClaimedReceipt => {
  const base = claim(o);
  return {
    ...base,
    replay: { seed: 4242, totalTicks: Math.round(base.durationSeconds * 60), dt: 1 / 60, finalHash: 987654, score: base.score },
  };
};

ok('trust is ordered', TRUST_ORDER.length === 4 && TRUST_ORDER[0] === 'unverified');
ok('atLeast compares levels', atLeast('attested', 'plausible') && !atLeast('plausible', 'attested'));

// THE POLICY THAT MATTERS
ok('an unverified claim still earns XP — refusing to score an ordinary game '
  + 'would be absurd', PAYOUT_BY_TRUST.unverified.xp);
ok('but earns no shards and no PRQ', !PAYOUT_BY_TRUST.unverified.shards && !PAYOUT_BY_TRUST.unverified.prq);
ok('a plausible claim earns shards and PRQ', PAYOUT_BY_TRUST.plausible.shards && PAYOUT_BY_TRUST.plausible.prq);
ok('but never touches the leaderboard', !PAYOUT_BY_TRUST.plausible.leaderboard);
ok('an attested claim is ranked-eligible', PAYOUT_BY_TRUST.attested.ranked);
ok('THE LINE: only a RE-SIMULATED claim can win real money',
  PAYOUT_BY_TRUST.resimulated.cashArena
  && !PAYOUT_BY_TRUST.attested.cashArena
  && !PAYOUT_BY_TRUST.plausible.cashArena);
ok('every trust level below the top is barred from cash',
  TRUST_ORDER.slice(0, 3).every((t) => !PAYOUT_BY_TRUST[t].cashArena));

// ── plausibility ─────────────────────────────────────────────────────────
ok('an ordinary dunk session passes', plausibilityFlags(claim()).length === 0);
ok('THE ATTACK: score 999999 is caught',
  plausibilityFlags(claim({ score: 999999 })).some((f) => /exceeds the ceiling/.test(f)));
ok('a plausible total in an impossible time is caught',
  plausibilityFlags(claim({ score: 380, durationSeconds: 21 })).some((f) => /points\/sec/.test(f)));
ok('a completed session shorter than a real one is caught',
  plausibilityFlags(claim({ durationSeconds: 2 })).some((f) => /shorter than a completed/.test(f)));
ok('THE POST-REPLAY SIGNATURE: zero duration with points is caught',
  plausibilityFlags(claim({ durationSeconds: 0, score: 100 })).some((f) => /zero duration/.test(f)));
ok('a negative score is caught', plausibilityFlags(claim({ score: -5 })).some((f) => /negative/.test(f)));
ok('an absurd combo is caught', plausibilityFlags(claim({ comboCount: 500 })).length > 0);
ok('disproportionate criticals are caught',
  plausibilityFlags(claim({ comboCount: 2, criticalCount: 40 })).length > 0);
ok('an abandoned marathon session is caught',
  plausibilityFlags(claim({ durationSeconds: 99999 })).length > 0);

ok('bounds differ per mode — 1v1 races to 21, karate does not',
  MODE_BOUNDS.onevone.absoluteMax === 21 && MODE_BOUNDS.karate.absoluteMax > 1000);
ok('a 25-point 1v1 is impossible', plausibilityFlags(claim({ modeId: 'onevone', score: 25, durationSeconds: 300 })).length > 0);
ok('an unknown mode gets a default envelope rather than a free pass',
  boundsFor('brand_new_mode').absoluteMax > 0);
ok('the shop can never score', boundsFor('market_browse').absoluteMax === 0);

// ── replay checks ────────────────────────────────────────────────────────
ok('a claim with no replay says so', replayFlags(claim()).includes('no replay attached'));
ok('a consistent replay passes', replayFlags(withReplay()).length === 0);
ok('A CLAIM STAPLED TO SOMEONE ELSE\'S REPLAY IS CAUGHT — the durations disagree',
  replayFlags({ ...withReplay(), durationSeconds: 300 }).some((f) => /covers/.test(f)));
ok('a replay scoring differently from the claim is caught',
  replayFlags({ ...withReplay(), score: 400 }).some((f) => /replay scored/.test(f)));
ok('a seedless replay is caught', (() => {
  const r = withReplay();
  return replayFlags({ ...r, replay: { ...r.replay, seed: NaN } }).some((f) => /no seed/.test(f));
})());
ok('a hashless replay is caught', (() => {
  const r = withReplay();
  return replayFlags({ ...r, replay: { ...r.replay, finalHash: undefined } }).some((f) => /no final state hash/.test(f));
})());

// ── the verdict ──────────────────────────────────────────────────────────
{
  ok('a bare plausible claim is "plausible"', assessReceipt(claim()).trust === 'plausible');
  ok('an implausible one is "unverified"', assessReceipt(claim({ score: 999999 })).trust === 'unverified');
  ok('a claim with a consistent replay is "attested"', assessReceipt(withReplay()).trust === 'attested');
  ok('and is NOT cash-eligible on its own', !assessReceipt(withReplay()).payout.cashArena);

  const resim = assessReceipt(withReplay(), 987654);
  ok('THE TOP LEVEL: a matching server hash reaches "resimulated"', resim.trust === 'resimulated');
  ok('with no flags left', resim.flags.length === 0);
  ok('and cash eligibility', resim.payout.cashArena);
  ok('and says what it means', /prize pools/.test(resim.summary));
}
{
  const lie = assessReceipt(withReplay(), 111111);
  ok('THE MOST SERIOUS RESULT: a hash mismatch drops straight to unverified',
    lie.trust === 'unverified');
  ok('it is named as a mismatch', lie.flags.some((f) => /RE-SIMULATION MISMATCH/.test(f)));
  ok('and stated plainly', /The claim is false/.test(lie.summary));
  ok('and pays nothing but XP', !lie.payout.shards && !lie.payout.cashArena);
}
{
  // A client cannot reach the top level by asserting anything.
  const selfAttested = { ...withReplay() };
  ok('THERE IS NO CLIENT PATH TO "resimulated" — the highest trust cannot be '
    + 'claimed, only earned by the server doing the work',
    assessReceipt(selfAttested).trust === 'attested');
}

// ── cash eligibility ─────────────────────────────────────────────────────
{
  const good = assessReceipt(withReplay(), 987654);
  ok('a re-simulated dunk is cash-eligible', cashEligible('dunk', good).allowed);
  ok('a re-simulated 1v1 is NOT — verification is harder in continuous modes, '
    + 'and money should follow verification rather than lead it',
    !cashEligible('onevone', good).allowed);
  ok('and it says why', /cannot be re-simulated/.test(cashEligible('onevone', good).reason));
  ok('an attested-but-not-resimulated dunk is refused',
    !cashEligible('dunk', assessReceipt(withReplay())).allowed);
  ok('the cash-eligible list matches the exact-replay modes',
    CASH_ELIGIBLE_MODES.includes('dunk') && !CASH_ELIGIBLE_MODES.includes('karate-vs'));
}

// ══ PROGRESSION ══════════════════════════════════════════════════════════
ok('parity: XP is floored at 10', sessionXp(0) === XP_MIN_PER_SESSION);
ok('parity: XP is capped at 500', sessionXp(999999) === XP_CAP_PER_SESSION);
ok('parity: XP is score / 5', sessionXp(1000) === 200);

ok('a level costs more than the one before', xpForLevel(10) > xpForLevel(9));
ok('the curve is superlinear, not flat',
  xpForLevel(40) - xpForLevel(39) > xpForLevel(10) - xpForLevel(9));
// A first draft cost 50x at level 50 — the quadratic term swamped the curve
// and turned the back half into a wall. This is the guard against that.
ok('but not a wall — level 50 is under 15x level 1',
  xpForLevel(50) / xpForLevel(1) < 15, `${(xpForLevel(50) / xpForLevel(1)).toFixed(1)}x`);
ok('and the gradient is still felt — level 50 costs at least 8x level 1',
  xpForLevel(50) / xpForLevel(1) > 8, `${(xpForLevel(50) / xpForLevel(1)).toFixed(1)}x`);
{
  ok('zero XP is level 1', levelFromXp(0).level === 1);
  const l = levelFromXp(totalXpForLevel(10));
  ok('cumulative XP lands exactly on the level', l.level === 10 && l.into === 0);
  ok('mid-level progress is reported', levelFromXp(totalXpForLevel(10) + 100).progress > 0);
  ok('progress stays in range',
    [0, 500, 50000, 5_000_000].every((x) => { const s = levelFromXp(x); return s.progress >= 0 && s.progress <= 1; }));
  ok('absurd XP caps rather than looping', levelFromXp(1e12).level === MAX_LEVEL);
  ok('negative XP is level 1', levelFromXp(-500).level === 1);
}

// ── the season ───────────────────────────────────────────────────────────
{
  const season = buildSeason('s1');
  ok('a season has 50 tiers', season.length === TIERS_PER_SEASON);
  ok('tiers are numbered in order', season.every((t, i) => t.tier === i + 1));
  ok('XP requirements rise', season[10].xpRequired > season[5].xpRequired);
  ok('every tier has a premium reward', season.every((t) => t.premium !== null));

  const freeCount = season.filter((t) => t.free !== null).length;
  ok('the free track is populated, not decorative', freeCount >= 18, `${freeCount}/50`);
  const gaps = season.reduce((max, t, i) => {
    if (t.free) return { max: Math.max(max.max, max.run), run: 0 };
    return { max: max.max, run: max.run + 1 };
  }, { max: 0, run: 0 }).max;
  ok('AND NEVER BLANK FOR LONG — a free lane empty for ten tiers is a paywall '
    + 'wearing a progress bar', gaps <= 3, `longest gap ${gaps}`);
}
{
  const season = buildSeason('s1');
  ok('no XP is tier 0', tierFromSeasonXp(0) === 0);
  ok('one tier of XP is tier 1', tierFromSeasonXp(XP_PER_TIER) === 1);
  ok('the track caps', tierFromSeasonXp(XP_PER_TIER * 999) === TIERS_PER_SEASON);

  const free = claimable(season, { seasonXp: XP_PER_TIER * 10, premium: false });
  const prem = claimable(season, { seasonXp: XP_PER_TIER * 10, premium: true });
  ok('premium claims more than free', prem.length > free.length);
  ok('free still claims something at tier 10', free.length > 0);
  ok('nothing is claimable past your tier',
    claimable(season, { seasonXp: 0, premium: true }).length === 0);
}
{
  const season = buildSeason('s1');
  const grant = retroactiveGrant(season, XP_PER_TIER * 12);
  ok('BUYING PREMIUM MID-SEASON GRANTS WHAT YOU ALREADY PASSED', grant.length === 12,
    'paying forward only would punish the player who tried the game first');
  ok('and nothing you have not reached', retroactiveGrant(season, 0).length === 0);
}

// ── THE PAYWALL RULE ─────────────────────────────────────────────────────
{
  const cosmetic: Reward[] = [
    { kind: 'shards', amount: 100, label: 'x' },
    { kind: 'skin', id: 'a', label: 'x' },
    { kind: 'emote', id: 'b', label: 'x' },
    { kind: 'title', id: 'c', label: 'x' },
    { kind: 'creator_tool', id: 'd', label: 'x' },
  ];
  ok('every legitimate reward kind passes on both tracks',
    cosmetic.every((r) => {
      try { assertNotPayToWin(r, 'premium'); assertNotPayToWin(r, 'free'); return true; }
      catch { return false; }
    }));

  for (const bad of ['stat_boost', 'multiplier', 'unlock_mode', 'advantage']) {
    let threw = false;
    try { assertNotPayToWin({ kind: bad as never, label: 'x' }, 'premium'); }
    catch (e) { threw = e instanceof PayToWinError; }
    ok(`a "${bad}" reward is REFUSED`, threw);
  }
  ok('and refused on the FREE track too — the rule is about gameplay, not money',
    (() => { try { assertNotPayToWin({ kind: 'stat_boost' as never, label: 'x' }, 'free'); return false; } catch { return true; } })());
  ok('the refusal explains the stake', (() => {
    try { assertNotPayToWin({ kind: 'advantage' as never, label: 'x' }, 'premium'); return false; }
    catch (e) { return /Cash Arena/.test((e as Error).message); }
  })());
}

// ── objectives ───────────────────────────────────────────────────────────
{
  const all = ['dunk', 'onevone', 'karate', 'surf', 'golf', 'dance', 'brain_brawl'];
  const recent = ['dunk', 'onevone'];
  const objs = pickObjectives(all, recent, 'daily', 3, new Rng(1));
  ok('objectives are produced', objs.length === 3);
  ok('THEY POINT AT MODES YOU HAVE NOT PLAYED — a daily aimed at your habit is '
    + 'a tax on it', objs.every((o) => !recent.includes(o.modeId as string)),
    objs.map((o) => o.modeId).join());
  ok('and describe themselves', objs.every((o) => o.description.length > 0));
  ok('they carry the scope XP', objs[0].xp === OBJECTIVE_XP.daily);
  ok('a weekly is worth more than a daily', OBJECTIVE_XP.weekly > OBJECTIVE_XP.daily);
  ok('objectives are reproducible from a seed — the client and server must '
    + 'agree on today without a round trip',
    JSON.stringify(pickObjectives(all, recent, 'daily', 3, new Rng(1)))
    === JSON.stringify(objs));

  const allPlayed = pickObjectives(all, all, 'daily', 3, new Rng(2));
  ok('when everything has been played it falls back gracefully', allPlayed.length === 3);
  ok('and asks you to beat your best instead',
    allPlayed.every((o) => /Beat your best/.test(o.description)));
}

// ── RULE 3: the season must be completable ───────────────────────────────
{
  // A committed player: 4 sessions a day, near the XP cap, both dailies.
  const committed = seasonFeasibility(4, 400, 2, 90);
  ok('A COMMITTED PLAYER CLEARS THE TRACK INSIDE THE SEASON', committed.completable,
    committed.note);

  // A casual player: one session a day, one daily.
  const casual = seasonFeasibility(1, 250, 1, 90);
  ok('a casual player does NOT clear it — the top tiers should mean something',
    !casual.completable, casual.note);
  ok('but gets most of the way', casual.daysNeeded < 90 * 2.5, `${casual.daysNeeded} days`);
  ok('and the shortfall is stated plainly, not buried',
    /advertisement, not a reward/.test(casual.note));
  ok('a player who does nothing never finishes', !seasonFeasibility(0, 0, 0, 90).completable);
}
{
  const season = buildSeason('s1');
  const m = nextMilestone(season, { seasonXp: XP_PER_TIER * 3 + 500, premium: false });
  ok('there is always a next milestone', m !== null);
  ok('it is ahead of you', m.xpAway > 0);
  ok('and carries the reward, so the bar says what it is FOR', m.reward.label.length > 0);
  ok('ONE thing, not a dashboard of twelve bars', typeof m.tier.tier === 'number');
  ok('a completed track has no next milestone',
    nextMilestone(season, { seasonXp: XP_PER_TIER * 999, premium: true }) === null);
}

console.log(`\n${pass} passed, ${fail} failed`);
if (fail) process.exit(1);
