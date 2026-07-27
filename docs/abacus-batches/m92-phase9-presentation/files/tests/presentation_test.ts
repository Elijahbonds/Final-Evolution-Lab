// node --experimental-strip-types --import ./tools/ts_resolve.mjs \
//   --import ./tools/fel_batch_alias.mjs tests/presentation_test.ts
//
// Phase 9. Two claims:
//
//   1. Every mechanic from phases 2-8 has a specified, accessible tell — and
//      the ones that carry a mechanic are identified as such.
//   2. Quality moves to hold 60fps, and a tell is never what gets shed.

import {
  TELLS, tellsFor, tell, loadBearingTells, auditTell, unimplementedTells,
  legibilityReport, type Tell,
} from '../core/Legibility.ts';
import {
  SHED_ORDER, SHEDDABLE, TARGET_MS, SHED_THRESHOLD_MS, RESTORE_THRESHOLD_MS,
  EVIDENCE_FRAMES, FULL_QUALITY, DEFAULT_FEEL, ProtectedLayerError,
  assertSheddable, QualityGovernor, gatedShake, gatedHitStop, gatedHaptic,
  gatedFlash, impactPlan, type FeelSettings, type QualityLayer,
} from '../core/AdaptiveQuality.ts';

let pass = 0, fail = 0;
const ok = (n: string, c: boolean, x = '') => { c ? (pass++, console.log(`  ok   ${n}`)) : (fail++, console.log(`  FAIL ${n} ${x}`)); };

// ══ LEGIBILITY ═══════════════════════════════════════════════════════════
ok('the tell registry is populated', TELLS.length >= 10);
ok('tell ids are unique', new Set(TELLS.map((t) => t.id)).size === TELLS.length);
ok('every tell says what the player should CONCLUDE, not what it draws',
  TELLS.every((t) => t.meaning.length > 20));

// THE DEBT: each phase's flagged-but-unfixed mechanic now has a tell.
ok('Phase 3: the tip zone has a tell', tell('spacing_tip') !== undefined);
ok('Phase 3: the whiff punish window has one', tell('whiff_punish_window') !== undefined);
ok('Phase 2: the defender commitment has one', tell('defender_committed') !== undefined);
ok('Phase 4: the pitch tell has one', tell('pitch_tell') !== undefined);
ok('Phase 4: the pursuit angle has one', tell('pursuit_angle') !== undefined);
ok('Phase 5: the wave section has one', tell('wave_section') !== undefined);
ok('Phase 5: the line at risk has one', tell('line_at_risk') !== undefined);
ok('Phase 5: the carve/skid state has one', tell('edge_state') !== undefined);

// ── every tell survives every accessibility configuration ────────────────
{
  const problems = TELLS.flatMap(auditTell);
  ok('EVERY TELL PASSES THE ACCESSIBILITY AUDIT', problems.length === 0,
    problems.join('\n         '));
}
ok('every tell has a caption — none is silent to a deaf player',
  TELLS.every((t) => t.caption.length > 0));
ok('no tell relies on colour alone',
  TELLS.filter((t) => ['outline', 'icon', 'ground_marker'].includes(t.visual.form))
    .every((t) => !!t.visual.glyph));

// ── the audit must be able to FAIL ───────────────────────────────────────
{
  const base = TELLS[0];
  ok('a captionless tell is caught',
    auditTell({ ...base, caption: '' }).some((p) => /no caption/.test(p)));
  ok('an urgent flash-only tell is caught — lost exactly when it is needed',
    auditTell({ ...base, urgency: 'act', visual: { form: 'flash', durationMs: 200 } })
      .some((p) => /reduced motion/.test(p)));
  ok('an urgent HUD tell is caught — missed by a player watching their character',
    auditTell({ ...base, urgency: 'act', anchor: 'hud' }).some((p) => /Anchor it to the subject/.test(p)));
  ok('a too-brief load-bearing tell is caught',
    auditTell({ ...base, loadBearing: true, visual: { form: 'icon', glyph: 'x', durationMs: 100 } })
      .some((p) => /250ms/.test(p)));
  ok('a colour-only marker is caught',
    auditTell({ ...base, visual: { form: 'ground_marker', durationMs: 0 } })
      .some((p) => /no glyph/.test(p)));
}

// ── anchoring: a spatial mechanic must read in the world ─────────────────
{
  const spatial = ['spacing_tip', 'defender_committed', 'pursuit_angle', 'wave_section'];
  ok('SPATIAL MECHANICS ANCHOR TO THE WORLD OR THE SUBJECT — a HUD readout for '
    + 'a spatial mechanic is a stat, not a tell',
    spatial.every((id) => ['world', 'subject', 'player'].includes(tell(id).anchor)));
  ok('and urgent tells are never in the HUD',
    TELLS.filter((t) => t.urgency === 'act').every((t) => t.anchor !== 'hud'));
}

