/**
 * synthVoices.js — richer, fully-deterministic WebAudio voices for Music mode.
 *
 * Drop-in companion to audioEngine.js. Every function here is a PURE function of
 * its arguments plus fixed constants: there is NO Math.random, NO Date/wall-clock,
 * and NO nondeterministic node ordering anywhere in the audio graph. All noise is
 * produced by a seedable LCG whose output is a pure function of (sampleIndex, seed).
 * Reverb impulse responses are likewise LCG-generated from a fixed seed.
 *
 * DETERMINISM INVARIANT
 * ---------------------
 * The exact same code drives live playback (AudioContext) and offline bounce
 * (OfflineAudioContext). Because:
 *   1. Every buffer (noise, IR) is filled by an LCG seeded with a fixed integer,
 *      so buffer[i] depends only on i and the seed — identical across contexts.
 *   2. All scheduling uses absolute `when` times relative to the passed-in start,
 *      never ctx.currentTime / Date.now().
 *   3. Oscillator/filter/gain automation uses value-at-time ramps, which
 *      OfflineAudioContext evaluates by the same math as the realtime renderer.
 *   4. ConvolverNode is deterministic PROVIDED its IR buffer is deterministic.
 *      The convolution itself is a fixed FIR (linear, time-invariant) operation;
 *      given identical input samples and identical IR taps, the output samples
 *      are bit-reproducible. OfflineAudioContext performs the same convolution
 *      math offline, so bounce == playback. (We also set normalize=false so the
 *      browser's internal IR-gain normalization — which is deterministic but
 *      version-sensitive — is bypassed and we control gain ourselves.)
 * => A bounced WAV is byte-identical to what plays.
 */

// ── Deterministic LCG ──────────────────────────────────────────────────────
// Same constants as audioEngine.makeNoise (glibc LCG). We expose a seedable
// generator so noise for different voices can be decorrelated *deterministically*
// (different seed -> different but still fixed stream). Never seeded from time.
function lcg(seed) {
  let s = seed >>> 0;
  // Returns a float in [-1, 1). Pure function of call count for a given seed.
  return function next() {
    s = (Math.imul(s, 1103515245) + 12345) >>> 0;
    return (s / 0xffffffff) * 2 - 1;
  };
}

/**
 * Deterministic noise BufferSource. `seed` decorrelates streams without any
 * randomness — same (dur, seed, sampleRate) always yields the same samples.
 */
export function makeNoise(ctx, dur, seed = 0x2545f491) {
  const len = Math.max(1, Math.floor(ctx.sampleRate * dur));
  const buf = ctx.createBuffer(1, len, ctx.sampleRate);
  const data = buf.getChannelData(0);
  const rnd = lcg(seed);
  for (let i = 0; i < len; i++) data[i] = rnd();
  const src = ctx.createBufferSource();
  src.buffer = buf;
  return src;
}

// ── ADSR envelope ──────────────────────────────────────────────────────────
/**
 * Full ADSR gain node. Signature is envGain-compatible: the first five args
 * match the existing engine's envGain(ctx, when, dur, peak, attack, release),
 * so this can drop in directly. `decay` and `sustain` are new optional params
 * (sustain is a 0..1 fraction of peak). When decay/sustain are omitted the
 * behaviour degrades gracefully to an attack+release shape.
 *
 * Uses exponentialRampToValueAtTime for the musical (perceptually linear) curve,
 * with a tiny floor (0.0001) because exponential ramps cannot target zero.
 * All times are absolute offsets from `when`, so identical offline and live.
 */
export function envGain(
  ctx,
  when,
  dur,
  peak,
  attack = 0.005,
  release = 0.08,
  decay = 0.0,
  sustain = 1.0
) {
  const g = ctx.createGain();
  const FLOOR = 0.0001;
  const pk = Math.max(FLOOR * 2, peak);
  const susLevel = Math.max(FLOOR * 2, pk * sustain);

  // Clamp phase boundaries so a short `dur` never produces inverted times.
  const tAttack = when + attack;
  const tDecay = tAttack + decay;
  const tRelease = Math.max(tDecay, when + dur - release);

  g.gain.setValueAtTime(FLOOR, when);
  // Attack: floor -> peak
  g.gain.exponentialRampToValueAtTime(pk, tAttack);
  // Decay: peak -> sustain level (skip if no decay requested)
  if (decay > 0 && susLevel < pk) {
    g.gain.exponentialRampToValueAtTime(susLevel, tDecay);
  }
  // Sustain: hold the sustain level until release begins.
  g.gain.setValueAtTime(susLevel, tRelease);
  // Release: sustain -> floor
  g.gain.exponentialRampToValueAtTime(FLOOR, when + dur);
  return g;
}

