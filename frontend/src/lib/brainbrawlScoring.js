/**
 * brainbrawlScoring.js — JS mirror of backend/lib/brainbrawl.py scoring.
 *
 * Used ONLY in locally-authoritative recording mode (RECORDING_LOCAL=1 or
 * ?recording=1) so a screen recording never stutters on network round-trips.
 * Integer math matches the Python engine exactly (Math.floor == // for the
 * non-negative operands used here), so a fixed seed + fixed inputs produce
 * the same score the server would have produced.
 */

export const BASE_POINTS = { easy: 100, medium: 150, hard: 200 };
export const STREAK_STEP_PCT = 10; // +10% per streak level
export const STREAK_CAP = 5;       // bonus capped at +50%
export const MAX_LATENCY_CREDIT_MS = 2000;

export function normalizeResponseMs(responseMs, latencyMs, timeLimitMs) {
  const lat = Math.max(0, Math.min(Math.trunc(latencyMs || 0), MAX_LATENCY_CREDIT_MS));
  const normalized = Math.trunc(responseMs) - lat;
  return Math.max(0, Math.min(normalized, timeLimitMs));
}

export function partialCredit(correct, selected) {
  const correctSet = new Set(correct);
  const selSet = new Set(selected);
  let hits = 0;
  let wrong = 0;
  selSet.forEach((s) => (correctSet.has(s) ? hits++ : wrong++));
  const numerator = Math.max(0, hits - wrong);
  const fullCorrect =
    selSet.size === correctSet.size && [...selSet].every((s) => correctSet.has(s));
  return { numerator, denominator: correctSet.size, fullCorrect };
}

/** Mirrors lib.brainbrawl.score_answer (Python). */
export function scoreAnswer(question, selected, responseMs, latencyMs, timeLimitMs, streak) {
  const normalizedMs = normalizeResponseMs(responseMs, latencyMs, timeLimitMs);
  const { numerator, denominator, fullCorrect } = partialCredit(question.answer, selected);
  const base = BASE_POINTS[question.difficulty] || 150;

  let raw = 0;
  if (numerator > 0) {
    const remainingMs = timeLimitMs - normalizedMs;
    const speedScaled =
      Math.floor(base / 2) + Math.floor((base * remainingMs) / (2 * timeLimitMs));
    raw = Math.floor((speedScaled * numerator) / denominator);
  }
  const bonus =
    raw > 0 ? Math.floor((raw * Math.min(streak, STREAK_CAP) * STREAK_STEP_PCT) / 100) : 0;

  return {
    questionId: question.id,
    selected: [...selected].map(Number).sort((a, b) => a - b),
    correctAnswer: [...question.answer],
    fullCorrect,
    creditNumerator: numerator,
    creditDenominator: denominator,
    normalizedMs,
    rawPoints: raw,
    streakBonus: bonus,
    points: raw + bonus,
    streakBefore: streak,
    streakAfter: fullCorrect ? streak + 1 : 0,
  };
}
