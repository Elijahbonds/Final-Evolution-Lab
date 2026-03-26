/**
 * Procedural AudioBuffers — 48 kHz float, full dynamic range; no lossy compression.
 * Audit: zero binary weight on the wire; optional future `public/audio/*.wav` can be
 * decoded here and kept ≤256 kbps AAC for music beds only, not FX.
 */

export function createAnkleStiffnessSnapBuffer(ctx: BaseAudioContext): AudioBuffer {
  const sampleRate = ctx.sampleRate;
  const duration = 0.012;
  const len = Math.floor(sampleRate * duration);
  const buf = ctx.createBuffer(1, len, sampleRate);
  const ch = buf.getChannelData(0);
  for (let i = 0; i < len; i++) {
    const t = i / sampleRate;
    const env = Math.exp(-t * 520) * (1 - i / len);
    ch[i] = env * (Math.sin(2 * Math.PI * 3800 * t) * 0.42 + Math.sin(2 * Math.PI * 9200 * t) * 0.22);
  }
  return buf;
}

export function createShardDepositChimeBuffer(ctx: BaseAudioContext): AudioBuffer {
  const sampleRate = ctx.sampleRate;
  const duration = 0.45;
  const len = Math.floor(sampleRate * duration);
  const buf = ctx.createBuffer(1, len, sampleRate);
  const ch = buf.getChannelData(0);
  const freqs = [523.25, 659.25, 783.99, 1046.5];
  for (let i = 0; i < len; i++) {
    const t = i / sampleRate;
    const env = Math.exp(-t * 2.8) * (1 - Math.pow(i / len, 0.8));
    let s = 0;
    freqs.forEach((f, j) => {
      s += Math.sin(2 * Math.PI * f * t) * (0.12 / (j + 1));
    });
    ch[i] = env * s * 0.85;
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