// ── Deterministic reverb impulse response ──────────────────────────────────
/**
 * makeReverbIR(ctx, { seed, seconds, decay }) -> AudioBuffer
 *
 * Builds a stereo exponentially-decaying noise IR. The "noise" is LCG output,
 * so the IR is a pure function of (seed, seconds, decay, sampleRate): identical
 * every render, offline or live. We deliberately use *different* per-channel LCG
 * seeds (seed and seed ^ 0x9e3779b9) to get a wide, decorrelated stereo tail —
 * still fully deterministic because the seeds are fixed, not random.
 *
 * The exponential envelope exp(-decay * t/seconds) shapes a natural room decay.
 * A short fade-in on the first ~5ms avoids a click at the IR head.
 */
export function makeReverbIR(ctx, { seed = 0x1234abcd, seconds = 2.2, decay = 3.2 } = {}) {
  const rate = ctx.sampleRate;
  const len = Math.max(1, Math.floor(seconds * rate));
  const ir = ctx.createBuffer(2, len, rate);
  const fadeIn = Math.max(1, Math.floor(0.005 * rate));
  for (let ch = 0; ch < 2; ch++) {
    const data = ir.getChannelData(ch);
    // Distinct-but-fixed seed per channel -> deterministic stereo decorrelation.
    const rnd = lcg((seed ^ (ch ? 0x9e3779b9 : 0)) >>> 0);
    for (let i = 0; i < len; i++) {
      const t = i / len;
      const env = Math.pow(1 - t, 2) * Math.exp(-decay * t); // smooth room decay
      let s = rnd() * env;
      if (i < fadeIn) s *= i / fadeIn; // click-free onset
      data[i] = s;
    }
  }
  return ir;
}

/**
 * Build a reverb send node: a ConvolverNode (deterministic IR) fed through a
 * pre-gain, plus a wet-gain output. Returns { input, output } so the engine can
 * wire tracks -> reverb.input and reverb.output -> master. normalize=false keeps
 * gain under our explicit control (see determinism note at top of file).
 */
export function makeReverbSend(ctx, { seed = 0x1234abcd, seconds = 2.2, decay = 3.2, wet = 0.9 } = {}) {
  const input = ctx.createGain();
  const conv = ctx.createConvolver();
  conv.normalize = false;
  conv.buffer = makeReverbIR(ctx, { seed, seconds, decay });
  const output = ctx.createGain();
  output.gain.value = wet;
  input.connect(conv);
  conv.connect(output);
  return { input, output, convolver: conv };
}

/**
 * Deterministic multi-tap delay send — an alternative to convolution reverb that
 * uses no buffers at all (so it is trivially identical offline). Taps are fixed
 * DelayNode + feedback gains. Returns { input, output }.
 */
export function makeMultiTapDelay(ctx, { time = 0.19, feedback = 0.38, taps = 3, wet = 0.5 } = {}) {
  const input = ctx.createGain();
  const output = ctx.createGain();
  output.gain.value = wet;
  let node = input;
  for (let i = 0; i < taps; i++) {
    const d = ctx.createDelay(2.0);
    d.delayTime.value = time * (i + 1); // fixed tap spacing
    const fb = ctx.createGain();
    fb.gain.value = Math.pow(feedback, i + 1); // fixed decreasing feedback
    node.connect(d);
    d.connect(fb);
    fb.connect(output);
  }
  return { input, output };
}

/**
 * Simple lowpass "tone" control. Returns a BiquadFilter the engine can splice
 * into the master chain. Fully deterministic (fixed cutoff/Q).
 */
export function makeToneControl(ctx, { cutoff = 12000, q = 0.7 } = {}) {
  const f = ctx.createBiquadFilter();
  f.type = "lowpass";
  f.frequency.value = cutoff;
  f.Q.value = q;
  return f;
}

