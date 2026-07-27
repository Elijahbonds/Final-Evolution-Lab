// Certification — the 12-point bar, and an honest count of how much of it is
// real.
//
// WHY THIS FILE IS MOSTLY ABOUT HONESTY
// Ten phases produced roughly 60,000 lines and about 900 passing tests. None
// of it has been observed running in the deployed app. That is not a
// throwaway caveat, it is the single most important fact about the state of
// this project, and a certification pass that reports "12/12 PASS" off the
// back of green unit tests would be actively misleading.
//
// So a criterion here has four states, not two:
//
//   PASS       demonstrated, with evidence anyone can re-run
//   BUILT      the code exists and is tested, but nothing has integrated it
//   SPECIFIED  the design exists and the code does not
//   UNKNOWN    nobody has checked
//
// BUILT is the one that matters. Most of this pass is BUILT, and a reader who
// sees BUILT as a soft PASS will ship something that does not work. `PASS` is
// the only state that means a player benefits.

export type CriterionState = 'PASS' | 'BUILT' | 'SPECIFIED' | 'UNKNOWN' | 'FAIL';

/** Only PASS counts toward shipping. */
export function counts(state: CriterionState): boolean { return state === 'PASS'; }

export interface Criterion {
  id: string;
  /** From docs/BLUEPRINT.md §7. */
  bar: string;
  /** How it is checked. If this is empty, it cannot be certified. */
  evidence: string;
  /** True if a mode cannot ship without it. */
  mandatory: boolean;
}

/** The bar, verbatim from BLUEPRINT §7. 1-9 are mandatory. */
export const CRITERIA: Criterion[] = [
  { id: 'response', bar: 'Input to visible response <= 66ms median on a mid-tier phone', evidence: 'instrumented in-app measurement', mandatory: true },
  { id: 'framerate', bar: '60fps held for a 3-minute session, no frame over 50ms', evidence: 'QualityGovernor.verdict over a real session', mandatory: true },
  { id: 'boot', bar: 'Boots to playable in <= 3s on 4G, cold', evidence: 'Lighthouse, throttled', mandatory: true },
  { id: 'canvas', bar: 'Canvas >= 85% of viewport height on iPhone portrait', evidence: 'measured in a real browser', mandatory: true },
  { id: 'no_tpose', bar: 'No T-pose at any point in a session', evidence: 'PoseProbe clean under ?probe=1', mandatory: true },
  { id: 'a11y_controls', bar: 'One-handed, remappable, reduced motion honoured', evidence: 'AccessibilityPanel + gated impact plan', mandatory: true },
  { id: 'a11y_audio', bar: 'Every gameplay sound has a visual equivalent', evidence: 'playCued coverage + caption bus', mandatory: true },
  { id: 'prq', bar: 'Reports a SessionResult AND reads PRQ before starting', evidence: '[FEL-DDA] on boot, receipt on end', mandatory: true },
  { id: 'lifecycle', bar: 'Survives 20 route changes without a reload', evidence: 'window.__FEL_ENGINES__ never exceeds 2', mandatory: true },
  { id: 'fun', bar: 'Fun for 60 seconds with no tutorial', evidence: 'the founder plays it', mandatory: false },
  { id: 'procedural', bar: 'Zero external assets; procedural venue, original content', evidence: 'asset audit', mandatory: false },
  { id: 'tested', bar: 'Core logic covered by executable tests', evidence: 'node --experimental-strip-types', mandatory: false },
];

export const MANDATORY = CRITERIA.filter((c) => c.mandatory).map((c) => c.id);

export interface ModeCertification {
  modeId: string;
  states: Record<string, CriterionState>;
  /** Load-bearing tells drawn / total. From Legibility. */
  tellsDrawn: number;
  tellsRequired: number;
}

export interface CertVerdict {
  modeId: string;
  shippable: boolean;
  passed: number;
  built: number;
  blocking: string[];
  /** The one-line truth. */
  summary: string;
}

/**
 * Certify one mode.
 *
 * A mode is shippable only when every mandatory criterion is PASS. BUILT does
 * not count, and the summary says so explicitly — because "9 of 9 built" reads
 * like success and means nothing has been integrated.
 */
