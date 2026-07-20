// ExerciseDemo — every exercise in the Coach section SHOWS the movement:
// AVATAR tab (user's own avatar performs it — M17 ExerciseMoviePlayer through
// the M31 character pipeline) and/or VIDEO tab (founder-recorded clip).
// Neither state is ever blank: cue-card fallback included.
//
// Library change: ExerciseDef gains optional `videoUrl`. Convention:
// drop files at /videos/exercises/{exerciseId}.mp4 and set
// `videoUrl: '/videos/exercises/goblet_squat.mp4'` — the tab lights up.

import React, { useState } from 'react';
import type { Scene } from '@babylonjs/core';
import { ExerciseMoviePlayer } from '../workout/ExerciseMoviePlayer';   // M17
import type { LoadedRig } from '../workout/MiniAvatarPreview';          // M17
import type { ExerciseDef, MiniAvatarSpec, ScanReplayClip } from '../workout/contracts';

type Tab = 'avatar' | 'video';

export function ExerciseDemo(props: {
  exercise: ExerciseDef & { videoUrl?: string };
  avatar: MiniAvatarSpec | null;          // null = no scan yet → video/cues only
  replay?: ScanReplayClip | null;
  loadCanonicalRig: (scene: Scene) => Promise<LoadedRig>;
}) {
  const hasAvatar = !!props.avatar;
  const hasVideo = !!props.exercise.videoUrl;
  const [tab, setTab] = useState<Tab>(hasAvatar ? 'avatar' : 'video');
  const [videoFailed, setVideoFailed] = useState(false);

  const showTabs = hasAvatar && hasVideo;

  return (
    <div className="overflow-hidden rounded-2xl border border-slate-700 bg-slate-950">
      {showTabs && (
        <div className="flex border-b border-slate-800">
          {(['avatar', 'video'] as Tab[]).map((t) => (
            <button key={t} onClick={() => setTab(t)}
              className={`flex-1 py-2 text-[11px] font-black tracking-widest ${
                tab === t ? 'bg-slate-800 text-cyan-300' : 'text-slate-500'}`}>
              {t === 'avatar' ? 'YOUR AVATAR' : 'COACH VIDEO'}
            </button>
          ))}
        </div>
      )}

      {/* AVATAR demo — their own look performing the movement */}
      {tab === 'avatar' && hasAvatar && (
        <ExerciseMoviePlayer
          avatar={props.avatar!}
          exercise={props.exercise}
          replay={props.replay ?? null}
          loadCanonicalRig={props.loadCanonicalRig}
        />
      )}

      {/* VIDEO demo — founder-recorded */}
      {tab === 'video' && hasVideo && !videoFailed && (
        <div className="relative">
          <video
            src={props.exercise.videoUrl}
            controls playsInline loop muted autoPlay
            onError={() => setVideoFailed(true)}
            className="aspect-video w-full bg-black"
          />
          <span className="absolute left-2 top-2 rounded bg-black/60 px-2 py-0.5 text-[10px] font-bold tracking-wider text-cyan-300">
            COACH DEMO
          </span>
        </div>
      )}

      {/* Never-blank fallback: cue card with animated diagram strip */}
      {((tab === 'video' && (videoFailed || !hasVideo)) || (tab === 'avatar' && !hasAvatar)) && (
        <div className="p-4">
          <div className="fel-cuecard mb-3 flex h-24 items-center justify-center rounded-xl bg-slate-900">
            <span className="text-4xl">🏋️</span>
          </div>
          {!hasAvatar && (
            <p className="mb-2 text-center text-[11px] text-cyan-300">
              Scan your body in the Lab to see YOURSELF demo every exercise.
            </p>
          )}
        </div>
      )}

      {/* Cues always visible under any demo */}
      <div className="border-t border-slate-800 p-3">
        <h3 className="font-bold">{props.exercise.name}</h3>
        <ul className="mt-1 space-y-0.5">
          {props.exercise.cues.map((c) => (
            <li key={c} className="text-xs text-slate-400">· {c}</li>
          ))}
        </ul>
        {props.exercise.tempo && (
          <p className="mt-1 text-[11px] font-bold text-amber-300">Tempo {props.exercise.tempo}</p>
        )}
      </div>

      <style>{`
        .fel-cuecard { animation: felcue 2.4s ease-in-out infinite; }
        @keyframes felcue { 0%,100% { transform: translateY(0) } 50% { transform: translateY(-4px) } }
      `}</style>
    </div>
  );
}

// WIRE INTO: PlanViewer exercise expansion (replace bare ExerciseMoviePlayer),
// Coach tab exercise browser, and session/seminar detail pages. Avatar spec +
// rig loader come from the M31 character pipeline (resolveIdentity → spec).