// ── Anti-aliasing helper ────────────────────────────────────────────────────
/**
 * Band-limited saw/square via bounded ADDITIVE synthesis. Instead of the raw
 * `sawtooth`/`square` oscillator types (whose brick-wall harmonic series aliases
 * badly on high notes in some renderers), we sum a fixed number of sine partials
 * and cap the highest partial below Nyquist. The partial count is derived
 * deterministically from `freq` and `ctx.sampleRate` — no randomness — so the
 * timbre is stable and offline-identical.
 *
 * saw:    amplitude of harmonic n = 1/n
 * square: only odd harmonics, amplitude 1/n
 *
 * Returns a gain node whose input is the summed partials; caller connects it on.
 */
function additiveOsc(ctx, freq, when, dur, { kind = "saw", detune = 0, maxPartials = 24 } = {}) {
  const out = ctx.createGain();
  out.gain.value = 1;
  const nyquist = ctx.sampleRate / 2;
  // Deterministic partial cap: never let a partial exceed ~90% of Nyquist.
  const hardCap = Math.max(1, Math.floor((nyquist * 0.9) / Math.max(1, freq)));
  const N = Math.min(maxPartials, hardCap);
  for (let n = 1; n <= N; n++) {
    if (kind === "square" && n % 2 === 0) continue; // square = odd harmonics only
    const amp = 1 / n;
    const o = ctx.createOscillator();
    o.type = "sine";
    o.frequency.setValueAtTime(freq * n, when);
    if (detune) o.detune.setValueAtTime(detune, when);
    const pg = ctx.createGain();
    pg.gain.value = amp * 0.5; // headroom so summed partials don't clip
    o.connect(pg);
    pg.connect(out);
    o.start(when);
    o.stop(when + dur);
  }
  return out;
}

