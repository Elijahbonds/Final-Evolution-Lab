// Capture/upload screen: consent → record live or pick a file → client-side pose
// extraction with a live skeleton overlay → submit KEYPOINTS ONLY to the server.

import { useEffect, useRef, useState } from 'react';
import { extractFromFile, extractLive, drawSkeleton, initPose } from './pose/poseExtractor';
import { sampleSkinTone } from '../shared/avatarBuilder';
import type { PoseFrame, ScanSubmission, ScanActivity } from '../shared/contracts';

const ACTIVITIES: { id: ScanActivity; label: string }[] = [
  { id: 'squat_screen', label: 'Movement Screen (squats)' },
  { id: 'jump', label: 'Stress Test — Jumps' },
  { id: 'run', label: 'Stress Test — Running' },
  { id: 'dunk', label: 'Dunking' },
  { id: 'sport_play', label: 'Playing my sport' },
  { id: 'freestyle', label: 'Just moving' },
];

export function ScanCaptureScreen(props: {
  onSubmitted: (scanId: string) => void;   // → ProcessingStatus / PlanViewer
}) {
  const [step, setStep] = useState<'consent' | 'setup' | 'capture' | 'review' | 'uploading'>('consent');
  const [activity, setActivity] = useState<ScanActivity>('squat_screen');
  const [heightCm, setHeightCm] = useState(175);
  const [frames, setFrames] = useState<PoseFrame[]>([]);
  const [skin, setSkin] = useState<string | undefined>();
  const [progress, setProgress] = useState(0);
  const [error, setError] = useState<string | null>(null);

  const videoRef = useRef<HTMLVideoElement>(null);
  const overlayRef = useRef<HTMLCanvasElement>(null);
  const liveRef = useRef<ReturnType<typeof extractLive> | null>(null);

  useEffect(() => { initPose().catch(() => setError('Pose model failed to load')); }, []);

  const overlay = (frame: PoseFrame) => {
    const ctx = overlayRef.current?.getContext('2d');
    if (ctx) drawSkeleton(ctx, frame);
  };

  const startCamera = async () => {
    const stream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: 'environment', width: 1280, height: 720 }, audio: false,
    });
    videoRef.current!.srcObject = stream;
    await videoRef.current!.play();
    liveRef.current = extractLive(videoRef.current!, (f) => {
      overlay(f);
      if (!skin && f.landmarks[16].visibility > 0.7)
        setSkin(sampleSkinTone(videoRef.current!, f));
    });
    setStep('capture');
  };

  const stopCamera = () => {
    const got = liveRef.current?.stop() ?? [];
    (videoRef.current?.srcObject as MediaStream | null)?.getTracks().forEach((t) => t.stop());
    setFrames(got);
    setStep('review');
  };

  const pickFile = async (file: File) => {
    setStep('capture'); setProgress(0);
    try {
      const { frames: got } = await extractFromFile(file, {
        onProgress: setProgress,
        onPreviewFrame: (f, vid) => {
          overlay(f);
          if (!skin && f.landmarks[16].visibility > 0.7) setSkin(sampleSkinTone(vid, f));
        },
      });
      setFrames(got);
      setStep('review');
    } catch (e: any) { setError(e.message); setStep('setup'); }
  };

  const submit = async () => {
    setStep('uploading'); setError(null);
    const sub: ScanSubmission = {
      scanId: `scan_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
      kind: activity === 'squat_screen' ? 'movement_screen' : 'stress_test',
      activity, fps: 24,
      durationMs: frames.length ? frames[frames.length - 1].tMs : 0,
      athleteHeightCm: heightCm,
      frames,
      videoOptIn: false,                 // raw video NEVER uploads in this flow
    };
    try {
      const res = await fetch('/api/workout/scan', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(sub),
      });
      if (!res.ok) throw new Error((await res.json().catch(() => ({})))?.message ?? 'upload failed');
      props.onSubmitted(sub.scanId);
    } catch (e: any) { setError(e.message); setStep('review'); }
  };

  if (step === 'consent') return (
    <div className="mx-auto max-w-md space-y-4 p-6 text-sm">
      <h1 className="text-lg font-black">BEFORE YOU FILM</h1>
      <ul className="space-y-2 text-slate-300">
        <li>· Your video is processed <b>on this device</b>. Only your movement
          skeleton (stick-figure data) is uploaded — never the video itself.</li>
        <li>· We use it to build your mini avatar and your plan. You can delete your
          scan data anytime in Profile.</li>
        <li>· You must be 13+. Under 18? Get a parent/guardian's OK first.</li>
      </ul>
      <button onClick={() => setStep('setup')}
        className="w-full rounded-xl bg-cyan-400 py-3 font-black text-black">I AGREE — CONTINUE</button>
    </div>
  );

  if (step === 'setup') return (
    <div className="mx-auto max-w-md space-y-4 p-6">
      <h1 className="text-lg font-black">WHAT ARE YOU FILMING?</h1>
      <div className="grid grid-cols-2 gap-2">
        {ACTIVITIES.map((a) => (
          <button key={a.id} onClick={() => setActivity(a.id)}
            className={`rounded-xl border p-3 text-left text-sm ${activity === a.id ? 'border-cyan-400 bg-cyan-950' : 'border-slate-700'}`}>
            {a.label}
          </button>
        ))}
      </div>
      <label className="block text-sm text-slate-300">
        Your height (cm) — used to scale your avatar and measure your jump
        <input type="number" value={heightCm} min={100} max={230}
          onChange={(e) => setHeightCm(+e.target.value)}
          className="mt-1 w-full rounded-lg bg-slate-800 p-2" />
      </label>
      <div className="flex gap-2">
        <button onClick={startCamera} className="flex-1 rounded-xl bg-cyan-400 py-3 font-black text-black">RECORD NOW</button>
        <label className="flex-1 cursor-pointer rounded-xl border border-slate-600 py-3 text-center font-black">
          UPLOAD VIDEO
          <input type="file" accept="video/*" className="hidden"
            onChange={(e) => e.target.files?.[0] && pickFile(e.target.files[0])} />
        </label>
      </div>
      <p className="text-xs text-slate-500">Tip: phone propped sideways, full body in frame, 10–30 seconds.</p>
      {error && <p className="text-sm text-rose-400">{error}</p>}
    </div>
  );

  return (
    <div className="mx-auto max-w-md space-y-3 p-4">
      <div className="relative overflow-hidden rounded-2xl bg-black">
        <video ref={videoRef} playsInline muted className="w-full" />
        <canvas ref={overlayRef} width={1280} height={720}
          className="pointer-events-none absolute inset-0 h-full w-full" />
        {step === 'capture' && progress > 0 && (
          <div className="absolute bottom-0 h-1 bg-cyan-400" style={{ width: `${progress * 100}%` }} />
        )}
      </div>

      {step === 'capture' && liveRef.current && (
        <button onClick={stopCamera} className="w-full rounded-xl bg-rose-500 py-3 font-black">STOP RECORDING</button>
      )}
      {step === 'review' && (
        <>
          <p className="text-center text-sm text-slate-300">
            Captured <b>{frames.length}</b> tracked frames
            {frames.length < 24 && ' — too short, film at least 1 second'}
          </p>
          <div className="flex gap-2">
            <button onClick={() => setStep('setup')} className="flex-1 rounded-xl border border-slate-600 py-3 font-bold">REDO</button>
            <button disabled={frames.length < 24} onClick={submit}
              className="flex-1 rounded-xl bg-cyan-400 py-3 font-black text-black disabled:opacity-40">
              BUILD MY AVATAR →
            </button>
          </div>
        </>
      )}
      {step === 'uploading' && <p className="text-center text-sm text-slate-300">Uploading your movement data…</p>}
      {error && <p className="text-center text-sm text-rose-400">{error}</p>}
    </div>
  );
}
