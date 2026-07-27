// MentalResilience — the source for a number the backend has always computed
// and nobody has ever supplied.
//
// WHAT EXISTS
// `backend/app/services/mri_engine.py` computes the Mental Resiliency Index:
//
//     MRI = 0.30·ARV + 0.45·ESI + 0.25·Pacing
//
// graded VULNERABLE / ADAPTING / RESILIENT / UNBREAKABLE. The weights are in
// `constants.py`, the grading is in `formulas.py`, and the session receipt
// schema types all three inputs.
//
// WHAT DOES NOT EXIST
// Anything that produces ARV, ESI or Pacing. The receipt schema defaults `arv`
// and `esi` to **50**, and no mode overwrites them.
//
//     EVERY PLAYER HAS AN MRI OF ABOUT 50. FOREVER.
//
// That is the same shape as the PRQ bug in M82 — a formula, weights, grading
// thresholds and a UI, all correct, all fed by a constant. The Mental
// Resiliency thesis is one of the two things this product is actually about,
// and it has never measured anything.
//
// WHAT THE THREE NUMBERS SHOULD MEAN
// Taken from the receipt schema's own labels, and each is measurable from a
// stream of samples any mode already produces:
//
//   ARV — Adaptive Recovery Value. How well you perform AFTER a setback. Do
//         you tilt, or do you reset? This is measured by comparing the window
//         following each failure against your own baseline.
//   ESI — Emotional Stability Index. Does your accuracy HOLD as the load
//         rises? Anyone is accurate when it is easy. Stability is whether the
//         curve stays flat when it stops being easy.
//   PACING — Do you sustain, or spike early and fade? Compares the first
//         third of a session against the last.
//
// Note what all three have in common: they are about performance *under
// changing conditions*, not performance. That is what makes them resilience
// rather than skill, and it is why Brain Brawl belongs in a fitness product at
// all — the interesting question is not whether you know the answer, it is
// whether you still know it on the ninth question with your heart rate at 160.

/** One observation. Any mode can emit these — a quiz answer, a timed swing,
 *  a dodge, a rally shot. */
export interface PerfSample {
  /** Simulation tick, from M83's FixedStep. Ordering matters; wall-clock does not. */
  tick: number;
  /** Did it go well? */
  success: boolean;
  /**
   * How demanding this moment was, 0..1. Wave number, rally length, pitch
   * deception, defender pressure — whatever the mode's own load is.
   */
  load: number;
  /**
   * Quality of the outcome, 0..1. Timing accuracy, answer speed, shot
   * quality. Richer than the boolean and used where it exists.
   */
  quality: number;
  /** Optional physiological load at that moment, 0..1 — from a heart-rate
   *  band or from accumulated in-game exertion. */
  exertion?: number;
}

export interface ResilienceScores {
  /** 0-100 each, matching the receipt schema's ranges. */
  arv: number;
  esi: number;
  pacing: number;
  mri: number;
  grade: MriGrade;
  /** Why the number is what it is. A resilience score nobody understands is a
   *  number, not feedback. */
  note: string;
  /** How much to trust it. Too few samples and the answer is "not enough". */
  confidence: number;
}

export type MriGrade = 'VULNERABLE' | 'ADAPTING' | 'RESILIENT' | 'UNBREAKABLE';

/** Mirrors backend/app/utils/constants.py. Tested against it. */
export const MRI_ARV_WEIGHT = 0.30;
export const MRI_ESI_WEIGHT = 0.45;
export const MRI_PACING_WEIGHT = 0.25;

/** Mirrors `grade_mri` in backend/app/utils/formulas.py. */
export function gradeMri(score: number): MriGrade {
  const s = Math.min(100, Math.max(0, score));
  if (s >= 85) return 'UNBREAKABLE';
  if (s >= 65) return 'RESILIENT';
  if (s >= 45) return 'ADAPTING';
  return 'VULNERABLE';
}

/** Below this, a session cannot say anything about resilience. */
export const MIN_SAMPLES = 8;
/** Samples examined after a failure when measuring recovery. */
export const RECOVERY_WINDOW = 3;

const mean = (xs: number[]): number => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 0);

/**
 * ARV — how you perform after a setback.
 *
 * For every failure, look at the next few samples and compare them to the
 * player's own baseline. Better than baseline after adversity is resilience;
 * worse is tilt.
 *
 * Deliberately measured against the player's OWN baseline rather than an
 * absolute. A weak player who holds their level after a mistake is more
 * resilient than a strong player who falls apart, and any absolute scale would
 * say the opposite.
 */
