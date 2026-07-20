// faceFromLandmarks — MediaPipe FaceLandmarker (478 pts) → M20 FaceConfig.
// The scan PROPOSES slider values; the Closet lets the player fix anything.
// All ratios are normalized against inter-temple width so distance/zoom cancel.

import type { FaceConfig } from '../../creator/CreatorCardTypes' /* or closetContracts */;
import { DEFAULT_FACE } from '../closet/closetContracts';

export interface FaceLandmark { x: number; y: number; z: number }

// Canonical FaceLandmarker indices (MediaPipe face mesh topology)
const IDX = {
  templeL: 127, templeR: 356,          // face width reference
  jawL: 172, jawR: 397, chin: 152,
  cheekL: 205, cheekR: 425,
  eyeL_outer: 33, eyeL_inner: 133, eyeL_top: 159, eyeL_bottom: 145,
  eyeR_outer: 263, eyeR_inner: 362,
  browL_top: 105, browL_bottom: 52, browL_inner: 107, browL_outer: 70,
  noseTop: 168, noseTip: 1, noseL: 98, noseR: 327,
  mouthL: 61, mouthR: 291, lipTop: 13, lipBottom: 14,
  forehead: 10,
} as const;

const dist = (a: FaceLandmark, b: FaceLandmark) =>
  Math.hypot(a.x - b.x, a.y - b.y, a.z - b.z);

/** Map a measured ratio into a 0..1 slider given the human-typical range. */
const slider = (value: number, lo: number, hi: number): number =>
  Math.min(1, Math.max(0, (value - lo) / (hi - lo)));

export function faceFromLandmarks(
  lm: FaceLandmark[],
  skinToneHex?: string,
): FaceConfig {
  if (!lm || lm.length < 468) return { ...DEFAULT_FACE, skinTone: skinToneHex ?? DEFAULT_FACE.skinTone };
  const P = (i: number) => lm[i];
  const faceW = dist(P(IDX.templeL), (P(IDX.templeR)));            // normalizer
  const n = (v: number) => v / Math.max(faceW, 1e-6);

  const faceH = n(dist(P(IDX.forehead), P(IDX.chin)));
  const jawW = n(dist(P(IDX.jawL), P(IDX.jawR)));
  const cheekW = n(dist(P(IDX.cheekL), P(IDX.cheekR)));

  const eyeW = n(dist(P(IDX.eyeL_outer), P(IDX.eyeL_inner)));
  const eyeH = n(dist(P(IDX.eyeL_top), P(IDX.eyeL_bottom)));
  const eyeSpacing = n(dist(P(IDX.eyeL_inner), P(IDX.eyeR_inner)));

  const browThick = n(dist(P(IDX.browL_top), P(IDX.browL_bottom)));
  const browAngle = Math.atan2(
    P(IDX.browL_outer).y - P(IDX.browL_inner).y,
    Math.abs(P(IDX.browL_outer).x - P(IDX.browL_inner).x) || 1e-6,
  );

  const noseW = n(dist(P(IDX.noseL), P(IDX.noseR)));
  const noseLen = n(dist(P(IDX.noseTop), P(IDX.noseTip)));
  const bridge = n(Math.abs(P(IDX.noseTop).z - P(IDX.noseTip).z));

  const mouthW = n(dist(P(IDX.mouthL), P(IDX.mouthR)));
  const lipFull = n(dist(P(IDX.lipTop), P(IDX.lipBottom)));

  return {
    ...DEFAULT_FACE,
    skinTone: skinToneHex ?? DEFAULT_FACE.skinTone,
    faceShape: {
      width: slider(1 / Math.max(faceH, 0.6), 0.72, 1.05),   // wider face = shorter H ratio
      jaw: slider(jawW, 0.55, 0.85),
      cheeks: slider(cheekW, 0.6, 0.92),
    },
    eyes: {
      shape: slider(eyeH / Math.max(eyeW, 1e-6), 0.18, 0.45),
      size: slider(eyeW, 0.16, 0.26),
      spacing: slider(eyeSpacing, 0.14, 0.26),
      color: DEFAULT_FACE.eyes.color,        // iris color left to the player
    },
    brows: {
      thickness: slider(browThick, 0.015, 0.05),
      angle: slider(browAngle, -0.25, 0.25),
      color: DEFAULT_FACE.brows.color,
    },
    nose: {
      width: slider(noseW, 0.14, 0.26),
      length: slider(noseLen, 0.18, 0.32),
      bridge: slider(bridge, 0.01, 0.08),
    },
    mouth: {
      width: slider(mouthW, 0.28, 0.46),
      lipFullness: slider(lipFull, 0.01, 0.06),
      smileRest: DEFAULT_FACE.mouth.smileRest,
    },
  };
}

/** Sample skin tone from the cheek region of the source image (client-only). */
export function sampleCheekTone(
  source: HTMLVideoElement | HTMLImageElement, lm: FaceLandmark[],
): string | undefined {
  try {
    const w = 'videoWidth' in source ? source.videoWidth : source.naturalWidth;
    const h = 'videoHeight' in source ? source.videoHeight : source.naturalHeight;
    const c = document.createElement('canvas');
    c.width = w; c.height = h;
    const ctx = c.getContext('2d', { willReadFrequently: true })!;
    ctx.drawImage(source, 0, 0);
    const cheek = lm[IDX.cheekR];
    const px = ctx.getImageData((cheek.x * w) | 0, (cheek.y * h) | 0, 8, 8).data;
    let r = 0, g = 0, b = 0;
    const nPx = px.length / 4;
    for (let i = 0; i < px.length; i += 4) { r += px[i]; g += px[i + 1]; b += px[i + 2]; }
    const hex = (x: number) => Math.round(x / nPx).toString(16).padStart(2, '0');
    return `#${hex(r)}${hex(g)}${hex(b)}`;
  } catch { return undefined; }
}
