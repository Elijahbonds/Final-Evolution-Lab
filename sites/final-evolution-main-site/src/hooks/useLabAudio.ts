import { useLabAudioContext } from "../providers/GlobalAudioProvider";

/**
 * Biomechanical biofeedback (Web Audio API, ~48 kHz) — requires `GlobalAudioProvider`.
 *
 * - **Metallic snap** — high-frequency transient for ankle stiffness / ground contact (HUD pulse sync).
 * - **Neural hum** — low-latency sine drone; `setVerticalVelocity(0–1)` maps pitch/level to vertical velocity.
 * - **Shard chime** — high-fidelity partials for Sovereign Thank You (after verified purchase).
 *
 * Buffers pre-warm on first user gesture. `biofeedbackPulseGeneration` increments each snap for HUD rings (16.6 ms cadence target).
 */
export function useLabAudio() {
  const ctx = useLabAudioContext();
  if (!ctx) {
    return {
      ready: false,
      warmUp: async () => {},
      playMetallicGroundSnap: () => {},
      playAnkleStiffnessSnap: () => {},
      setVerticalVelocity: (_n: number) => {},
      setNeuralDriveVelocity: (_n: number) => {},
      playShardChime: () => {},
      playShardDeposit: () => {},
      playUnlock: () => {},
      pulseHapticSync: (_ms?: number) => {},
      biofeedbackPulseGeneration: 0,
      verticalVelocityDisplay: 0,
    };
  }
  return ctx;
}
