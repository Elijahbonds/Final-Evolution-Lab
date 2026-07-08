# Asset Attribution — Music Creation Mode

## Audio

The Music Creation mode (`/nexus/music`) ships **zero binary audio samples**.

All sound is generated at runtime via the Web Audio API:

- **Instruments** (piano, synth, bass) — oscillator + envelope synthesis
  (`frontend/src/lib/audioEngine.js`, `INSTRUMENTS`). No recorded samples.
- **Drum kit** (kick, snare, hat) — synthesized one-shots (oscillator sweeps +
  deterministic LCG noise bursts, `DRUMS` / `makeNoise`). No recorded samples.

Because there are no external samples, there is nothing to license and no CC0 /
CC-BY attribution is required. The deterministic noise generator (seeded LCG)
guarantees the offline WAV bounce is byte-identical to live playback.

If future work adds recorded one-shots, they MUST be CC0 or CC-BY, kept under
1MB total, and each source attributed here with a link and license.
