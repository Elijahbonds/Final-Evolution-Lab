// The deliverable screen: the athlete's personalized plan, animated by their own
// mini avatar. Week strip → day cards → exercise list, each exercise expandable
// into an ExerciseMoviePlayer mini-movie.

import { useEffect, useState } from 'react';
import { ExerciseMoviePlayer } from './ExerciseMoviePlayer';
import type { LoadedRig } from './MiniAvatarPreview';
import type { Scene } from '@babylonjs/core';
import { EXERCISES } from '../shared/exerciseLibrary';
import type { WorkoutPlan, ScanReplayClip } from '../shared/contracts';

export function PlanViewer(props: {
  loadCanonicalRig: (scene: Scene) => Promise<LoadedRig>;
}) {
  const [plan, setPlan] = useState<WorkoutPlan | null>(null);
  const [replay, setReplay] = useState<ScanReplayClip | null>(null);
  const [week, setWeek] = useState(0);
  const [day, setDay] = useState(0);
  const [openEx, setOpenEx] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetch('/api/workout/plan')
      .then(async (r) => { if (!r.ok) throw new Error('No plan yet'); return r.json(); })
      .then(({ plan, replay }) => { setPlan(plan); setReplay(replay); })
      .catch((e) => setError(e.message));
  }, []);

  if (error) return <p className="p-6 text-center text-sm text-slate-400">{error}</p>;
  if (!plan) return <p className="p-6 text-center text-sm text-slate-400">Loading your plan…</p>;

  const wk = plan.weeks[week];
  const d = wk.days[Math.min(day, wk.days.length - 1)];

  return (
    <div className="mx-auto max-w-md space-y-4 p-4">
      <header>
        <h1 className="text-lg font-black tracking-wide">
          {plan.product === 'program_12w' ? 'YOUR 12-WEEK PROGRAM' : 'YOUR 4-WEEK PLAN'}
        </h1>
        <p className="mt-1 text-xs text-slate-400">{plan.basedOn.summary}</p>
      </header>

      {/* Week strip */}
      <div className="flex gap-1 overflow-x-auto pb-1">
        {plan.weeks.map((w, i) => (
          <button key={i} onClick={() => { setWeek(i); setDay(0); }}
            className={`shrink-0 rounded-full px-3 py-1 text-[11px] font-bold ${
              i === week ? 'bg-cyan-400 text-black' : 'bg-slate-800 text-slate-300'}`}>
            W{i + 1} · {w.theme}
          </button>
        ))}
      </div>

      {/* Day tabs */}
      <div className="flex gap-1">
        {wk.days.map((dd, i) => (
          <button key={i} onClick={() => setDay(i)}
            className={`flex-1 rounded-lg px-2 py-2 text-[11px] font-bold ${
              i === day ? 'bg-slate-700 text-white' : 'bg-slate-900 text-slate-400'}`}>
            {dd.label.split('—')[0].trim()}
          </button>
        ))}
      </div>

      <div className="rounded-xl bg-slate-900 p-3">
        <h2 className="text-sm font-bold">{d.label}</h2>
        <p className="text-[11px] text-slate-400">~{d.estMinutes} min</p>
      </div>

      {d.blocks.map((block) => (
        <section key={block.title}>
          <h3 className="mb-1 text-[11px] font-black tracking-widest text-slate-500">
            {block.title.toUpperCase()}
          </h3>
          <div className="space-y-2">
            {block.exercises.map((pe) => {
              const def = EXERCISES[pe.exerciseId];
              if (!def) return null;
              const open = openEx === pe.exerciseId;
              return (
                <div key={pe.exerciseId}>
                  <button
                    onClick={() => setOpenEx(open ? null : pe.exerciseId)}
                    className="flex w-full items-center justify-between rounded-xl bg-slate-800 p-3 text-left"
                  >
                    <span className="text-sm font-semibold">{def.name}</span>
                    <span className="font-mono text-xs text-cyan-300">
                      {pe.sets}×{pe.reps}
                    </span>
                  </button>
                  {open && (
                    <div className="mt-2">
                      <ExerciseMoviePlayer
                        avatar={plan.athleteAvatar}
                        exercise={def}
                        replay={def.targets.some((t) => plan.basedOn.deficits.includes(t)) ? replay : null}
                        loadCanonicalRig={props.loadCanonicalRig}
                      />
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </section>
      ))}

      <p className="pb-6 text-center text-[11px] leading-4 text-slate-500">
        Movies are AI-generated depictions of your avatar. Training guidance, not
        medical advice — stop if you feel pain and consult a professional.
      </p>
    </div>
  );
}
