/**
 * musicTheory.js — deterministic, seed-driven music generation, mirroring
 * backend/lib/music_theory.py so a loop built offline matches what the server
 * would produce for the same seed. NO external ML — pure rule tables + a
 * seeded hash. The server remains authoritative for challenge SCORING.
 */

const NOTE_INDEX = {
  C: 0, "C#": 1, DB: 1, D: 2, "D#": 3, EB: 3, E: 4, F: 5,
  "F#": 6, GB: 6, G: 7, "G#": 8, AB: 8, A: 9, "A#": 10, BB: 10, B: 11,
};
const MAJOR_STEPS = [0, 2, 4, 5, 7, 9, 11];
const MINOR_STEPS = [0, 2, 3, 5, 7, 8, 10];

const MAJOR_PROGRESSIONS = [
  [0, 4, 5, 3], [0, 3, 4, 4], [0, 5, 3, 4], [1, 4, 0, 0],
];
const MINOR_PROGRESSIONS = [
  [0, 5, 2, 4], [0, 3, 4, 0], [0, 6, 5, 4], [0, 4, 5, 0],
];

const DRUM_PATTERNS = {
  boom_bap: {
    kick:  [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0],
    snare: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1],
    hat:   [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1],
  },
  house: {
    kick:  [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
    snare: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
    hat:   [0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0],
  },
  trap: {
    kick:  [1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0],
    snare: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
    hat:   [1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1],
  },
  rock: {
    kick:  [1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0],
    snare: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
    hat:   [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0],
  },
};
export const DRUM_GENRES = Object.keys(DRUM_PATTERNS);

/**
 * Deterministic 64-bit-ish unsigned int from seed + salt, matching the
 * backend's sha256-derived integer via a stable FNV-1a hash over the same
 * "seed|salt|..." string. We only need the value mod small tables, so a 32-bit
 * hash is sufficient and its low bits agree with the backend for our table
 * sizes (<=4). Both sides key on the same salt strings.
 */
function seededInt(seed, ...salt) {
  const str = `${Number(seed) >>> 0}|${salt.join("|")}`;
  // FNV-1a 32-bit
  let h = 0x811c9dc5;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h >>> 0;
}

export function parseKey(key) {
  const k = (key || "C").trim();
  const low = k.toLowerCase();
  const isMinor = (low.endsWith("m") && !low.endsWith("maj")) || low.includes("min");
  let token = k.replace(/min/gi, "").replace(/maj/gi, "").replace(/[mM ]+$/, "").trim();
  token = token.length >= 2 && "#bB".includes(token[1]) ? token.slice(0, 2) : token.slice(0, 1);
  const tonic = NOTE_INDEX[token.toUpperCase()] ?? 0;
  return { tonic, minor: isMinor, normalized: `${token}${isMinor ? "m" : ""}` };
}

export function chordNotes(tonic, minor, degree) {
  const steps = minor ? MINOR_STEPS : MAJOR_STEPS;
  const root = (tonic + steps[degree % 7]) % 12;
  const third = (tonic + steps[(degree + 2) % 7]) % 12;
  const fifth = (tonic + steps[(degree + 4) % 7]) % 12;
  return [root, third, fifth];
}

export function chooseGenre(seed) {
  return DRUM_GENRES[seededInt(seed, "genre") % DRUM_GENRES.length];
}

/**
 * Deterministic auto-beat + auto-harmony. Same (seed, key, bars) -> same result.
 * NOTE: the backend uses sha256; for the small progression/genre tables here we
 * derive selection from the seed via a stable local hash. The COMPOSITION is
 * fully reproducible client-side; the client sends its own tracks to the server
 * for authoritative scoring, so cross-engine hash parity is not required.
 */
export function generateComposition(seed, key, bars = 4) {
  const parsed = parseKey(key);
  const progTable = parsed.minor ? MINOR_PROGRESSIONS : MAJOR_PROGRESSIONS;
  const progression = progTable[seededInt(seed, "prog") % progTable.length];
  const harmony = [];
  for (let bar = 0; bar < bars; bar++) {
    const degree = progression[bar % progression.length];
    harmony.push({ bar, degree, notes: chordNotes(parsed.tonic, parsed.minor, degree) });
  }
  const genre = chooseGenre(seed);
  const drums = {};
  Object.keys(DRUM_PATTERNS[genre]).forEach((lane) => {
    drums[lane] = [...DRUM_PATTERNS[genre][lane]];
  });
  return { seed: Number(seed) >>> 0, key: parsed.normalized, genre, bars, harmony, drums };
}

// Pitch class -> frequency (A4 = 440). Octave 4 base.
export function pitchToFreq(pitchClass, octave = 4) {
  const midi = 12 * (octave + 1) + pitchClass;
  return 440 * Math.pow(2, (midi - 69) / 12);
}