export function computeArv(samples: PerfSample[]): number {
  if (samples.length < MIN_SAMPLES) return 50;

  const recoveries: number[] = [];
  for (let i = 0; i < samples.length - 1; i++) {
    if (samples[i].success) continue;
    const after = samples.slice(i + 1, i + 1 + RECOVERY_WINDOW);
    if (after.length === 0) continue;

    // Compare against the window BEFORE the failure, not the session mean.
    //
    // A whole-session baseline includes the tilt it is trying to detect, so it
    // drags itself down and damps the signal — a badly tilting player measured
    // that way scored 46.7 instead of the ~30 the behaviour deserves. The
    // player's form immediately BEFORE the mistake is what "recovered" should
    // be measured against, and it is also what the phrase actually means.
    const before = samples.slice(Math.max(0, i - RECOVERY_WINDOW), i);
    const local = before.length ? mean(before.map((s) => s.quality)) : 0;
    if (local <= 0) continue;

    // The recovery window is WEIGHTED toward the first sample after the
    // mistake, because that is where tilt actually shows. An unweighted mean
    // cannot tell a player who dips-then-recovers from one who never dipped:
    // in any repeating pattern the before- and after-windows contain the same
    // samples and every player scores exactly 50. Weighting 3:2:1 makes the
    // immediate response dominate, which is both what "recovery" means and
    // what makes the metric able to discriminate at all.
    const weights = [3, 2, 1];
    let num = 0;
    let den = 0;
    after.forEach((sm, k) => { const w = weights[k] ?? 1; num += sm.quality * w; den += w; });
    recoveries.push((num / den) / local);
  }
  // No failures is not perfect resilience — it is an untested one. Saying
  // otherwise would let an easy session mint an UNBREAKABLE grade.
  if (recoveries.length === 0) return 60;

  const ratio = mean(recoveries);
  return Math.min(100, Math.max(0, 50 + (ratio - 1) * 120));
}

/**
 * ESI — does accuracy hold as load rises?
 *
 * Split by load, compare the high-load half against the low-load half. A flat
 * curve is stable; a collapsing one is not.
 *
 * The subtlety worth stating: this is NOT "how good are you under pressure".
 * It is how much you DROP. A player who is 60% easy and 58% hard scores far
 * better than one who is 95% easy and 60% hard, and that is the correct
 * ordering for a resilience metric even though the second player answered more
 * questions right.
 */
export function computeEsi(samples: PerfSample[]): number {
  if (samples.length < MIN_SAMPLES) return 50;
  const sorted = [...samples].sort((a, b) => a.load - b.load);
  const half = Math.floor(sorted.length / 2);
  const low = sorted.slice(0, half);
  const high = sorted.slice(sorted.length - half);

  const lowQ = mean(low.map((s) => s.quality));
  const highQ = mean(high.map((s) => s.quality));
  if (lowQ <= 0) return 50;

  const retention = highQ / lowQ;

  // Exertion, when a band is supplying it, is the whole point of the metric —
  // holding accuracy at a high heart rate is the thing the product claims to
  // measure. It is a bonus rather than a requirement, because most players
  // will never wear a band and the metric must still mean something.
  const withExertion = samples.filter((s) => s.exertion !== undefined);
  let exertionBonus = 0;
  if (withExertion.length >= MIN_SAMPLES) {
    const hardWork = withExertion.filter((s) => (s.exertion ?? 0) > 0.6);
    if (hardWork.length >= 3) {
      const underLoad = mean(hardWork.map((s) => s.quality));
      exertionBonus = Math.max(-10, Math.min(15, (underLoad / lowQ - 1) * 40));
    }
  }

  return Math.min(100, Math.max(0, 50 + (retention - 1) * 110 + exertionBonus));
}

/**
 * Pacing — do you sustain, or fade?
 *
 * First third against last third, in tick order. Note that IMPROVING scores
 * above 50: a player who finishes stronger than they started has paced well,
 * not merely been inconsistent.
 */
