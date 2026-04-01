export default function PRQSection() {
  return (
    <section id="prq" className="border-t border-white/5 py-24 sm:py-32">
      <div className="mx-auto max-w-7xl px-4 sm:px-6">
        <div className="grid items-center gap-12 lg:grid-cols-2">
          <div>
            <p className="mb-3 text-[0.65rem] font-bold uppercase tracking-[0.35em] text-fel-cyan">
              Performance Readiness
            </p>
            <h2 className="text-3xl font-black leading-tight tracking-tight sm:text-4xl">
              Your PRQ Score <span className="text-fel-cyan">Drives Everything</span>
            </h2>
            <p className="mt-4 text-white/60 leading-relaxed">
              The Performance Readiness Quotient (0–100) is computed from your System Scan: biomechanical
              screening, movement screening (SFMA-aligned), and readiness data. It influences every arena
              mechanic in real time.
            </p>
            <ul className="mt-6 space-y-3 text-sm text-white/70">
              {[
                "Jump height multiplier — higher PRQ = higher vertical",
                "Sprint speed multiplier — PRQ scales movement tempo",
                "Reaction time scale — elite PRQ sharpens timing",
                "Kinetic leakage damping — reduce energy waste",
                "Shot/swing stability — PRQ steadies curve and plane",
                "Stamina drain reduction — train longer at high readiness",
              ].map((item) => (
                <li key={item} className="flex items-start gap-2">
                  <span className="mt-0.5 h-1.5 w-1.5 shrink-0 rounded-full bg-fel-cyan" />
                  {item}
                </li>
              ))}
            </ul>
          </div>

          {/* PRQ Gauge visualization */}
          <div className="flex items-center justify-center">
            <div className="relative h-64 w-64 rounded-full border border-white/10 bg-gradient-to-br from-white/[0.04] to-transparent p-8">
              <div className="flex h-full w-full flex-col items-center justify-center rounded-full border border-fel-cyan/20 bg-fel-black/60">
                <span className="text-5xl font-black text-fel-cyan">84</span>
                <span className="mt-1 text-[0.6rem] font-bold uppercase tracking-[0.25em] text-white/50">
                  PRQ Score
                </span>
              </div>
              <div className="absolute -right-2 top-1/4 rounded-lg border border-white/10 bg-fel-deep/90 px-3 py-1.5 text-[0.7rem]">
                <span className="text-fel-cyan font-bold">1.18×</span>
                <span className="text-white/50 ml-1">Jump</span>
              </div>
              <div className="absolute -left-2 top-1/2 rounded-lg border border-white/10 bg-fel-deep/90 px-3 py-1.5 text-[0.7rem]">
                <span className="text-fel-cyan font-bold">0.82</span>
                <span className="text-white/50 ml-1">Leakage</span>
              </div>
              <div className="absolute -right-4 bottom-1/4 rounded-lg border border-white/10 bg-fel-deep/90 px-3 py-1.5 text-[0.7rem]">
                <span className="text-fel-cyan font-bold">1.12×</span>
                <span className="text-white/50 ml-1">Speed</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
