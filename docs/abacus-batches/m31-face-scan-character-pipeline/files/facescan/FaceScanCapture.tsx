// FaceScanCapture — selfie via camera or photo upload → FaceLandmarker
// (client-side; the image never uploads) → FaceConfig → hands off to the
// Closet pre-filled. Mount as the "SCAN MY FACE" step in the Scan tab.

import React, { useEffect, useRef, useState } from 'react';
import { FilesetResolver, FaceLandmarker } from '@mediapipe/tasks-vision';
import { faceFromLandmarks, sampleCheekTone, type FaceLandmark } from './faceFromLandmarks';
import type { FaceConfig } from '../closet/closetContracts';

const WASM_CDN = 'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@latest/wasm';
const MODEL_URL =
  'https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/latest/face_landmarker.task';
// Self-host both in production (CSP + reliability).

let landmarker: FaceLandmarker | null = null;
async function init(): Promise<void> {
  if (landmarker) return;
  const vision = await FilesetResolver.forVisionTasks(WASM_CDN);
  landmarker = await FaceLandmarker.createFromOptions(vision, {
    baseOptions: { modelAssetPath: MODEL_URL, delegate: 'GPU' },
    runningMode: 'IMAGE',
    numFaces: 1,
  });
}

export function FaceScanCapture(props: {
  onFace: (face: FaceConfig) => void;      // → open Closet with this pre-applied
  onSkip: () => void;
}) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [phase, setPhase] = useState<'consent' | 'camera' | 'detecting' | 'error'>('consent');
  const [error, setError] = useState('');

  useEffect(() => { void init().catch(() => setError('Face model failed to load')); }, []);

  const startCamera = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'user', width: 960, height: 960 }, audio: false,
      });
      videoRef.current!.srcObject = stream;
      await videoRef.current!.play();
      setPhase('camera');
    } catch { setError('Camera unavailable — upload a photo instead.'); }
  };

  const stopCamera = () =>
    (videoRef.current?.srcObject as MediaStream | null)?.getTracks().forEach((t) => t.stop());

  const detectFrom = async (source: HTMLVideoElement | HTMLImageElement) => {
    setPhase('detecting');
    await init();
    const res = landmarker!.detect(source);
    const lm = res.faceLandmarks?.[0] as FaceLandmark[] | undefined;
    if (!lm) {
      setError('No face found — face the camera in good light and try again.');
      setPhase('error');
      return;
    }
    const tone = sampleCheekTone(source, lm);
    const face = faceFromLandmarks(lm, tone);
    stopCamera();
    props.onFace(face);
  };

  const capture = () => { if (videoRef.current) void detectFrom(videoRef.current); };

  const onFile = (f: File) => {
    const img = new Image();
    img.onload = () => { void detectFrom(img); URL.revokeObjectURL(img.src); };
    img.src = URL.createObjectURL(f);
  };

  if (phase === 'consent') return (
    <div className="mx-auto max-w-md space-y-4 p-6 text-sm">
      <h1 className="text-lg font-black">SCAN YOUR FACE</h1>
      <ul className="space-y-2 text-slate-300">
        <li>· One selfie builds your avatar's face — processed <b>on this device</b>.
          The photo itself never uploads.</li>
        <li>· You'll fine-tune everything in the Closet after; nothing is final.</li>
        <li>· Delete-my-data in Profile clears your face settings anytime.</li>
      </ul>
      <button onClick={startCamera} className="w-full rounded-xl bg-cyan-400 py-3 font-black text-black">
        OPEN CAMERA
      </button>
      <label className="block w-full cursor-pointer rounded-xl border border-slate-600 py-3 text-center font-black">
        UPLOAD A PHOTO
        <input type="file" accept="image/*" className="hidden"
          onChange={(e) => e.target.files?.[0] && onFile(e.target.files[0])} />
      </label>
      <button onClick={props.onSkip} className="w-full text-center text-xs text-slate-500">
        Skip — I'll build my face by hand
      </button>
      {error && <p className="text-rose-400">{error}</p>}
    </div>
  );

  return (
    <div className="mx-auto max-w-md space-y-3 p-4">
      <div className="relative overflow-hidden rounded-2xl bg-black">
        <video ref={videoRef} playsInline muted className="w-full scale-x-[-1]" />
        <div className="pointer-events-none absolute inset-0 rounded-2xl border-4 border-cyan-400/40" />
        <div className="pointer-events-none absolute left-1/2 top-1/2 h-64 w-48 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-dashed border-white/50" />
      </div>
      {phase === 'camera' && (
        <button onClick={capture} className="w-full rounded-xl bg-cyan-400 py-3 font-black text-black">
          CAPTURE ▸
        </button>
      )}
      {phase === 'detecting' && <p className="text-center text-sm text-slate-300">Reading your features…</p>}
      {phase === 'error' && (
        <>
          <p className="text-center text-sm text-rose-400">{error}</p>
          <button onClick={() => setPhase('camera')} className="w-full rounded-xl border border-slate-600 py-3 font-black">
            TRY AGAIN
          </button>
        </>
      )}
    </div>
  );
}
