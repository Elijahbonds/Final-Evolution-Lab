// Plan generator: ScreenResult + product tier → WorkoutPlan.
// Deterministic rules engine (same inputs → same plan) so support can reproduce any
// athlete's plan. 4-week tier = deficit correction; 12-week tier = 3 phases
// (correct → build → express) with progressions from the library.

import type {
  ScreenResult, WorkoutPlan, WorkoutDay, PlannedExercise, Deficit, MiniAvatarSpec,
} from './contracts';
import { EXERCISES, forDeficit } from './exerciseLibrary';

const WARMUP_POOL = ['worlds_greatest_stretch', 'ankle_rock', 'deep_squat_hold', 'a_skip'];

function planned(exerciseId: string, sets: number, reps: string, restSec = 60): PlannedExercise {
  return { exerciseId, sets, reps, restSec, cueIndex: 0 };
}

/** Pick n exercises for a deficit, skipping ones already used this week. */
function pick(d: Deficit, n: number, used: Set<string>): PlannedExercise[] {
  const out: PlannedExercise[] = [];
  for (const ex of forDeficit(d)) {
    if (out.length >= n) break;
    if (used.has(ex.id)) continue;
    used.add(ex.id);
    const isHold = ex.tempo?.includes('hold') || ex.id.includes('hold');
    const isPower = ex.targets.includes('reactive_power') || ex.targets.includes('elastic_stiffness');
    out.push(planned(
      ex.id,
      isPower ? 4 : 3,
      isHold ? '30s hold' : isPower ? '5' : ex.id.includes('single') || ex.id.includes('split') ? '8/side' : '10',
      isPower ? 90 : 60,
    ));
  }
  return out;
}

function dayFor(focus: Deficit[], dayIdx: number, intensity: number): WorkoutDay {
  const used = new Set<string>();
  const warm = WARMUP_POOL.slice(dayIdx % 2, (dayIdx % 2) + 2).map((id) => planned(id, 1, '45s', 20));
  const main = focus.flatMap((d) => pick(d, 2, used));
  // Finisher expresses power once the base is in — scaled by intensity week
  const finisher = intensity >= 2
    ? pick('reactive_power', 1, used)
    : [planned('dead_bug', 2, '8/side', 45)];

  const label = `Day ${dayIdx + 1} — ${focus.map((f) => f.replace(/_/g, ' ')).join(' + ')}`;
  const est = 8 + main.length * 4 + finisher.length * 4;
  return {
    label,
    focus,
    blocks: [
      { title: 'Prime', exercises: warm },
      { title: 'Build', exercises: main },
      { title: 'Express', exercises: finisher },
    ],
    estMinutes: Math.min(est, 40),
  };
}

function fourWeeks(result: ScreenResult): WorkoutPlan['weeks'] {
  const d = result.deficits;
  const primary = d.slice(0, 2);
  const secondary = d.length > 2 ? d.slice(2, 4) : primary;
  return [0, 1, 2, 3].map((w) => ({
    theme: ['Foundation', 'Load', 'Intensify', 'Test Week'][w],
    days: [
      dayFor(primary, 0, w),
      dayFor(secondary, 1, w),
      dayFor([...primary.slice(0, 1), ...secondary.slice(0, 1)] as Deficit[], 2, w),
    ],
  }));
}

function twelveWeeks(result: ScreenResult): WorkoutPlan['weeks'] {
  // Phase 1 (wk 1–4): correct deficits. Phase 2 (5–8): build capacity with
  // progressions. Phase 3 (9–12): express power + retest.
  const base = fourWeeks(result);
  const progressed = base.map((wk, i) => ({
    theme: `Build ${i + 1}`,
    days: wk.days.map((day) => ({
      ...day,
      blocks: day.blocks.map((b) => ({
        ...b,
        exercises: b.exercises.map((pe) => {
          const def = EXERCISES[pe.exerciseId];
          return def?.progression
            ? { ...pe, exerciseId: def.progression }
            : { ...pe, sets: Math.min(pe.sets + 1, 5) };
        }),
      })),
    })),
  }));
  const express = base.map((wk, i) => ({
    theme: i === 3 ? 'Retest Week — new scan unlocked' : `Express ${i + 1}`,
    days: wk.days.map((day) => ({
      ...day,
      blocks: day.blocks.map((b) =>
        b.title === 'Express'
          ? { ...b, exercises: [planned('depth_jump', 4, '5', 90), planned('broad_jump', 3, '5', 90)] }
          : b,
      ),
    })),
  }));
  return [...base, ...progressed, ...express];
}

export function generatePlan(
  result: ScreenResult,
  avatar: MiniAvatarSpec,
  product: 'workout_4w' | 'program_12w',
): WorkoutPlan {
  return {
    planId: `plan_${result.scanId}_${product}`,
    product,
    athleteAvatar: avatar,
    basedOn: result,
    weeks: product === 'workout_4w' ? fourWeeks(result) : twelveWeeks(result),
    createdAt: new Date().toISOString(),
  };
}
