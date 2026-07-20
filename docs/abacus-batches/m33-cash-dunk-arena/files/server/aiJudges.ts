// AI Judges — three personas, one deterministic core. The score is a pure
// function of the run (auditable/replayable — the skill-contest requirement);
// personas add a BOUNDED style lean + LLM commentary that never moves scores.

import {
  PERSONA_STYLE_LEAN_MAX,
  type DunkRunTelemetry, type JudgeScore, type JudgeScorecard,
} from '../shared/arenaContracts';

// ── Judge personas (commentary via the M19 chat route, persona per judge) ──
export interface JudgePersona {
  id: 'silk' | 'doc' | 'prime';
  name: string;
  bias: 'style' | 'technique' | 'difficulty';
  styleLean: number;                     // −0.5..+0.5, constant per judge
  voice: string;                         // system-prompt fragment for commentary
}
export const JUDGES: JudgePersona[] = [
  { id: 'silk', name: 'Silk', bias: 'style', styleLean: +PERSONA_STYLE_LEAN_MAX,
    voice: 'Smooth-talking style purist. Cares about flair, rhythm, and finish aesthetics. One sentence, warm, vivid.' },
  { id: 'doc', name: 'Doc', bias: 'technique', styleLean: 0,
    voice: 'Biomechanics analyst. Cites the numbers (apex, hang time, timing delta). One sentence, precise, encouraging.' },
  { id: 'prime', name: 'Prime', bias: 'difficulty', styleLean: -PERSONA_STYLE_LEAN_MAX,
    voice: 'Hard-to-impress legend. Respects degree of difficulty only. One sentence, terse, occasionally awed.' },
];

const clamp10 = (n: number) => Math.max(0, Math.min(10, n));
const round1 = (n: number) => Math.round(n * 10) / 10;

/** Deterministic axes from telemetry — identical input ⇒ identical output. */
export function coreAxes(t: DunkRunTelemetry): { technique: number; difficulty: number; style: number } {
  // Technique: timing precision + clean release + controlled approach
  const timing = Math.max(0, 1 - t.qteDeltaMs / 250);              // 0..1
  const technique = clamp10(timing * 6 + (t.cleanRelease ? 2.5 : 0) + Math.min(1.5, t.approachSpeed / 6));
  // Difficulty: style tier + charge commitment + air
  const styleTier = t.style === 'sig' ? 4.5 : t.style === 'flashy' ? 3 : 2;
  const difficulty = clamp10(styleTier + t.chargeLevel * 3 + Math.min(2.5, t.apexHeight * 1.8));
  // Style: hang time + flair tier + finish quality
  const style = clamp10(Math.min(4, t.hangTimeMs / 250) + styleTier * 0.9 + (t.cleanRelease ? 1.8 : 0.4));
  return { technique: round1(technique), difficulty: round1(difficulty), style: round1(style) };
}

export interface CommentarySeam {
  /** M19 chat route with the judge persona voice; MUST NOT affect scores. */
  line(judge: JudgePersona, axes: { technique: number; difficulty: number; style: number },
       metrics: JudgeScorecard['metrics']): Promise<string>;
}

/** Fallback commentary when the LLM seam is unavailable — deterministic. */
const cannedLine = (j: JudgePersona, total: number): string =>
  total >= 24 ? `${j.name}: that one goes on the wall.` :
  total >= 18 ? `${j.name}: real promise in that finish.` :
  `${j.name}: run it again — the bounce is there.`;

export async function scoreRun(
  t: DunkRunTelemetry,
  metrics: JudgeScorecard['metrics'],
  commentary?: CommentarySeam,
): Promise<JudgeScorecard> {
  const axes = coreAxes(t);
  const scores: JudgeScore[] = [];
  for (const j of JUDGES) {
    const style = clamp10(axes.style + j.styleLean);   // the ONLY persona effect, bounded
    const total = round1(axes.technique + axes.difficulty + style);
    let line: string;
    try {
      line = commentary ? await commentary.line(j, { ...axes, style }, metrics) : cannedLine(j, total);
    } catch { line = cannedLine(j, total); }
    scores.push({
      judgeId: j.id,
      technique: axes.technique, difficulty: axes.difficulty, style: round1(style),
      total, commentary: line.slice(0, 160),
    });
  }
  return {
    scores,
    grandTotal: round1(scores.reduce((s, x) => s + x.total, 0)),
    metrics,
  };
}

/**
 * Server-side verification: replay the submitted input stream through the
 * deterministic sim and confirm the reproduced telemetry matches the claim.
 * Bind `simulate` to the headless DunkMode simulation (same code path as the
 * client — same seed ⇒ same physics ⇒ same telemetry).
 */
export async function verifyRun(
  claimed: DunkRunTelemetry,
  simulate: (seed: string, inputStream: string) => Promise<DunkRunTelemetry>,
): Promise<{ verified: boolean; delta?: string }> {
  const replayed = await simulate(claimed.seed, claimed.inputStream);
  const close = (a: number, b: number, tol: number) => Math.abs(a - b) <= tol;
  const ok =
    replayed.style === claimed.style &&
    close(replayed.qteDeltaMs, claimed.qteDeltaMs, 20) &&
    close(replayed.apexHeight, claimed.apexHeight, 0.05) &&
    close(replayed.hangTimeMs, claimed.hangTimeMs, 40) &&
    replayed.cleanRelease === claimed.cleanRelease;
  return ok
    ? { verified: true }
    : { verified: false, delta: JSON.stringify({ claimed, replayed }).slice(0, 500) };
}