// ── Instrument voices ───────────────────────────────────────────────────────
// Signature-compatible with audioEngine: voice(ctx, dest, freq, when, dur, vel).
// Each preset documents its ADSR and why it stays deterministic.
export const INSTRUMENTS = {
  /**
   * piano — additive partials with per-partial inharmonic detune and per-partial
   * decay (higher partials die faster, like a struck string). All detune/decay
   * factors are FIXED constants, so the timbre is deterministic.
   * ADSR: A 0.004 / D 0.18 / S 0.35 / R 0.30 (percussive, long tail).
   */
  piano(ctx, dest, freq, when, dur, vel = 0.8) {
    const master = envGain(ctx, when, dur, 0.24 * vel, 0.004, 0.30, 0.18, 0.35);
    master.connect(dest);
    // Fixed detune (cents) and relative level per partial — no randomness.
    const partials = [
      { h: 1, detune: 0, level: 1.0, decay: 0.30 },
      { h: 2, detune: 1.5, level: 0.55, decay: 0.22 },
      { h: 3, detune: -1.0, level: 0.32, decay: 0.16 },
      { h: 4, detune: 2.5, level: 0.18, decay: 0.12 },
      { h: 6, detune: -2.0, level: 0.09, decay: 0.09 },
    ];
    partials.forEach((p) => {
      const o = ctx.createOscillator();
      o.type = "sine";
      o.frequency.setValueAtTime(freq * p.h, when);
      o.detune.setValueAtTime(p.detune, when);
      // Per-partial decay envelope: high partials fade faster (deterministic).
      const pg = ctx.createGain();
      const FLOOR = 0.0001;
      pg.gain.setValueAtTime(Math.max(FLOOR * 2, p.level), when);
      pg.gain.exponentialRampToValueAtTime(FLOOR, when + Math.min(dur, p.decay + 0.05));
      o.connect(pg);
      pg.connect(master);
      o.start(when);
      o.stop(when + dur);
    });
  },

  /**
   * synth — band-limited detuned saw stack through a lowpass with a fixed
   * envelope-style sweep (set at fixed value-times, not modulated randomly).
   * ADSR: A 0.012 / D 0.10 / S 0.75 / R 0.14.
   * Anti-alias: additiveOsc caps partials below Nyquist deterministically.
   */
  synth(ctx, dest, freq, when, dur, vel = 0.8) {
    const g = envGain(ctx, when, dur, 0.16 * vel, 0.012, 0.14, 0.10, 0.75);
    const filt = ctx.createBiquadFilter();
    filt.type = "lowpass";
    filt.Q.value = 0.9;
    // Fixed cutoff "pluck" contour — deterministic value-at-time ramps.
    filt.frequency.setValueAtTime(2600, when);
    filt.frequency.exponentialRampToValueAtTime(1400, when + Math.min(dur, 0.25));
    filt.connect(g);
    g.connect(dest);
    // Two detuned band-limited saws (+7 / -7 cents) for width, both deterministic.
    additiveOsc(ctx, freq, when, dur, { kind: "saw", detune: 7 }).connect(filt);
    const b = additiveOsc(ctx, freq, when, dur, { kind: "saw", detune: -7 });
    const bg = ctx.createGain();
    bg.gain.value = 0.8;
    b.connect(bg);
    bg.connect(filt);
  },

  /**
   * bass — warm sine fundamental + a band-limited saw an octave up for grit,
   * lowpassed. ADSR: A 0.006 / D 0.08 / S 0.80 / R 0.09. Fully deterministic.
   */
  bass(ctx, dest, freq, when, dur, vel = 0.9) {
    const g = envGain(ctx, when, dur, 0.30 * vel, 0.006, 0.09, 0.08, 0.80);
    const filt = ctx.createBiquadFilter();
    filt.type = "lowpass";
    filt.frequency.value = 900;
    filt.Q.value = 0.6;
    filt.connect(g);
    g.connect(dest);
    // Sub sine (fundamental / 2 -> one octave below the note, classic bass weight).
    const sub = ctx.createOscillator();
    sub.type = "sine";
    sub.frequency.setValueAtTime(freq / 2, when);
    const subg = ctx.createGain();
    subg.gain.value = 1.0;
    sub.connect(subg);
    subg.connect(filt);
    sub.start(when);
    sub.stop(when + dur);
    // Band-limited saw at the note pitch for harmonic body/grit.
    const grit = additiveOsc(ctx, freq / 2, when, dur, { kind: "saw", maxPartials: 12 });
    const gritg = ctx.createGain();
    gritg.gain.value = 0.35;
    grit.connect(gritg);
    gritg.connect(filt);
  },

  /**
   * pad — lush, slow, wide. Detuned band-limited saw layers (fixed ±cents) plus
   * a sine octave for warmth, through a gentle lowpass. Long attack/release.
   * ADSR: A 0.35 / D 0.20 / S 0.85 / R 0.60.
   */
  pad(ctx, dest, freq, when, dur, vel = 0.7) {
    const g = envGain(ctx, when, dur, 0.13 * vel, 0.35, 0.60, 0.20, 0.85);
    const filt = ctx.createBiquadFilter();
    filt.type = "lowpass";
    filt.frequency.value = 3200;
    filt.Q.value = 0.5;
    filt.connect(g);
    g.connect(dest);
    // Fixed detune spread (cents) — deterministic chorus-like width.
    const voices = [-9, -3, 4, 11];
    voices.forEach((cents, i) => {
      const v = additiveOsc(ctx, freq, when, dur, { kind: "saw", detune: cents, maxPartials: 16 });
      const vg = ctx.createGain();
      vg.gain.value = 0.5 / voices.length + (i === 0 ? 0.1 : 0); // fixed weighting
      v.connect(vg);
      vg.connect(filt);
    });
    // Warm sine one octave up, low level.
    const air = ctx.createOscillator();
    air.type = "sine";
    air.frequency.setValueAtTime(freq * 2, when);
    const airg = ctx.createGain();
    airg.gain.value = 0.12;
    air.connect(airg);
    airg.connect(filt);
    air.start(when);
    air.stop(when + dur);
  },

  /**
   * keys — electric piano (Rhodes-ish). A sine fundamental FM-tickled by a fixed
   * higher-ratio sine gives the characteristic bell/tine attack, then a mellow
   * body. The FM index and ratio are FIXED constants (no randomness), so timbre
   * is deterministic. ADSR: A 0.005 / D 0.22 / S 0.45 / R 0.28.
   */
  keys(ctx, dest, freq, when, dur, vel = 0.8) {
    const g = envGain(ctx, when, dur, 0.20 * vel, 0.005, 0.28, 0.22, 0.45);
    g.connect(dest);
    // Carrier
    const carrier = ctx.createOscillator();
    carrier.type = "sine";
    carrier.frequency.setValueAtTime(freq, when);
    // Modulator: fixed 14:1-ish ratio produces a bright "tine" transient.
    const mod = ctx.createOscillator();
    mod.type = "sine";
    mod.frequency.setValueAtTime(freq * 14, when);
    const modGain = ctx.createGain();
    // FM depth decays quickly (percussive bell that mellows) — fixed ramp.
    const modPeak = freq * 6;
    modGain.gain.setValueAtTime(modPeak, when);
    modGain.gain.exponentialRampToValueAtTime(Math.max(0.0001, freq * 0.3), when + Math.min(dur, 0.18));
    mod.connect(modGain);
    modGain.connect(carrier.frequency); // classic 2-op FM
    carrier.connect(g);
    // Second harmonic body for fullness (fixed level).
    const body = ctx.createOscillator();
    body.type = "sine";
    body.frequency.setValueAtTime(freq * 2, when);
    const bodyg = ctx.createGain();
    bodyg.gain.value = 0.14;
    body.connect(bodyg);
    bodyg.connect(g);
    carrier.start(when); carrier.stop(when + dur);
    mod.start(when); mod.stop(when + dur);
    body.start(when); body.stop(when + dur);
  },
};

