/**
 * audioEngine.js — WebAudio synthesis for the Music Creation mode.
 *
 * Instruments are richer, deterministic oscillator/FM voices (piano, synth,
 * bass, pad, keys) sourced from synthVoices.js; drums are synthesized one-shots
 * (kick/snare/hat) — NO binary samples, so nothing to ship and everything is
 * fully deterministic. The SAME render function drives both live playback
 * (AudioContext) and offline WAV bounce (OfflineAudioContext), so an exported
 * WAV is byte-identical to what you hear.
 *
 * DETERMINISM INVARIANT (hard): every voice, the drum noise beds, and the
 * reverb impulse response are pure functions of their inputs + FIXED seeds —
 * NO Math.random / Date / wall-clock anywhere in the audio graph. See
 * synthVoices.js for the full determinism argument (LCG noise, deterministic
 * IR, value-at-time automation, ConvolverNode over a fixed IR).
 */
import {
  INSTRUMENTS, DRUMS, makeNoise, makeReverbSend, makeToneControl,
  INSTRUMENT_NAMES as VOICE_NAMES,
} from "./synthVoices";

export const INSTRUMENT_NAMES = VOICE_NAMES;

/**
 * Schedule an entire project's audio onto `ctx` starting at `startTime`.
 * `project` = { bpm, key, seed, tracks:[{instrument, clips, volume, pan, muted}],
 *   metronome?:bool, composition?:{harmony,drums} }.
 * Returns the total scheduled duration in seconds.
 */
export function scheduleProject(ctx, project, startTime = 0, opts = {}) {
  const { bpm = 120, tracks = [], composition = null } = project;
  const spb = 60 / bpm; // seconds per beat

  // Master chain: [track sums] -> master -> tone (lowpass) -> destination.
  // A deterministic reverb send hangs off master (built from a FIXED seed so the
  // IR — and therefore the whole render — stays byte-identical). Effects are
  // opt-outable via opts.effects === false for a fully dry render if ever needed.
  const useEffects = opts.effects !== false;
  const master = ctx.createGain();
  master.gain.value = 0.9;
  if (useEffects && ctx.createConvolver) {
    const tone = makeToneControl(ctx, { cutoff: 13000, q: 0.7 });
    master.connect(tone);
    tone.connect(ctx.destination);
    // Reverb send: fixed seed => deterministic IR => bounce == playback.
    const reverb = makeReverbSend(ctx, { seed: 0x1234abcd, seconds: 1.8, decay: 3.4, wet: 0.28 });
    reverb.output.connect(tone);
    master._reverbInput = reverb.input; // tracks route a wet copy here
  } else {
    master.connect(ctx.destination);
  }

  let maxEnd = 0;
  const stepBeats = 0.25; // 16th notes

  // Per-instrument reverb-send amount (0..1). Pads/keys sit further back; bass
  // and drums stay dry-ish for punch. Fixed data => deterministic.
  const REVERB_SEND = { pad: 0.9, keys: 0.5, piano: 0.35, synth: 0.4, bass: 0.08, "drum-kit": 0.15 };

  tracks.forEach((track) => {
    if (track.muted) return;
    const trackGain = ctx.createGain();
    trackGain.gain.value = track.volume != null ? track.volume : 1;
    const panner = ctx.createStereoPanner ? ctx.createStereoPanner() : null;
    if (panner) { panner.pan.value = track.pan || 0; trackGain.connect(panner); panner.connect(master); }
    else { trackGain.connect(master); }
    // Wet send: a fixed fraction of the (pre-pan) track feeds the reverb bus.
    if (master._reverbInput) {
      const sendAmt = REVERB_SEND[track.instrument] != null ? REVERB_SEND[track.instrument] : 0.3;
      if (sendAmt > 0) {
        const send = ctx.createGain();
        send.gain.value = sendAmt;
        trackGain.connect(send);
        send.connect(master._reverbInput);
      }
    }

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
          // Guard each lane: an imported/partial composition may omit a lane.
          if (pat.kick && pat.kick[idx]) DRUMS.kick(ctx, trackGain, t);
          if (pat.snare && pat.snare[idx]) DRUMS.snare(ctx, trackGain, t);
          if (pat.hat && pat.hat[idx]) DRUMS.hat(ctx, trackGain, t);
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
    // Base the click track on the grid/clip extent, min 4 bars, so an empty
    // project still counts a full bar-cycle instead of a single lone bar.
    const bars = Math.max(4, Math.ceil(maxEnd / (spb * 4)) || 1);
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
  // Voices ring out past clip.length (piano/keys release ~0.30s, reverb tail
  // ~1.8s). Size the buffer to include the longest realistic tail so the final
  // hit + its reverb are NOT clipped. The reverb IR is 1.8s; add headroom.
  const VOICE_TAIL = 0.4;   // longest instrument release
  const REVERB_TAIL = 1.9;  // matches makeReverbSend seconds + margin
  const duration = Math.max(1, maxBeats * spb + Math.max(tailSeconds, VOICE_TAIL + REVERB_TAIL));
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
