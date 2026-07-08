/**
 * audioEngine.js — lightweight WebAudio synthesis for the Music Creation mode.
 *
 * Instruments are oscillator+envelope presets (piano, synth, bass); drums are
 * synthesized one-shots (kick/snare/hat) — NO binary samples, so nothing to
 * ship and everything is fully deterministic. The same render function drives
 * both live playback (AudioContext) and offline WAV bounce (OfflineAudioContext),
 * so an exported WAV matches what you hear.
 */

// ── Instrument voice presets ───────────────────────────────────────────────
// Each returns a function(ctx, destination, freq, when, dur, velocity).

function envGain(ctx, when, dur, peak, attack = 0.005, release = 0.08) {
  const g = ctx.createGain();
  g.gain.setValueAtTime(0.0001, when);
  g.gain.exponentialRampToValueAtTime(Math.max(0.0002, peak), when + attack);
  g.gain.setValueAtTime(Math.max(0.0002, peak), Math.max(when + attack, when + dur - release));
  g.gain.exponentialRampToValueAtTime(0.0001, when + dur);
  return g;
}

const INSTRUMENTS = {
  piano(ctx, dest, freq, when, dur, vel = 0.8) {
    const g = envGain(ctx, when, dur, 0.22 * vel, 0.004, 0.12);
    g.connect(dest);
    [1, 2, 3].forEach((h, i) => {
      const o = ctx.createOscillator();
      o.type = "triangle";
      o.frequency.setValueAtTime(freq * h, when);
      const hg = ctx.createGain();
      hg.gain.value = 1 / (h * 1.6 + i);
      o.connect(hg); hg.connect(g);
      o.start(when); o.stop(when + dur);
    });
  },
  synth(ctx, dest, freq, when, dur, vel = 0.8) {
    const g = envGain(ctx, when, dur, 0.18 * vel, 0.01, 0.1);
    const filt = ctx.createBiquadFilter();
    filt.type = "lowpass";
    filt.frequency.setValueAtTime(1800, when);
    filt.connect(g); g.connect(dest);
    ["sawtooth", "square"].forEach((t, i) => {
      const o = ctx.createOscillator();
      o.type = t;
      o.frequency.setValueAtTime(freq * (i === 1 ? 1.005 : 1), when);
      const og = ctx.createGain(); og.gain.value = i === 0 ? 0.6 : 0.4;
      o.connect(og); og.connect(filt);
      o.start(when); o.stop(when + dur);
    });
  },
  bass(ctx, dest, freq, when, dur, vel = 0.9) {
    const g = envGain(ctx, when, dur, 0.3 * vel, 0.006, 0.06);
    g.connect(dest);
    const o = ctx.createOscillator();
    o.type = "sine";
    o.frequency.setValueAtTime(freq / 2, when);
    o.connect(g);
    o.start(when); o.stop(when + dur);
  },
};

// ── Drum voices (synthesized one-shots) ────────────────────────────────────
const DRUMS = {
  kick(ctx, dest, when, vel = 1) {
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.9 * vel, when);
    g.gain.exponentialRampToValueAtTime(0.0001, when + 0.28);
    g.connect(dest);
    const o = ctx.createOscillator();
    o.type = "sine";
    o.frequency.setValueAtTime(150, when);
    o.frequency.exponentialRampToValueAtTime(45, when + 0.2);
    o.connect(g);
    o.start(when); o.stop(when + 0.3);
  },
  snare(ctx, dest, when, vel = 1) {
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.5 * vel, when);
    g.gain.exponentialRampToValueAtTime(0.0001, when + 0.18);
    const filt = ctx.createBiquadFilter();
    filt.type = "highpass"; filt.frequency.value = 1200;
    filt.connect(g); g.connect(dest);
    const noise = makeNoise(ctx, 0.2);
    noise.connect(filt);
    noise.start(when); noise.stop(when + 0.2);
    // body tone
    const o = ctx.createOscillator();
    o.type = "triangle"; o.frequency.setValueAtTime(180, when);
    const og = ctx.createGain();
    og.gain.setValueAtTime(0.3 * vel, when);
    og.gain.exponentialRampToValueAtTime(0.0001, when + 0.1);
    o.connect(og); og.connect(dest);
    o.start(when); o.stop(when + 0.12);
  },
  hat(ctx, dest, when, vel = 1) {
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.22 * vel, when);
    g.gain.exponentialRampToValueAtTime(0.0001, when + 0.05);
    const filt = ctx.createBiquadFilter();
    filt.type = "highpass"; filt.frequency.value = 7000;
    filt.connect(g); g.connect(dest);
    const noise = makeNoise(ctx, 0.06);
    noise.connect(filt);
    noise.start(when); noise.stop(when + 0.06);
  },
};

function makeNoise(ctx, dur) {
  const len = Math.max(1, Math.floor(ctx.sampleRate * dur));
  const buf = ctx.createBuffer(1, len, ctx.sampleRate);
  const data = buf.getChannelData(0);
  // Deterministic pseudo-noise (LCG) so bounce == playback bit-for-bit.
  let s = 0x2545f491;
  for (let i = 0; i < len; i++) {
    s = (Math.imul(s, 1103515245) + 12345) >>> 0;
    data[i] = (s / 0xffffffff) * 2 - 1;
  }
  const src = ctx.createBufferSource();
  src.buffer = buf;
  return src;
}

export const INSTRUMENT_NAMES = ["piano", "synth", "bass", "drum-kit"];

/**
 * Schedule an entire project's audio onto `ctx` starting at `startTime`.
 * `project` = { bpm, key, seed, tracks:[{instrument, clips, volume, pan, muted}],
 *   metronome?:bool, composition?:{harmony,drums} }.
 * Returns the total scheduled duration in seconds.
 */
