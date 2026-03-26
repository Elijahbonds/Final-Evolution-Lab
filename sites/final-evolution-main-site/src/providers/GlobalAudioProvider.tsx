import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";
import {
  createAnkleStiffnessSnapBuffer,
  createShardDepositChimeBuffer,
  createUnlockSwellBuffer,
} from "../audio/proceduralBuffers";

export type LabAudioContextValue = {
  ready: boolean;
  warmUp: () => Promise<void>;
  playAnkleStiffnessSnap: () => void;
  setNeuralDriveVelocity: (normalized: number) => void;
  playShardDeposit: () => void;
  playUnlock: () => void;
  /** Vibration API; DualSense haptics require native / Gamepad extension — web uses short pulse. */
  pulseHapticSync: (ms?: number) => void;
};

const LabAudioCtx = createContext<LabAudioContextValue | null>(null);

export function GlobalAudioProvider({ children }: { children: ReactNode }) {
  const [ready, setReady] = useState(false);
  const audioCtxRef = useRef<AudioContext | null>(null);
  const snapBufRef = useRef<AudioBuffer | null>(null);
  const chimeBufRef = useRef<AudioBuffer | null>(null);
  const unlockBufRef = useRef<AudioBuffer | null>(null);
  const humOscRef = useRef<OscillatorNode | null>(null);
  const humGainRef = useRef<GainNode | null>(null);
  const masterGainRef = useRef<GainNode | null>(null);
  const initRef = useRef(false);

  const ensureGraph = useCallback(async () => {
    if (initRef.current && audioCtxRef.current) {
      if (audioCtxRef.current.state === "suspended") await audioCtxRef.current.resume();
      return audioCtxRef.current;
    }
    const ctx = new AudioContext({ sampleRate: 48000 });
    audioCtxRef.current = ctx;
    const master = ctx.createGain();
    master.gain.value = 0.62;
    master.connect(ctx.destination);
    masterGainRef.current = master;

    snapBufRef.current = createAnkleStiffnessSnapBuffer(ctx);
    chimeBufRef.current = createShardDepositChimeBuffer(ctx);
    unlockBufRef.current = createUnlockSwellBuffer(ctx);

    const humOsc = ctx.createOscillator();
    humOsc.type = "sine";
    humOsc.frequency.value = 52;
    const humGain = ctx.createGain();
    humGain.gain.value = 0;
    humOsc.connect(humGain);
    humGain.connect(master);
    humOsc.start();
    humOscRef.current = humOsc;
    humGainRef.current = humGain;

    initRef.current = true;
    setReady(true);
    return ctx;
  }, []);

  useEffect(() => {
    const onFirst = () => {
      void ensureGraph();
    };
    document.addEventListener("pointerdown", onFirst, { once: true, passive: true });
    document.addEventListener("keydown", onFirst, { once: true });
    return () => {
      document.removeEventListener("pointerdown", onFirst);
      document.removeEventListener("keydown", onFirst);
    };
  }, [ensureGraph]);

  const warmUp = useCallback(async () => {
    await ensureGraph();
  }, [ensureGraph]);

  const playBuffer = useCallback((buf: AudioBuffer | null) => {
    const ctx = audioCtxRef.current;
    const master = masterGainRef.current;
    if (!ctx || !master || !buf) return;
    const src = ctx.createBufferSource();
    src.buffer = buf;
    const g = ctx.createGain();
    g.gain.value = 1;
    src.connect(g);
    g.connect(master);
    src.start();
  }, []);

  const playAnkleStiffnessSnap = useCallback(() => {
    playBuffer(snapBufRef.current);
  }, [playBuffer]);

  const setNeuralDriveVelocity = useCallback((normalized: number) => {
    const ctx = audioCtxRef.current;
    const humOsc = humOscRef.current;
    const humGain = humGainRef.current;
    if (!ctx || !humOsc || !humGain) return;
    const n = Math.max(0, Math.min(1, normalized));
    const now = ctx.currentTime;
    const hz = 48 + n * 155;
    const amp = 0.002 + n * n * 0.12;
    humOsc.frequency.setTargetAtTime(hz, now, 0.02);
    humGain.gain.setTargetAtTime(amp, now, 0.03);
  }, []);

  const playShardDeposit = useCallback(() => {
    playBuffer(chimeBufRef.current);
  }, [playBuffer]);

  const playUnlock = useCallback(() => {
    playBuffer(unlockBufRef.current);
  }, [playBuffer]);

  const pulseHapticSync = useCallback((ms = 16) => {
    if (typeof navigator !== "undefined" && navigator.vibrate) {
      try {
        navigator.vibrate(ms);
      } catch {
        /* */
      }
    }
  }, []);

  const value = useMemo<LabAudioContextValue>(
    () => ({
      ready,
      warmUp,
      playAnkleStiffnessSnap,
      setNeuralDriveVelocity,
      playShardDeposit,
      playUnlock,
      pulseHapticSync,
    }),
    [
      ready,
      warmUp,
      playAnkleStiffnessSnap,
      setNeuralDriveVelocity,
      playShardDeposit,
      playUnlock,
      pulseHapticSync,
    ]
  );

  return <LabAudioCtx.Provider value={value}>{children}</LabAudioCtx.Provider>;
}

export function useLabAudioContext(): LabAudioContextValue | null {
  return useContext(LabAudioCtx);
}