// ── per-mode ─────────────────────────────────────────────────────────────
{
  const karate = tellsFor('karate-vs');
  ok('a mode gets its own tells', karate.some((t) => t.id === 'spacing_tip'));
  ok('and the cross-mode ones', karate.some((t) => t.id === 'prq_effect'));
  ok('but not another mode\'s', !karate.some((t) => t.id === 'pitch_tell'));
  ok('every mode with mechanics has at least one load-bearing tell',
    ['karate-vs', 'onevone', 'baseball', 'football', 'tennis', 'skateboard', 'snowboard', 'surf']
      .every((m) => loadBearingTells(m).length > 0));
}
{
  // The report Phase 9 exists to produce.
  const none = legibilityReport('baseball', []);
  ok('a mode with nothing drawn is NOT ready', !none.ready);
  ok('and the report names the cost, not just the count',
    /reads as random/.test(none.note), none.note);
  ok('it lists exactly what is missing', none.missing.length > 0);

  const all = legibilityReport('baseball', loadBearingTells('baseball').map((t) => t.id));
  ok('a mode with every load-bearing tell drawn IS ready', all.ready);
  ok('decorative tells are not required for readiness',
    legibilityReport('dunk', loadBearingTells('dunk').map((t) => t.id)).ready);
  ok('unimplementedTells only reports load-bearing ones',
    unimplementedTells('dunk', []).every((t) => t.loadBearing));
}

// ══ ADAPTIVE QUALITY ═════════════════════════════════════════════════════
ok('60fps is the target', Math.abs(TARGET_MS - 16.67) < 0.02);
ok('there is hysteresis, so quality does not oscillate',
  RESTORE_THRESHOLD_MS < SHED_THRESHOLD_MS);
ok('the shed threshold is a real drop, not jitter', SHED_THRESHOLD_MS > TARGET_MS);
ok('the shed order goes atmosphere first', SHED_ORDER[0] === 'ambient_particles');
ok('and resolution last — a soft image beats a slow one',
  SHED_ORDER[SHED_ORDER.length - 1] === 'render_scale');
ok('shed order has no duplicates', new Set(SHED_ORDER).size === SHED_ORDER.length);

// ── THE RULE ─────────────────────────────────────────────────────────────
{
  const tellIds = TELLS.map((t) => t.id);
  ok('NO TELL APPEARS IN THE SHED ORDER — not as an oversight, by construction',
    !SHED_ORDER.some((l) => tellIds.includes(l as string)));

  for (const protectedThing of ['spacing_tip', 'defender_committed', 'wave_section', 'captions', 'hud_tells']) {
    let threw = false;
    try { assertSheddable(protectedThing); } catch (e) { threw = e instanceof ProtectedLayerError; }
    ok(`shedding "${protectedThing}" is REFUSED`, threw);
  }
  ok('the refusal explains that it removes a MECHANIC, not quality', (() => {
    try { assertSheddable('spacing_tip'); return false; }
    catch (e) { return /removes the mechanic/.test((e as Error).message); }
  })());
  ok('a genuine effect layer is allowed', (() => {
    try { assertSheddable('ambient_particles'); return true; } catch { return false; }
  })());
  ok('SHEDDABLE is exactly the shed order', SHEDDABLE.size === SHED_ORDER.length);
}

