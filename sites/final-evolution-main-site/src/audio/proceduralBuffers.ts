/**
 * Procedural AudioBuffers — 48 kHz float, full dynamic range.
 * Audit: FX stay synthetic (zero asset bytes); optional music beds may use efficient AAC ≤256 kbps.
 */

/** Sharp metallic ground contact — odd harmonics + fast decay (ankle stiffness cue). */
export function createMetallicGroundSnapBuffer(ctx: BaseAudioContext): AudioBuffer {
  const sampleRate = ctx.sampleRate;
  const duration = 0.01;
  const len = Math.floor(sampleRate * duration);
  const buf = ctx.createBuffer(1, len, sampleRate);
  const ch = buf.getChannelData(0);
  for (let i = 0; i < len; i++) {
    const t = i / sampleRate;
    const env = Math.exp(-t * 620) * (1 - i / len);
    const f0 = 4200;
    ch[i] =
      env *
      (Math.sin(2 * Math.PI * f0 * t) * 0.38 +
        Math.sin(2 * Math.PI * f0 * 3 * t) * 0.14 +
        Math.sin(2 * Math.PI * f0 * 5 * t) * 0.08 +
        Math.sin(2 * Math.PI * 11200 * t) * 0.12);
  }
  return buf;
}

/** High-fidelity purchase chime — crystal partials + long tail. */
export function createShardChimeBuffer(ctx: BaseAudioContext): AudioBuffer {
  const sampleRate = ctx.sampleRate;
  const duration = 0.52;
  const len = Math.floor(sampleRate * duration);
  const buf = ctx.createBuffer(1, len, sampleRate);
  const ch = buf.getChannelData(0);
  const freqs = [523.25, 659.25, 783.99, 987.77, 1174.66, 1318.51];
  for (let i = 0; i < len; i++) {
    const t = i / sampleRate;
    const env = Math.exp(-t * 2.2) * (1 - Math.pow(i / len, 0.75));
    let s = 0;
    freqs.forEach((f, j) => {
      s += Math.sin(2 * Math.PI * f * t) * (0.1 / (j + 1));
    });
    ch[i] = env * s * 0.92;
  }
  return buf;
}

export function createUnlockSwellBuffer(ctx: BaseAudioContext): AudioBuffer {
  const sampleRate = ctx.sampleRate;
  const duration = 0.28;
  const len = Math.floor(sampleRate * duration);
  const buf = ctx.createBuffer(1, len, sampleRate);
  const ch = buf.getChannelData(0);
  for (let i = 0; i < len; i++) {
    const t = i / sampleRate;
    const env = Math.min(1, t * 18) * Math.exp(-t * 5);
    const f = 220 + t * 180;
    ch[i] = env * (Math.sin(2 * Math.PI * f * t) * 0.35 + Math.sin(2 * Math.PI * f * 1.5 * t) * 0.12);
  }
  return buf;
}
