import { useEffect, useState } from "react";
import { useLabAudio } from "../hooks/useLabAudio";

/**
 * Floating glassmorphism HUD — clinical telemetry + biofeedback pulse rings (synced to ground-contact audio).
 */
export function HUDOverlay() {
  const {
    biofeedbackPulseGeneration,
    verticalVelocityDisplay,
  } = useLabAudio();
  const [snapFlash, setSnapFlash] = useState(false);

  useEffect(() => {
    if (biofeedbackPulseGeneration === 0) return;
    setSnapFlash(true);
    const t = window.setTimeout(() => setSnapFlash(false), 56);
    return () => clearTimeout(t);
  }, [biofeedbackPulseGeneration]);

  const cards: Array<{
    label: string;
    sub: string;
    position: string;
    pulse: boolean;
    veloBar?: boolean;
  }> = [
    {
      label: "TISSUE STIFFNESS",
      sub: "spring-like response",
      position: "left-[6%] top-[22%]",
      pulse: true,
    },
    {
      label: "NEURAL DRIVE",
      sub: "effort · intent",
      position: "right-[8%] top-[38%]",
      pulse: true,
    },
    {
      label: "OUTPUT VELOCITY",
      sub: "timing · readiness",
      position: "left-[12%] bottom-[28%]",
      pulse: true,
      veloBar: true,
    },
  ];

  return (
    <div
      className="pointer-events-none absolute inset-0 z-20"
      aria-hidden="true"
    >
      {cards.map(({ label, sub, position, pulse, veloBar }) => (
        <div
          key={label}
          className={`absolute ${position} max-w-[min(220px,42vw)] rounded-2xl border border-white/15 bg-white/[0.06] px-4 py-3 shadow-[0_8px_32px_rgba(0,0,0,0.45)] backdrop-blur-xl backdrop-saturate-150 transition-[box-shadow] duration-75 ${
            snapFlash && pulse ? "fel-hud-snap-pulse" : ""
          }`}
        >
          <p className="text-[0.6rem] font-bold uppercase tracking-[0.28em] text-fel-cyan">
            {label}
          </p>
          <p className="mt-1 text-[0.65rem] leading-snug text-white/55">{sub}</p>
          {veloBar ? (
            <div className="mt-2 h-1 w-full overflow-hidden rounded-full bg-white/10">
              <div
                className="h-full rounded-full bg-fel-cyan shadow-[0_0_12px_rgba(92,225,230,0.5)] transition-[width] duration-100"
                style={{ width: `${Math.round(verticalVelocityDisplay * 100)}%` }}
              />
            </div>
          ) : null}
        </div>
      ))}
    </div>
  );
}
