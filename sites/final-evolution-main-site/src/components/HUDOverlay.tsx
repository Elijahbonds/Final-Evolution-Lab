/**
 * Floating glassmorphism HUD labels — clinical telemetry aesthetic.
 */
export function HUDOverlay() {
  const cards = [
    { label: "REACTIVE STIFFNESS", sub: "knee–ankle coupling", position: "left-[6%] top-[22%]" },
    { label: "NEURAL DRIVE", sub: "motor unit recruitment", position: "right-[8%] top-[38%]" },
    { label: "VELO SNAP", sub: "penultimate timing", position: "left-[12%] bottom-[28%]" },
  ] as const;

  return (
    <div
      className="pointer-events-none absolute inset-0 z-20"
      aria-hidden="true"
    >
      {cards.map(({ label, sub, position }) => (
        <div
          key={label}
          className={`absolute ${position} max-w-[min(220px,42vw)] rounded-2xl border border-white/15 bg-white/[0.06] px-4 py-3 shadow-[0_8px_32px_rgba(0,0,0,0.45)] backdrop-blur-xl backdrop-saturate-150`}
        >
          <p className="text-[0.6rem] font-bold uppercase tracking-[0.28em] text-fel-cyan">
            {label}
          </p>
          <p className="mt-1 text-[0.65rem] leading-snug text-white/55">{sub}</p>
        </div>
      ))}
    </div>
  );
}
