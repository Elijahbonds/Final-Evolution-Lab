/**
 * presets.js — DATA-DRIVEN sound-design presets for the deterministic WebAudio
 * Music Creation mode. Everything here is PURE DATA (numbers/strings/arrays) —
 * NO functions, NO randomness — so a synth engine can consume the params and
 * produce byte-identical output on every run. Mirrors the voice signatures in
 * audioEngine.js (INSTRUMENTS/DRUMS) and the drum-pattern shape in
 * musicTheory.js / backend music_theory.py so patterns can be kept in sync.
 *
 * Param contract for INSTRUMENT_PRESETS voices:
 *   label        human-readable name
 *   category     grouping tag (keys | synth | bass | pad | pluck | organ)
 *   partials     [{ type, ratio, gain, detune }]  additive oscillator stack
 *                  type   : OscillatorNode type ("sine"|"triangle"|"sawtooth"|"square")
 *                  ratio  : frequency multiplier of the played note
 *                  gain   : linear mix gain of this partial (0..1)
 *                  detune : cents offset applied to this partial
 *   adsr         { attack, decay, sustain, release }  seconds (sustain is 0..1 level)
 *   lowpass      { cutoff, q }   biquad lowpass in Hz + resonance
 *   reverbSend   0..1 wet-send amount to a shared reverb bus
 *   octaveShift  integer octave offset applied before playback (bass = -1, etc.)
 *
 * Param contract for DRUM_KITS voices (all seconds / Hz / 0..1):
 *   kick  : { pitchStart, pitchEnd, pitchDecay, ampDecay, gain, drive }
 *   snare : { tone, noiseMix, noiseDecay, toneDecay, highpass, gain }
 *              noiseMix 0..1 = balance noise(1) vs body tone(0)
 *   hat   : { decay, cutoff, gain }   highpass-noise burst
 */

// ── Instrument voice presets (pure data) ────────────────────────────────────
export const INSTRUMENT_PRESETS = {
  // Existing voices from audioEngine.js, expressed as data.
  piano: {
    label: "Grand Piano",
    category: "keys",
    partials: [
      { type: "triangle", ratio: 1, gain: 0.63, detune: 0 },
      { type: "triangle", ratio: 2, gain: 0.24, detune: 0 },
      { type: "triangle", ratio: 3, gain: 0.13, detune: 0 },
    ],
    adsr: { attack: 0.004, decay: 0.35, sustain: 0.35, release: 0.12 },
    lowpass: { cutoff: 6000, q: 0.5 },
    reverbSend: 0.18,
    octaveShift: 0,
  },
  synth: {
    label: "Analog Lead",
    category: "synth",
    partials: [
      { type: "sawtooth", ratio: 1, gain: 0.6, detune: 0 },
      { type: "square", ratio: 1, gain: 0.4, detune: 8.6 },
    ],
    adsr: { attack: 0.01, decay: 0.2, sustain: 0.7, release: 0.1 },
    lowpass: { cutoff: 1800, q: 1.0 },
    reverbSend: 0.12,
    octaveShift: 0,
  },
  bass: {
    label: "Sub Bass",
    category: "bass",
    partials: [
      { type: "sine", ratio: 1, gain: 0.85, detune: 0 },
      { type: "triangle", ratio: 2, gain: 0.15, detune: 0 },
    ],
    adsr: { attack: 0.006, decay: 0.14, sustain: 0.8, release: 0.06 },
    lowpass: { cutoff: 600, q: 0.7 },
    reverbSend: 0.02,
    octaveShift: -1,
  },

  // New voices.
  pad: {
    label: "Warm Pad",
    category: "pad",
    partials: [
      { type: "sawtooth", ratio: 1, gain: 0.45, detune: -7 },
      { type: "sawtooth", ratio: 1, gain: 0.45, detune: 7 },
      { type: "sine", ratio: 2, gain: 0.2, detune: 0 },
    ],
    adsr: { attack: 0.6, decay: 0.4, sustain: 0.85, release: 0.9 },
    lowpass: { cutoff: 2200, q: 0.6 },
    reverbSend: 0.4,
    octaveShift: 0,
  },
  keys: {
    label: "Electric Piano",
    category: "keys",
    partials: [
      { type: "sine", ratio: 1, gain: 0.7, detune: 0 },
      { type: "sine", ratio: 2, gain: 0.28, detune: 0 },
      { type: "triangle", ratio: 14, gain: 0.06, detune: 0 }, // FM-ish bell tine
    ],
    adsr: { attack: 0.003, decay: 0.45, sustain: 0.4, release: 0.25 },
    lowpass: { cutoff: 3800, q: 0.5 },
    reverbSend: 0.22,
    octaveShift: 0,
  },
  pluck: {
    label: "Pluck",
    category: "pluck",
    partials: [
      { type: "sawtooth", ratio: 1, gain: 0.6, detune: 0 },
      { type: "square", ratio: 2, gain: 0.25, detune: 4 },
    ],
    adsr: { attack: 0.002, decay: 0.18, sustain: 0.0, release: 0.12 },
    lowpass: { cutoff: 3200, q: 1.4 },
    reverbSend: 0.16,
    octaveShift: 0,
  },
  organ: {
    label: "Drawbar Organ",
    category: "organ",
    partials: [
      { type: "sine", ratio: 1, gain: 0.5, detune: 0 },   // 8'
      { type: "sine", ratio: 2, gain: 0.3, detune: 0 },   // 4'
      { type: "sine", ratio: 3, gain: 0.18, detune: 0 },  // 2 2/3'
      { type: "sine", ratio: 4, gain: 0.12, detune: 0 },  // 2'
    ],
    adsr: { attack: 0.005, decay: 0.02, sustain: 1.0, release: 0.05 },
    lowpass: { cutoff: 5000, q: 0.4 },
    reverbSend: 0.1,
    octaveShift: 0,
  },
};

