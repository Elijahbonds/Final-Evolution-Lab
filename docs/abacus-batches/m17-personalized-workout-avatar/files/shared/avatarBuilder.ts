// Mini-avatar builder: pose frames + calibration → MiniAvatarSpec.
// Proportions are ratios of the athlete's measured segment lengths vs. the canonical
// rig's reference ratios — the avatar is visibly THEM (long arms, short torso, etc.)
// while staying stylized. Palette defaults are user-adjustable in the reveal UI.

import type {
  PoseFrame, Landmark, MiniAvatarSpec, AvatarProportions, AvatarPalette,
} from './contracts';

const LM = {
  L_SHOULDER: 11, R_SHOULDER: 12, L_ELBOW: 13, R_ELBOW: 14,
  L_WRIST: 15, R_WRIST: 16, L_HIP: 23, R_HIP: 24,
  L_KNEE: 25, R_KNEE: 26, L_ANKLE: 27, R_ANKLE: 28,
} as const;

const dist = (a: Landmark, b: Landmark) =>
  Math.hypot(b.x - a.x, b.y - a.y, b.z - a.z);

/** Canonical rig reference ratios (segment length / stature) for the default body. */
const REF = {
  torso: 0.29, arms: 0.17, forearms: 0.15,
  legs: 0.24, shins: 0.23, shoulders: 0.23, hips: 0.16,
};

/** Median over well-tracked frames beats mean — robust to landmark jitter. */
function median(xs: number[]): number {
  const s = [...xs].sort((a, b) => a - b);
  return s.length ? s[(s.length / 2) | 0] : 0;
}

export function buildAvatar(
  frames: PoseFrame[],
  opts: { athleteHeightCm: number; scanId: string; skinHex?: string },
): MiniAvatarSpec {
  // Use only frames where the whole body is confidently visible
  const good = frames.filter(
    (f) => f.landmarks.reduce((s, l) => s + l.visibility, 0) / f.landmarks.length > 0.6,
  );
  const use = good.length >= 8 ? good : frames;

  const seg = (a: number, b: number) => median(use.map((f) => dist(f.landmarks[a], f.landmarks[b])));

  const torso = (seg(LM.L_SHOULDER, LM.L_HIP) + seg(LM.R_SHOULDER, LM.R_HIP)) / 2;
  const arms = (seg(LM.L_SHOULDER, LM.L_ELBOW) + seg(LM.R_SHOULDER, LM.R_ELBOW)) / 2;
  const forearms = (seg(LM.L_ELBOW, LM.L_WRIST) + seg(LM.R_ELBOW, LM.R_WRIST)) / 2;
  const legs = (seg(LM.L_HIP, LM.L_KNEE) + seg(LM.R_HIP, LM.R_KNEE)) / 2;
  const shins = (seg(LM.L_KNEE, LM.L_ANKLE) + seg(LM.R_KNEE, LM.R_ANKLE)) / 2;
  const shoulders = seg(LM.L_SHOULDER, LM.R_SHOULDER);
  const hips = seg(LM.L_HIP, LM.R_HIP);

  // Stature estimate in landmark space: shoulder→ankle span + head allowance
  const stature = (torso + legs + shins) * 1.18;

  const ratio = (measured: number, ref: number) => {
    const r = measured / Math.max(stature, 1e-9) / ref;
    return Math.min(1.35, Math.max(0.7, Math.round(r * 100) / 100)); // clamp: stylized, never grotesque
  };

  const proportions: AvatarProportions = {
    height: Math.min(1.25, Math.max(0.8, opts.athleteHeightCm / 178)), // canonical rig ≈ 178 cm
    torso: ratio(torso, REF.torso),
    arms: ratio(arms, REF.arms),
    forearms: ratio(forearms, REF.forearms),
    legs: ratio(legs, REF.legs),
    shins: ratio(shins, REF.shins),
    shoulders: ratio(shoulders, REF.shoulders),
    hips: ratio(hips, REF.hips),
  };

  const palette: AvatarPalette = {
    skin: opts.skinHex ?? '#b98a63',     // reveal UI offers a swatch row to adjust
    jersey: '#22d3ee',
    shorts: '#0f172a',
    shoes: '#f8fafc',
    accent: '#f59e0b',
  };

  return {
    avatarId: `av_${opts.scanId}`,
    proportions,
    palette,
    sourceScanId: opts.scanId,
  };
}

/**
 * Sample a skin-tone hex from a video frame around the face/forearm landmarks.
 * CLIENT-ONLY helper (needs a canvas); call before upload, pass result into
 * buildAvatar via opts.skinHex. Always user-adjustable afterwards.
 */
export function sampleSkinTone(
  video: HTMLVideoElement, frame: PoseFrame,
): string | undefined {
  try {
    const c = document.createElement('canvas');
    c.width = video.videoWidth; c.height = video.videoHeight;
    const ctx = c.getContext('2d', { willReadFrequently: true })!;
    ctx.drawImage(video, 0, 0);
    const wrist = frame.landmarks[16];   // R wrist area — usually exposed skin
    const px = ctx.getImageData(
      Math.max(0, (wrist.vx * c.width) | 0),
      Math.max(0, (wrist.vy * c.height) | 0),
      6, 6,
    ).data;
    let r = 0, g = 0, b = 0, n = px.length / 4;
    for (let i = 0; i < px.length; i += 4) { r += px[i]; g += px[i + 1]; b += px[i + 2]; }
    const hex = (x: number) => Math.round(x / n).toString(16).padStart(2, '0');
    return `#${hex(r)}${hex(g)}${hex(b)}`;
  } catch {
    return undefined;                    // cross-origin or decode issue → default palette
  }
}