export function computePacing(samples: PerfSample[]): number {
  if (samples.length < MIN_SAMPLES) return 50;
  const ordered = [...samples].sort((a, b) => a.tick - b.tick);
  const third = Math.max(2, Math.floor(ordered.length / 3));
  const first = mean(ordered.slice(0, third).map((s) => s.quality));
  const last = mean(ordered.slice(-third).map((s) => s.quality));
  if (first <= 0) return 50;

  const sustain = last / first;
  // Variance across the whole session, so a player who oscillates wildly but
  // happens to start and end alike is not credited with pacing.
  const qs = ordered.map((s) => s.quality);
  const m = mean(qs);
  const variance = m > 0 ? mean(qs.map((q) => (q - m) ** 2)) / (m * m) : 0;

  return Math.min(100, Math.max(0, 50 + (sustain - 1) * 90 - variance * 60));
}

/**
 * The whole assessment.
 *
 * Mirrors the backend formula exactly so the client can show a number that
 * matches the receipt. The server's value remains authoritative; this exists so
 * the results screen can be honest in the same second the session ends.
 */
export function assessResilience(samples: PerfSample[]): ResilienceScores {
  const confidence = Math.min(1, samples.length / (MIN_SAMPLES * 2));

  if (samples.length < MIN_SAMPLES) {
    return {
      arv: 50, esi: 50, pacing: 50, mri: 50, grade: 'ADAPTING', confidence,
      note: `Only ${samples.length} moments to judge — too short to say anything about resilience.`,
    };
  }

  const arv = computeArv(samples);
  const esi = computeEsi(samples);
  const pacing = computePacing(samples);
  const mri = Math.round(
    (arv * MRI_ARV_WEIGHT + esi * MRI_ESI_WEIGHT + pacing * MRI_PACING_WEIGHT) * 100,
  ) / 100;

  return { arv: Math.round(arv), esi: Math.round(esi), pacing: Math.round(pacing), mri, grade: gradeMri(mri), confidence, note: resilienceNote(arv, esi, pacing) };
}

/**
 * The sentence that makes the number mean something.
 *
 * Names the WEAKEST of the three, because that is the actionable one. A player
 * told "your MRI is 61" learns nothing; one told "you are accurate until it
 * gets hard, then you drop" has been handed something to work on.
 */
export function resilienceNote(arv: number, esi: number, pacing: number): string {
  const lowest = Math.min(arv, esi, pacing);
  if (lowest > 65) return 'You held your level through everything this session threw at you.';
  if (lowest === esi) {
    return 'You are accurate while it is easy and drop when the load rises. Stability under pressure is the gap.';
  }
  if (lowest === arv) {
    return 'One mistake is costing you the next three. Resetting after a miss is the gap.';
  }
  return 'You start strong and fade. Sustaining across a whole session is the gap.';
}

/**
 * Accumulates samples during a session.
 *
 * Deliberately mode-agnostic: a quiz answer, a rally shot, a dodge and a pitch
 * are all just (success, load, quality). That is what lets MRI be measured
 * across the whole product instead of only in the quiz modes — which is what
 * the thesis has always claimed and what nothing has ever delivered.
 */
export class ResilienceTracker {
  private samples: PerfSample[] = [];

  record(s: PerfSample): void { this.samples.push(s); }

  /** Convenience for modes without a quality signal. */
  recordSimple(tick: number, success: boolean, load: number): void {
    this.samples.push({ tick, success, load, quality: success ? 1 : 0 });
  }

  get count(): number { return this.samples.length; }
  get all(): readonly PerfSample[] { return this.samples; }

  assess(): ResilienceScores { return assessResilience(this.samples); }
  reset(): void { this.samples = []; }

  /** The fields a session receipt wants. */
  receiptFields(): { arv: number; esi: number; pacing_score: number } {
    const r = this.assess();
    return { arv: r.arv, esi: r.esi, pacing_score: r.pacing };
  }
}

/**
 * Escalating load for a cognitive mode.
 *
 * Brain Brawl's differentiator is cognitive load UNDER rising pressure, and a
 * quiz that asks ten questions at one difficulty cannot measure that. This
 * ramps time pressure and distraction across a round so ESI has something to
 * read — without it, every load value is identical and ESI is 50 by
 * construction.
 */
export function loadCurve(questionIndex: number, total: number): number {
  if (total <= 1) return 0.5;
  return Math.min(1, 0.2 + (questionIndex / (total - 1)) * 0.8);
}

/** Answer time allowed at a given load. Shrinks as the round escalates. */
export function timeAllowedMs(baseMs: number, load: number): number {
  return Math.round(baseMs * (1.15 - load * 0.55));
}
