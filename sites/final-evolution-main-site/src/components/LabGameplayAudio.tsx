import { useEffect, useRef } from "react";
import { useLabAudio } from "../hooks/useLabAudio";

/**
 * Demo feedback loop: ankle stiffness snaps on synthetic ground contact + neural drive hum vs velocity.
 * Haptic pulse uses Vibration API (~16 ms) — DualSense actuators need native bridge; audio stays authoritative.
 */
export function LabGameplayAudio() {
  const {
    ready,
    playAnkleStiffnessSnap,
    setNeuralDriveVelocity,
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
      setNeuralDriveVelocity(vel);
      const foot = Math.floor(t * 0.55);
      if (foot !== lastFootRef.current) {
        lastFootRef.current = foot;
        playAnkleStiffnessSnap();
        pulseHapticSync(16);
      }
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(raf);
  }, [ready, playAnkleStiffnessSnap, setNeuralDriveVelocity, pulseHapticSync]);

  return null;
}