// ── Drum voices ─────────────────────────────────────────────────────────────
// Signature-compatible: drum(ctx, dest, when, vel). Distinct fixed noise seeds
// per drum decorrelate their noise beds deterministically.
export const DRUMS = {
  kick(ctx, dest, when, vel = 1) {
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.95 * vel, when);
    g.gain.exponentialRampToValueAtTime(0.0001, when + 0.30);
    g.connect(dest);
    const o = ctx.createOscillator();
    o.type = "sine";
    o.frequency.setValueAtTime(160, when);
    o.frequency.exponentialRampToValueAtTime(42, when + 0.22);
    o.connect(g);
    o.start(when); o.stop(when + 0.32);
    // Fixed click transient (deterministic seed) for attack definition.
    const click = makeNoise(ctx, 0.01, 0xa1b2c3d4);
    const cg = ctx.createGain();
    cg.gain.setValueAtTime(0.25 * vel, when);
    cg.gain.exponentialRampToValueAtTime(0.0001, when + 0.01);
    click.connect(cg); cg.connect(dest);
    click.start(when); click.stop(when + 0.01);
  },

  snare(ctx, dest, when, vel = 1) {
    // Noise bed (fixed seed) through highpass.
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.5 * vel, when);
    g.gain.exponentialRampToValueAtTime(0.0001, when + 0.18);
    const filt = ctx.createBiquadFilter();
    filt.type = "highpass"; filt.frequency.value = 1400;
    filt.connect(g); g.connect(dest);
    const noise = makeNoise(ctx, 0.2, 0x5e6f7a8b);
    noise.connect(filt);
    noise.start(when); noise.stop(when + 0.2);
    // Two body tones (fixed detune) for a fuller snap.
    [180, 240].forEach((f, i) => {
      const o = ctx.createOscillator();
      o.type = "triangle"; o.frequency.setValueAtTime(f, when);
      const og = ctx.createGain();
      og.gain.setValueAtTime((i === 0 ? 0.3 : 0.18) * vel, when);
      og.gain.exponentialRampToValueAtTime(0.0001, when + 0.10);
      o.connect(og); og.connect(dest);
      o.start(when); o.stop(when + 0.12);
    });
  },

  hat(ctx, dest, when, vel = 1) {
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.22 * vel, when);
    g.gain.exponentialRampToValueAtTime(0.0001, when + 0.05);
    const filt = ctx.createBiquadFilter();
    filt.type = "highpass"; filt.frequency.value = 7500;
    filt.connect(g); g.connect(dest);
    const noise = makeNoise(ctx, 0.06, 0x9c8d7e6f);
    noise.connect(filt);
    noise.start(when); noise.stop(when + 0.06);
  },
};

export const INSTRUMENT_NAMES = ["piano", "synth", "bass", "pad", "keys", "drum-kit"];
