// IrlUploadScreen — film or pick a real dunk clip; pose keypoints are
// extracted ON DEVICE (M31 MediaPipe loader) and ONLY the keypoints upload.
// The video never leaves the phone. Judges score the same card as in-game.

import React, { useRef, useState } from 'react';
import type { JudgeScorecard } from '../shared/arenaContracts';

// M31 seam: returns a ready PoseLandmarker (VIDEO running mode).
import { loadPoseLandmarker } from '../scan/characterPipeline';

interface PoseFrame { tMs: number; landmarks: { x: number; y: number; z: number; visibility: number }[] }

type Stage = 'pick' | 'extracting' | 'submitting' | 'scored' | 'review' | 'error';

export function IrlUploadScreen(props: { contestId: string; athleteHeightCm: number; onBack: () => void }) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [stage, setStage] = useState<Stage>('pick');
  const [progress, setProgress] = useState(0);
  const [card, setCard] = useState<JudgeScorecard | null>(null);
  const [message, setMessage] = useState('');

  const onFile = async (file: File) => {
    const video = videoRef.current!;
    try {
      setStage('extracting'); setProgress(0);
      video.src = URL.createObjectURL(file);
      await new Promise<void>((res, rej) => {
        video.onloadedmetadata = () => res();
        video.onerror = () => rej(new Error('could not read that video'));
      });
      if (video.duration > 30) throw new Error('clip too long — trim to the dunk (≤30s)');

      const landmarker = await loadPoseLandmarker();
      const frames: PoseFrame[] = [];
      const fps = 24;
      const total = Math.floor(video.duration * fps);
      for (let i = 0; i < total; i++) {
        video.currentTime = i / fps;
        await new Promise<void>((res) => { video.onseeked = () => res(); });
        const result = landmarker.detectForVideo(video, i * (1000 / fps));
        const lm = result.landmarks?.[0];
        if (lm) {
          frames.push({
            tMs: Math.round(i * (1000 / fps)),
            landmarks: lm.map((p: { x: number; y: number; z: number; visibility?: number }) => ({
              x: p.x, y: p.y, z: p.z, visibility: p.visibility ?? 1,
            })),
          });
        }
        if (i % 8 === 0) setProgress(Math.round((i / total) * 100));
      }
      if (frames.length < 12) throw new Error('couldn’t track a full body — refilm with your whole body in frame');

      setStage('submitting');
      const res = await fetch(`/api/arena/${props.contestId}/irl-submit`, {
        method: 'POST', headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ frames, athleteHeightCm: props.athleteHeightCm }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.message ?? 'submission failed');
      if (data.scorecard) { setCard(data.scorecard); setStage(data.needsHumanReview ? 'review' : 'scored'); }
      else { setMessage(data.reason ?? 'needs another take'); setStage('review'); }
    } catch (e) {
      setMessage(e instanceof Error ? e.message : 'something went wrong');
      setStage('error');
    } finally {
      URL.revokeObjectURL(video.src);
    }
  };

  return (
    <div className="mx-auto max-w-md space-y-4 p-4">
      <header>
        <button onClick={props.onBack} className="text-xs text-slate-400">← Arena</button>
        <h1 className="text-lg font-black">IRL PROVING GROUND</h1>
        <p className="text-xs text-slate-400">
          Film your dunk. Analysis runs on your phone — only movement data uploads, never the video.
        </p>
      </header>

      <video ref={videoRef} muted playsInline className="hidden" />

      {stage === 'pick' && (
        <>
          <ul className="space-y-1 rounded-2xl bg-slate-900 p-4 text-xs text-slate-300">
            <li>• Whole body in frame, side-on to the hoop</li>
            <li>• Steady phone (prop it or use a friend)</li>
            <li>• One dunk per clip, ≤30 seconds</li>
          </ul>
          <label className="block">
            <input type="file" accept="video/*" capture="environment" className="hidden"
              onChange={(e) => e.target.files?.[0] && onFile(e.target.files[0])} />
            <span className="block w-full cursor-pointer rounded-xl bg-cyan-400 py-3 text-center font-black text-black">
              FILM / PICK YOUR DUNK
            </span>
          </label>
        </>
      )}

      {(stage === 'extracting' || stage === 'submitting') && (
        <div className="rounded-2xl bg-slate-900 p-6 text-center">
          <p className="font-bold">{stage === 'extracting' ? 'Reading your movement…' : 'Judges are watching…'}</p>
          <div className="mx-auto mt-3 h-2 w-48 rounded-full bg-slate-800">
            <div className="h-2 rounded-full bg-cyan-400 transition-all" style={{ width: `${stage === 'submitting' ? 100 : progress}%` }} />
          </div>
          <p className="mt-2 text-[10px] text-slate-500">Video stays on this device.</p>
        </div>
      )}

      {card && (stage === 'scored' || stage === 'review') && (
        <div className="rounded-2xl border border-slate-600 bg-slate-950 p-4">
          <p className="text-center text-[10px] font-black tracking-widest text-slate-400">
            {stage === 'review' ? 'PROVISIONAL — HUMAN REVIEW PENDING' : 'THE JUDGES HAVE SCORED'}
          </p>
          <p className="my-1 text-center text-4xl font-black text-amber-300">{card.grandTotal}</p>
          {card.metrics.jumpHeightCm && (
            <p className="text-center text-sm text-slate-300">
              <b>{card.metrics.jumpHeightCm} cm</b> vertical · <b>{card.metrics.hangTimeMs} ms</b> hang time
            </p>
          )}
          <div className="mt-3 space-y-2">
            {card.scores.map((s) => (
              <p key={s.judgeId} className="rounded-xl bg-slate-900 p-3 text-xs">
                <b className="capitalize">{s.judgeId}</b> · <span className="text-amber-300">{s.total}</span>
                <span className="ml-2 italic text-slate-300">“{s.commentary}”</span>
              </p>
            ))}
          </div>
          <button onClick={props.onBack} className="mt-3 w-full rounded-xl bg-slate-700 py-2 text-sm font-bold">
            SEE LEADERBOARD
          </button>
        </div>
      )}

      {(stage === 'error' || (stage === 'review' && !card)) && (
        <div className="rounded-2xl border border-amber-500/50 bg-amber-500/10 p-4">
          <p className="text-sm font-bold text-amber-300">{message}</p>
          <button onClick={() => { setStage('pick'); setMessage(''); }}
            className="mt-2 w-full rounded-xl bg-slate-700 py-2 text-sm font-bold">TRY ANOTHER CLIP</button>
        </div>
      )}
    </div>
  );
}