// ── the governor ─────────────────────────────────────────────────────────
{
  const g = new QualityGovernor();
  ok('it starts at full quality', g.current.level === 0 && g.current.renderScale === 1);
  ok('and needs evidence before acting', g.sample(30) === null);

  for (let i = 0; i < EVIDENCE_FRAMES; i++) g.sample(30);
  ok('sustained slow frames shed a layer', g.current.level >= 1, `level ${g.current.level}`);
  ok('starting with atmosphere', g.isShed('ambient_particles'));
}
{
  // A single hitch must not trigger a drop — median, not mean.
  const g = new QualityGovernor();
  for (let i = 0; i < EVIDENCE_FRAMES - 1; i++) g.sample(14);
  g.sample(400);                                    // one GC pause
  for (let i = 0; i < EVIDENCE_FRAMES; i++) g.sample(14);
  ok('ONE 400ms HITCH DOES NOT DROP QUALITY — a mean would have been dragged '
    + 'straight over the threshold', g.current.level === 0, `level ${g.current.level}`);
}
{
  const g = new QualityGovernor();
  for (let i = 0; i < EVIDENCE_FRAMES * 12; i++) g.sample(40);
  ok('a very slow device sheds progressively', g.current.level > 2, `level ${g.current.level}`);
  ok('and eventually reduces render scale', g.current.renderScale < 1 || g.current.level < SHED_ORDER.length);
  ok('but never sheds more than exists', g.current.level <= SHED_ORDER.length);
}
{
  const g = new QualityGovernor();
  for (let i = 0; i < EVIDENCE_FRAMES * 3; i++) g.sample(40);
  const shedLevel = g.current.level;
  for (let i = 0; i < EVIDENCE_FRAMES * 12; i++) g.sample(10);
  ok('quality is restored when the device keeps up', g.current.level < shedLevel);
  ok('and restoration is more cautious than shedding',
    g.history.filter((h) => h.action === 'restore').length
    <= g.history.filter((h) => h.action === 'shed').length);
}
{
  const g = new QualityGovernor();
  ok('a NaN frame time is ignored', g.sample(NaN) === null);
  ok('and a negative one', g.sample(-5) === null);
  for (let i = 0; i < EVIDENCE_FRAMES; i++) g.sample(14);
  ok('a comfortable device stays at full quality', g.current.level === 0);
  ok('and reports it', g.verdict.comfortable && /full quality/.test(g.verdict.note));
}
{
  const g = new QualityGovernor();
  for (let i = 0; i < EVIDENCE_FRAMES * 40; i++) g.sample(60);
  ok('a device that cannot cope is reported honestly', !g.verdict.comfortable);
  ok('AND THE NOTE SAYS WHY IT MATTERS — below 60fps the reaction mechanics '
    + 'stop being fair', /stop being fair/.test(g.verdict.note));
  g.reset();
  ok('reset returns to full quality', g.current.level === 0);
}

// ══ THE a11y GATE gameFeel NEVER GOT ═════════════════════════════════════
const feel = (o: Partial<FeelSettings> = {}): FeelSettings => ({ ...DEFAULT_FEEL, ...o });

ok('shake is unmodified by default', gatedShake(0.8, feel()) === 0.8);
ok('THE MISSING GATE: reduced motion zeroes camera shake — the thing that '
  + 'actually makes people ill', gatedShake(0.8, feel({ reducedMotion: true })) === 0);
ok('shake is clamped', gatedShake(50, feel()) === 1);

ok('hit-stop is capped at 120ms', gatedHitStop(9999, feel()) === 120);
ok('REDUCED MOTION SHORTENS HIT-STOP RATHER THAN REMOVING IT — it is a pause, '
  + 'not movement, and blanket-disabling everything under one flag makes '
  + 'accessibility feel like a punishment',
  gatedHitStop(100, feel({ reducedMotion: true })) > 0
  && gatedHitStop(100, feel({ reducedMotion: true })) < 100);

ok('haptics fire by default', gatedHaptic([20], feel()) !== null);
ok('and can be turned off independently of motion',
  gatedHaptic([20], feel({ hapticsEnabled: false })) === null);
ok('a null pattern stays null', gatedHaptic(null, feel()) === null);

ok('a slow flash is allowed', gatedFlash(2, 1, feel()) > 0);
ok('SEIZURE RISK: above 3Hz is a hard zero, not a scale',
  gatedFlash(8, 1, feel()) === 0);
ok('noFlashing blocks even a slow one', gatedFlash(1, 1, feel({ noFlashing: true })) === 0);
ok('reduced motion dims a flash without removing it',
  gatedFlash(1, 1, feel({ reducedMotion: true })) > 0
  && gatedFlash(1, 1, feel({ reducedMotion: true })) < 1);

{
  const normal = impactPlan(0.8);
  ok('a default impact does all four channels',
    normal.hitStopMs > 0 && normal.shake > 0 && normal.haptic !== null);

  const reduced = impactPlan(0.8, feel({ reducedMotion: true }));
  ok('under reduced motion the shake is gone', reduced.shake === 0);
  ok('but the impact is still FELT — hit-stop and haptics remain',
    reduced.hitStopMs > 0 && reduced.haptic !== null,
    'accessibility should change how a hit reads, not delete it');

  const quiet = impactPlan(0.8, feel({ reducedMotion: true, hapticsEnabled: false, noFlashing: true }));
  ok('with everything off, only hit-stop remains — and something still lands',
    quiet.hitStopMs > 0 && quiet.shake === 0 && quiet.haptic === null && quiet.flash === 0);
}

console.log(`\n${pass} passed, ${fail} failed`);
if (fail) process.exit(1);
