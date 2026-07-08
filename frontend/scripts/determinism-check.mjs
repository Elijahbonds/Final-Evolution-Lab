/**
 * determinism-check.mjs — proves the WAV render is a DETERMINISTIC, pure
 * function of the project: same project -> byte-identical WAV, every run.
 *
 * It imports the REAL audioEngine.js (scheduleProject / renderProjectToWav /
 * audioBufferToWav) and drives it through a deterministic mock WebAudio graph
 * (webaudio-mock.cjs). We render the SAME project twice in the same process and
 * across a fresh window/globals, hash both WAVs, and assert the checksums match.
 *
 * Usage: node scripts/determinism-check.mjs
 * Exit 0 + prints the stable checksum on success; exit 1 on any mismatch.
 */
import { createHash } from "node:crypto";
import { createRequire, register } from "node:module";
import { pathToFileURL } from "node:url";
import path from "node:path";

// Register the extensionless-import resolve hook so audioEngine.js's
// `./synthVoices` (webpack-style) resolves in Node ESM.
register("./js-ext-loader.mjs", import.meta.url);

const require = createRequire(import.meta.url);
const { OfflineAudioContextMock } = require("./webaudio-mock.cjs");

const enginePath = path.resolve(process.cwd(), "src/lib/audioEngine.js");

// A representative, non-trivial project touching every voice + drums + FX.
const PROJECT = {
  name: "determinism-probe",
  bpm: 120,
  key: "Am",
  seed: 123456789,
  metronome: true,
  tracks: [
    { instrument: "piano", type: "instrument", volume: 0.9, pan: -0.3, muted: false,
      clips: [{ start: 0, length: 4 }, { start: 8, length: 4 }] },
    { instrument: "bass", type: "instrument", volume: 1.0, pan: 0, muted: false,
      clips: [{ start: 0, length: 8 }, { start: 8, length: 8 }] },
    { instrument: "synth", type: "instrument", volume: 0.8, pan: 0.3, muted: false,
      clips: [{ start: 4, length: 4 }, { start: 12, length: 4 }] },
    { instrument: "drum-kit", type: "sample", volume: 1.0, pan: 0, muted: false,
      clips: [{ start: 0, length: 4 }, { start: 4, length: 4 }, { start: 8, length: 4 }, { start: 12, length: 4 }] },
  ],
  composition: {
    harmony: [
      { bar: 0, degree: 0, notes: [9, 0, 4] },
      { bar: 1, degree: 5, notes: [5, 9, 0] },
      { bar: 2, degree: 2, notes: [0, 4, 7] },
      { bar: 3, degree: 4, notes: [4, 7, 11] },
    ],
    drums: {
      kick: [1,0,0,0,0,0,1,0,0,0,1,0,0,0,0,0],
      snare:[0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,1],
      hat:  [1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,1],
    },
  },
};

async function loadEngine() {
  // Provide the browser globals the engine expects, backed by the mock.
  globalThis.window = {
    OfflineAudioContext: OfflineAudioContextMock,
    webkitOfflineAudioContext: OfflineAudioContextMock,
    AudioContext: OfflineAudioContextMock,
  };
  const mod = await import(pathToFileURL(enginePath).href + `?t=${Date.now()}`);
  return mod;
}

function wavBytes(blob) {
  // The engine returns a Blob; our mock Blob stores the ArrayBuffer.
  if (blob._bytes) return Buffer.from(blob._bytes);
  if (blob.arrayBuffer) return blob.arrayBuffer().then((ab) => Buffer.from(ab));
  throw new Error("cannot extract wav bytes");
}

async function renderOnce() {
  const { renderProjectToWav } = await loadEngine();
  const blob = await renderProjectToWav(PROJECT, { sampleRate: 44100, tailSeconds: 0.6 });
  const bytes = await Promise.resolve(wavBytes(blob));
  return createHash("sha256").update(bytes).digest("hex");
}

(async () => {
  const h1 = await renderOnce();
  const h2 = await renderOnce();
  // Fresh globals to simulate a different session.
  delete globalThis.window;
  const h3 = await renderOnce();

  // Round-trip: serialize -> parse (as export/import does) -> render. The WAV
  // from the re-imported project must be byte-identical to the original.
  globalThis.window = {
    OfflineAudioContext: OfflineAudioContextMock,
    webkitOfflineAudioContext: OfflineAudioContextMock,
    AudioContext: OfflineAudioContextMock,
  };
  const { renderProjectToWav } = await loadEngine();
  const roundTripped = JSON.parse(JSON.stringify({ export_version: "1.0-local", project: PROJECT })).project;
  const rtBlob = await renderProjectToWav(roundTripped, { sampleRate: 44100, tailSeconds: 0.6 });
  const hRT = createHash("sha256").update(Buffer.from(await rtBlob.arrayBuffer())).digest("hex");

  const stable = h1 === h2 && h2 === h3;
  const roundtripOk = hRT === h1;
  const ok = stable && roundtripOk;
  console.log("wav-sha256 run1:", h1);
  console.log("wav-sha256 run2:", h2);
  console.log("wav-sha256 run3:", h3);
  console.log("wav-sha256 round-trip (export->import):", hRT);
  console.log(stable ? "DETERMINISTIC: PASS (checksum stable across 3 renders)" : "DETERMINISTIC: FAIL");
  console.log(roundtripOk ? "ROUND-TRIP: PASS (import renders byte-identical WAV)" : "ROUND-TRIP: FAIL");
  process.exit(ok ? 0 : 1);
})();