export function scheduleProject(ctx, project, startTime = 0, opts = {}) {
  const { bpm = 120, tracks = [], composition = null } = project;
  const spb = 60 / bpm; // seconds per beat
  const master = ctx.createGain();
  master.gain.value = 0.9;
  master.connect(ctx.destination);

  let maxEnd = 0;
  const stepBeats = 0.25; // 16th notes

  tracks.forEach((track) => {
    if (track.muted) return;
    const trackGain = ctx.createGain();
    trackGain.gain.value = track.volume != null ? track.volume : 1;
    const panner = ctx.createStereoPanner ? ctx.createStereoPanner() : null;
    if (panner) { panner.pan.value = track.pan || 0; trackGain.connect(panner); panner.connect(master); }
    else { trackGain.connect(master); }

    const instrument = track.instrument || "synth";
    (track.clips || []).forEach((clip) => {
      const when = startTime + clip.start * spb;
      const dur = Math.max(0.05, clip.length * spb);
      maxEnd = Math.max(maxEnd, when - startTime + dur);
      if (instrument === "drum-kit") {
        // Drum clip: fire a genre pattern (from composition) across its length.
        const pat = (composition && composition.drums) || {
          kick: [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0],
          snare: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1],
          hat: [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0],
        };
        const steps = Math.round(clip.length / stepBeats);
        for (let i = 0; i < steps; i++) {
          const t = when + i * stepBeats * spb;
          const idx = i % 16;
          if (pat.kick[idx]) DRUMS.kick(ctx, trackGain, t);
          if (pat.snare[idx]) DRUMS.snare(ctx, trackGain, t);
          if (pat.hat[idx]) DRUMS.hat(ctx, trackGain, t);
        }
      } else {
        // Pitched clip: play the chord for the bar it falls in (auto-harmony)
        // or a root note if no composition.
        const voice = INSTRUMENTS[instrument] || INSTRUMENTS.synth;
        let freqs = [261.63]; // C4 default
        if (composition && composition.harmony && composition.harmony.length) {
          const bar = Math.floor(clip.start / 4) % composition.harmony.length;
          const notes = composition.harmony[bar].notes;
          const oct = instrument === "bass" ? 3 : 4;
          freqs = notes.map((pc) => 440 * Math.pow(2, (12 * (oct + 1) + pc - 69) / 12));
        }
        freqs.forEach((f) => voice(ctx, trackGain, f, when, dur, 0.8));
      }
    });
  });

  if (project.metronome) {
    const bars = Math.ceil(maxEnd / (spb * 4)) || 1;
    for (let b = 0; b < bars * 4; b++) {
      const t = startTime + b * spb;
      const o = ctx.createOscillator();
      const g = ctx.createGain();
      g.gain.setValueAtTime(0.0001, t);
      g.gain.exponentialRampToValueAtTime(b % 4 === 0 ? 0.18 : 0.09, t + 0.001);
      g.gain.exponentialRampToValueAtTime(0.0001, t + 0.04);
      o.type = "square";
      o.frequency.value = b % 4 === 0 ? 1600 : 1000;
      o.connect(g); g.connect(master);
      o.start(t); o.stop(t + 0.05);
    }
  }

  return maxEnd;
}

/**
 * Offline render of a project to a WAV Blob via OfflineAudioContext.
 * Deterministic: same project -> byte-identical WAV.
 */
export async function renderProjectToWav(project, { sampleRate = 44100, tailSeconds = 0.5 } = {}) {
  const bpm = project.bpm || 120;
  const spb = 60 / bpm;
  // Compute duration from clips.
  let maxBeats = 0;
  (project.tracks || []).forEach((t) =>
    (t.clips || []).forEach((c) => { maxBeats = Math.max(maxBeats, c.start + c.length); }));
  const duration = Math.max(1, maxBeats * spb + tailSeconds);
  const Offline = window.OfflineAudioContext || window.webkitOfflineAudioContext;
  const ctx = new Offline(2, Math.ceil(duration * sampleRate), sampleRate);
  scheduleProject(ctx, project, 0);
  const rendered = await ctx.startRendering();
  return audioBufferToWav(rendered);
}

// ── WAV encoding (16-bit PCM) ──────────────────────────────────────────────
export function audioBufferToWav(buffer) {
  const numCh = buffer.numberOfChannels;
  const sampleRate = buffer.sampleRate;
  const numFrames = buffer.length;
  const bytesPerSample = 2;
  const blockAlign = numCh * bytesPerSample;
  const dataSize = numFrames * blockAlign;
  const bufferAB = new ArrayBuffer(44 + dataSize);
  const view = new DataView(bufferAB);

  const writeStr = (off, s) => { for (let i = 0; i < s.length; i++) view.setUint8(off + i, s.charCodeAt(i)); };
  writeStr(0, "RIFF");
  view.setUint32(4, 36 + dataSize, true);
  writeStr(8, "WAVE");
  writeStr(12, "fmt ");
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true); // PCM
  view.setUint16(22, numCh, true);
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, sampleRate * blockAlign, true);
  view.setUint16(32, blockAlign, true);
  view.setUint16(34, 16, true);
  writeStr(36, "data");
  view.setUint32(40, dataSize, true);

  const channels = [];
  for (let c = 0; c < numCh; c++) channels.push(buffer.getChannelData(c));
  let offset = 44;
  for (let i = 0; i < numFrames; i++) {
    for (let c = 0; c < numCh; c++) {
      let s = Math.max(-1, Math.min(1, channels[c][i]));
      s = s < 0 ? s * 0x8000 : s * 0x7fff;
      view.setInt16(offset, s, true);
      offset += 2;
    }
  }
  return new Blob([view], { type: "audio/wav" });
}