export const INSTRUMENT_PRESET_NAMES = Object.keys(INSTRUMENT_PRESETS);

// ── Drum kits (pure-data synthesis params) ──────────────────────────────────
// Params mirror the DRUMS one-shots in audioEngine.js (pitch sweep + amp decay
// on the kick, noise/tone mix on the snare, highpass-noise hat).
export const DRUM_KITS = {
  acoustic: {
    label: "Acoustic",
    kick:  { pitchStart: 150, pitchEnd: 45, pitchDecay: 0.2, ampDecay: 0.28, gain: 0.9, drive: 0.0 },
    snare: { tone: 180, noiseMix: 0.6, noiseDecay: 0.18, toneDecay: 0.1, highpass: 1200, gain: 0.5 },
    hat:   { decay: 0.05, cutoff: 7000, gain: 0.22 },
  },
  "808": {
    label: "808",
    kick:  { pitchStart: 120, pitchEnd: 32, pitchDecay: 0.5, ampDecay: 0.7, gain: 1.0, drive: 0.25 },
    snare: { tone: 210, noiseMix: 0.75, noiseDecay: 0.14, toneDecay: 0.08, highpass: 1500, gain: 0.55 },
    hat:   { decay: 0.04, cutoff: 9000, gain: 0.2 },
  },
  lofi: {
    label: "Lo-Fi",
    kick:  { pitchStart: 110, pitchEnd: 50, pitchDecay: 0.18, ampDecay: 0.22, gain: 0.8, drive: 0.1 },
    snare: { tone: 160, noiseMix: 0.5, noiseDecay: 0.12, toneDecay: 0.09, highpass: 900, gain: 0.42 },
    hat:   { decay: 0.045, cutoff: 5500, gain: 0.18 },
  },
};

export const DRUM_KIT_NAMES = Object.keys(DRUM_KITS);

// ── Additional genre drum patterns ──────────────────────────────────────────
// Structurally identical to DRUM_PATTERNS in musicTheory.js and _DRUM_PATTERNS
// in backend music_theory.py: { kick:[16], snare:[16], hat:[16] }, values 0/1.
// These are meant to be mirrored verbatim into both of those files.
export const DRUM_PATTERNS_EXTRA = {
  funk: {
    kick:  [1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0],
    snare: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
    hat:   [1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1],
  },
  dnb: {
    kick:  [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0],
    snare: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
    hat:   [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0],
  },
  reggaeton: {
    kick:  [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
    snare: [0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1, 0],
    hat:   [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0],
  },
  disco: {
    kick:  [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
    snare: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
    hat:   [0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0],
  },
};

export const DRUM_GENRES_EXTRA = Object.keys(DRUM_PATTERNS_EXTRA);
