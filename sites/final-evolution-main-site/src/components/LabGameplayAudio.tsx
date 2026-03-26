import { useEffect, useRef } from "react";
import { useLabAudio } from "../hooks/useLabAudio";

/**
 * Ambient lab audio: ground-contact cue + neural hum vs vertical velocity (browser haptics when available).
 */
export function LabGameplayAudio() {
  const {
    ready,
    playMetallicGroundSnap,
    setVerticalVelocity,
    pulseHapticSync,
  } = useLabAudio();
  const phaseRef = useRef(0);
  const lastFootRef = useRef(-1);

  useEffect(() => {
    if (!ready) return;
    let raf = 0;
    const loop = () => {
      phaseRef.current += 0.018;
      const t = phaseRef.current;
      const vel = Math.sin(t * 0.55) * 0.5 + 0.5;
      setVerticalVelocity(vel);
      const foot = Math.floor(t * 0.55);
      if (foot !== lastFootRef.current) {
        lastFootRef.current = foot;
        playMetallicGroundSnap();
        pulseHapticSync(16);
      }
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(raf);
  }, [ready, playMetallicGroundSnap, setVerticalVelocity, pulseHapticSync]);

  return null;
}
