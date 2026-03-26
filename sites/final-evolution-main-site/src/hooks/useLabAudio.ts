import { useLabAudioContext } from "../providers/GlobalAudioProvider";

/**
 * Low-latency lab triggers (Web Audio API). Requires `GlobalAudioProvider` above.
 * Buffers are pre-loaded on first user gesture; call `warmUp()` after mount if you need graph before interaction.
 */
export function useLabAudio() {
  const ctx = useLabAudioContext();
  if (!ctx) {
    return {
      ready: false,
      warmUp: async () => {},
      playAnkleStiffnessSnap: () => {},
      setNeuralDriveVelocity: (_n: number) => {},
      playShardDeposit: () => {},
      playUnlock: () => {},
      pulseHapticSync: (_ms?: number) => {},
    };
  }
  return ctx;
}
