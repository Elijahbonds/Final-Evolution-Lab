// Client-side pose extraction: video file/stream → PoseFrame timeline.
// Runs entirely in the browser via MediaPipe Tasks Vision — raw video never uploads.

import {
  FilesetResolver,
  PoseLandmarker,
  type PoseLandmarkerResult,
} from '@mediapipe/tasks-vision';
import type { PoseFrame, Landmark } from '../../shared/contracts';

const WASM_CDN =
  'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@latest/wasm';
const MODEL_URL =
  'https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_full/float16/latest/pose_landmarker_full.task';

// Self-host both assets in production (CSP + reliability); URLs kept here so the
// package runs out of the box.

let landmarker: PoseLandmarker | null = null;

export async function initPose(): Promise<void> {
  if (landmarker) return;
  const vision = await FilesetResolver.forVisionTasks(WASM_CDN);
  landmarker = await PoseLandmarker.createFromOptions(vision, {
    baseOptions: { modelAssetPath: MODEL_URL, delegate: 'GPU' },
    runningMode: 'VIDEO',
    numPoses: 1,
    minPoseDetectionConfidence: 0.5,
    minPosePresenceConfidence: 0.5,
    minTrackingConfidence: 0.5,
  });
}

function toFrame(res: PoseLandmarkerResult, tMs: number): PoseFrame | null {
  const world = res.worldLandmarks?.[0];
  const view = res.landmarks?.[0];
  if (!world || !view) return null;
  const landmarks: Landmark[] = world.map((w, i) => ({
    x: w.x, y: w.y, z: w.z,
    vx: view[i].x, vy: view[i].y,
    visibility: view[i].visibility ?? 0,
  }));
  return { tMs, landmarks };
}

/**
 * Extract pose frames from a recorded video File at a target sample rate.
 * Seek-decode loop: deterministic timing, works on any container the browser plays.
 * onProgress: 0..1. onPreviewFrame: for drawing the skeleton overlay during extract.
 */
export async function extractFromFile(
  file: File,
  opts: {
    sampleFps?: number;
    onProgress?: (p: number) => void;
    onPreviewFrame?: (frame: PoseFrame, video: HTMLVideoElement) => void;
  } = {},
): Promise<{ frames: PoseFrame[]; fps: number; durationMs: number }> {
  await initPose();
  const sampleFps = opts.sampleFps ?? 24;             // 24 Hz is plenty for gait/jump analysis
  const video = document.createElement('video');
  video.muted = true;
  video.playsInline = true;
  video.src = URL.createObjectURL(file);
  await new Promise<void>((res, rej) => {
    video.onloadedmetadata = () => res();
    video.onerror = () => rej(new Error('Could not decode video'));
  });

  const durationMs = video.duration * 1000;
  const stepMs = 1000 / sampleFps;
  const frames: PoseFrame[] = [];

  for (let t = 0; t < durationMs; t += stepMs) {
    video.currentTime = t / 1000;
    await new Promise<void>((res) => { video.onseeked = () => res(); });
    // detectForVideo requires monotonically increasing timestamps
    const result = landmarker!.detectForVideo(video, t);
    const frame = toFrame(result, t);
    if (frame) {
      frames.push(frame);
      opts.onPreviewFrame?.(frame, video);
    }
    opts.onProgress?.(t / durationMs);
  }

  URL.revokeObjectURL(video.src);
  opts.onProgress?.(1);
  return { frames, fps: sampleFps, durationMs };
}

/**
 * Live-camera extraction for in-app recording. Returns a stop() that resolves the
 * collected frames. Caller owns the <video> element showing the camera stream.
 */
export function extractLive(
  video: HTMLVideoElement,
  onFrame?: (frame: PoseFrame) => void,
): { stop: () => PoseFrame[] } {
  const frames: PoseFrame[] = [];
  let running = true;
  const t0 = performance.now();

  const loop = () => {
    if (!running) return;
    if (video.readyState >= 2) {
      const tMs = performance.now() - t0;
      const result = landmarker!.detectForVideo(video, tMs);
      const frame = toFrame(result, tMs);
      if (frame) { frames.push(frame); onFrame?.(frame); }
    }
    requestAnimationFrame(loop);
  };
  requestAnimationFrame(loop);

  return { stop: () => { running = false; return frames; } };
}

/** Draw a skeleton overlay for the current frame onto a canvas over the video. */
export function drawSkeleton(ctx: CanvasRenderingContext2D, frame: PoseFrame): void {
  const C = PoseLandmarker.POSE_CONNECTIONS;
  const w = ctx.canvas.width, h = ctx.canvas.height;
  ctx.clearRect(0, 0, w, h);
  ctx.strokeStyle = '#22d3ee'; ctx.lineWidth = 3; ctx.lineCap = 'round';
  for (const { start, end } of C) {
    const a = frame.landmarks[start], b = frame.landmarks[end];
    if (a.visibility < 0.4 || b.visibility < 0.4) continue;
    ctx.beginPath();
    ctx.moveTo(a.vx * w, a.vy * h);
    ctx.lineTo(b.vx * w, b.vy * h);
    ctx.stroke();
  }
}
