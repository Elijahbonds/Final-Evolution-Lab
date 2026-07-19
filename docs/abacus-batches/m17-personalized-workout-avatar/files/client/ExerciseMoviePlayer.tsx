// Mini-movie player: the athlete's avatar performs an exercise clip with an
// authored camera angle. Also supports "MY SCAN" mode: replays the athlete's own
// retargeted movement (ScanReplayClip) on their avatar, side-by-side with target
// form — their movement, starring them.

import { useRef, useState } from 'react';
import { MiniAvatarPreview, type LoadedRig } from './MiniAvatarPreview';
import type { Scene } from '@babylonjs/core';
import { Quaternion, Vector3 } from '@babylonjs/core';
import type { MiniAvatarSpec, ScanReplayClip, ExerciseDef } from '../shared/contracts';

/** Drive the rig directly from a ScanReplayClip (bypasses the clip registry). */
function playReplay(rig: LoadedRig, replay: ScanReplayClip): () => void {
  let raf = 0; const t0 = performance.now();
  const dur = replay.frames[replay.frames.length - 1]?.tMs ?? 0;
  const nodeOf = (bone: string) =>
    rig.skeleton.bones.find((b) => b.name === bone)?.getTransformNode();

  const tick = () => {
    const t = (performance.now() - t0) % Math.max(dur, 1);
    // nearest-frame lookup; 24 Hz + EMA smoothing upstream reads fine
    let f = replay.frames[0];
    for (const fr of replay.frames) { if (fr.tMs <= t) f = fr; else break; }
    for (const [bone, q] of Object.entries(f.rotations)) {
      const node = nodeOf(bone);
      if (node) node.rotationQuaternion = new Quaternion(q[0], q[1], q[2], q[3]);
    }
    const hips = nodeOf('mixamorig:Hips');
    if (hips) hips.position = new Vector3(...f.rootPos);
    raf = requestAnimationFrame(tick);
  };
  raf = requestAnimationFrame(tick);
  return () => cancelAnimationFrame(raf);
}

export function ExerciseMoviePlayer(props: {
  avatar: MiniAvatarSpec;
  exercise: ExerciseDef;
  replay?: ScanReplayClip | null;      // the athlete's own scan, when relevant
  loadCanonicalRig: (scene: Scene) => Promise<LoadedRig>;
}) {
  const [mode, setMode] = useState<'target' | 'mine'>('target');
  const stopReplay = useRef<(() => void) | null>(null);

  const onRig = (rig: LoadedRig) => {
    stopReplay.current?.();
    if (mode === 'mine' && props.replay) {
      rig.stopClips();
      stopReplay.current = playReplay(rig, props.replay);
    }
  };

  return (
    <div className="overflow-hidden rounded-2xl border border-slate-700 bg-slate-950">
      <div className="relative">
        <MiniAvatarPreview
          key={mode}                            // remount on mode switch
          spec={props.avatar}
          clip={mode === 'target' ? props.exercise.clip : undefined}
          loop
          loadCanonicalRig={props.loadCanonicalRig}
          onRig={onRig}
          className="h-64 w-full"
        />
        <span className="absolute left-2 top-2 rounded bg-black/60 px-2 py-0.5 text-[10px] font-bold tracking-wider text-cyan-300">
          {mode === 'target' ? 'TARGET FORM' : 'MY SCAN'} · AI-GENERATED
        </span>
        {props.replay && (
          <button
            onClick={() => setMode(mode === 'target' ? 'mine' : 'target')}
            className="absolute right-2 top-2 rounded-full bg-cyan-400 px-3 py-1 text-[11px] font-black text-black"
          >
            {mode === 'target' ? 'SEE MY SCAN' : 'SEE TARGET'}
          </button>
        )}
      </div>
      <div className="p-3">
        <h3 className="font-bold">{props.exercise.name}</h3>
        <p className="mt-1 text-xs text-slate-400">{props.exercise.cues[0]}</p>
      </div>
    </div>
  );
}