export function certify(c: ModeCertification): CertVerdict {
  const passed = CRITERIA.filter((x) => c.states[x.id] === 'PASS').length;
  const built = CRITERIA.filter((x) => c.states[x.id] === 'BUILT').length;
  const blocking = MANDATORY.filter((id) => c.states[id] !== 'PASS');

  // A mode whose mechanics are invisible is not shippable however green its
  // tests are — see M92. This is the same rule stated as a gate.
  const legible = c.tellsRequired === 0 || c.tellsDrawn >= c.tellsRequired;
  if (!legible) blocking.push('legibility');

  const shippable = blocking.length === 0;

  return {
    modeId: c.modeId,
    shippable,
    passed,
    built,
    blocking,
    summary: shippable
      ? `${c.modeId}: ${passed}/12 demonstrated. Shippable.`
      : `${c.modeId}: ${passed} PASS, ${built} BUILT-not-integrated. `
        + `Blocking: ${blocking.join(', ')}. `
        + (built > passed
          ? 'Most of this mode is code nobody has wired up — BUILT is not a soft PASS.'
          : 'Needs the blocking criteria demonstrated, not written.'),
  };
}

export interface FleetReport {
  total: number;
  shippable: number;
  /** Criteria blocking the most modes, worst first. */
  topBlockers: Array<{ id: string; modes: number; bar: string }>;
  summary: string;
}

/**
 * Certify the whole product.
 *
 * The `topBlockers` list is the useful output. If one criterion blocks
 * twenty-three modes, that is one piece of work worth more than any per-mode
 * effort — and it is exactly the kind of leverage that is invisible when
 * looking at modes one at a time.
 */
export function certifyFleet(modes: ModeCertification[]): FleetReport {
  const verdicts = modes.map(certify);
  const shippable = verdicts.filter((v) => v.shippable).length;

  const counts = new Map<string, number>();
  for (const v of verdicts) for (const b of v.blocking) counts.set(b, (counts.get(b) ?? 0) + 1);

  const topBlockers = [...counts.entries()]
    .map(([id, n]) => ({ id, modes: n, bar: CRITERIA.find((c) => c.id === id)?.bar ?? id }))
    .sort((a, b) => b.modes - a.modes);

  const worst = topBlockers[0];
  return {
    total: modes.length,
    shippable,
    topBlockers,
    summary: shippable === modes.length
      ? `All ${modes.length} modes certified.`
      : `${shippable}/${modes.length} modes shippable. `
        + (worst
          ? `The single biggest blocker is "${worst.id}", holding back ${worst.modes} mode(s) — `
            + 'fixing one thing once beats certifying modes one at a time.'
          : ''),
  };
}

/**
 * The state every mode is in today, before integration.
 *
 * Deliberately pessimistic and deliberately uniform: the shared layers from
 * M81-M92 are BUILT for every mode because they are the same code, and none of
 * it has been observed running. Per-mode differences only appear once someone
 * integrates and measures.
 *
 * This is the baseline the next pass is measured against. If it is wrong, it
 * is wrong in the direction of understating progress, which is the safe
 * direction for a document that decides what ships.
 */
export function baselineToday(modeId: string, tellsRequired: number): ModeCertification {
  return {
    modeId,
    tellsRequired,
    tellsDrawn: 0,
    states: {
      response: 'BUILT',        // MotionModel exists; never measured in-app
      framerate: 'BUILT',       // QualityGovernor exists; never run
      boot: 'UNKNOWN',          // nobody has measured a cold 4G load
      canvas: 'SPECIFIED',      // CSS written, container chain unverified
      no_tpose: 'BUILT',        // PoseProbe exists; the cause is still unknown
      a11y_controls: 'BUILT',
      a11y_audio: 'BUILT',      // caption bus exists; no mode calls playCued
      prq: 'BUILT',             // DDA exists; no mode reads it yet
      lifecycle: 'BUILT',       // ModeHarness v3 exists; not integrated
      fun: 'UNKNOWN',           // only the founder can answer this
      procedural: 'PASS',       // the one thing that has always been true
      tested: 'PASS',
    },
  };
}

/**
 * Cost of one criterion across the fleet.
 *
 * Answers "should I fix this once or twenty-five times?". Shared-layer work
 * lands everywhere at once; per-mode work does not, and confusing the two is
 * how a roadmap ends up spending a month on the wrong thing.
 */
export function leverage(
  criterionId: string, modes: ModeCertification[],
): { blocked: number; shared: boolean; note: string } {
  const blocked = modes.filter((m) => m.states[criterionId] !== 'PASS').length;
  const shared = ['response', 'framerate', 'lifecycle', 'a11y_controls', 'a11y_audio', 'prq', 'canvas']
    .includes(criterionId);
  return {
    blocked,
    shared,
    note: shared
      ? `Shared layer: integrating it once fixes ${blocked} mode(s).`
      : `Per-mode: needs ${blocked} separate piece(s) of work.`,
  };
}
