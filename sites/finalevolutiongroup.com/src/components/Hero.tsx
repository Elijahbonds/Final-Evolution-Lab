export default function Hero() {
  return (
    <section className="relative min-h-screen overflow-hidden pt-20">
      {/* Spiral background */}
      <div className="pointer-events-none absolute inset-0 z-0" aria-hidden="true">
        <div className="absolute inset-0 bg-gradient-to-b from-fel-cyan/[0.03] via-transparent to-transparent" />
        <svg
          className="absolute left-1/2 top-1/2 h-[140vmin] w-[140vmin] -translate-x-1/2 -translate-y-1/2 opacity-[0.12] animate-[spin_60s_linear_infinite]"
          viewBox="0 0 800 800"
          fill="none"
        >
          <defs>
            <linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%">
              <stop offset="0%" stopColor="#5ce1e6" stopOpacity="0.9" />
              <stop offset="100%" stopColor="#1e90ff" stopOpacity="0.4" />
            </linearGradient>
          </defs>
          <path d="M120 400 Q 200 120 400 200 T 680 400 Q 560 680 400 600 T 120 400" stroke="url(#g)" strokeWidth="1.2" />
          <path d="M200 520 C 320 360 480 360 600 520" stroke="#5ce1e6" strokeOpacity="0.35" strokeWidth="0.8" />
          <ellipse cx="400" cy="400" rx="280" ry="180" stroke="#5ce1e6" strokeOpacity="0.08" strokeWidth="1" transform="rotate(-12 400 400)" />
        </svg>
        <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_50%_30%,rgba(92,225,230,0.06),transparent_55%)]" />
      </div>

      <div className="relative z-10 mx-auto flex max-w-6xl flex-col items-center px-4 py-24 text-center sm:px-6 sm:py-32 lg:py-40">
        <p className="mb-4 text-[0.65rem] font-bold uppercase tracking-[0.35em] text-fel-cyan">
          finalevolutiongroup.com · dark clinical · sovereign performance
        </p>
        <h1 className="max-w-4xl text-4xl font-black leading-[1.05] tracking-tight text-glow-cyan sm:text-5xl md:text-6xl lg:text-7xl">
          The Biomechanical
          <br />
          <span className="text-fel-cyan">Truth.</span>
        </h1>
        <p className="mt-6 max-w-2xl text-lg leading-relaxed text-white/65">
          12 arena game modes. Streamed to your browser. 3D exercise demonstrations powered by
          motion capture. Clinical movement education — not medical diagnosis.
        </p>
        <div className="mt-10 flex flex-wrap items-center justify-center gap-4">
          <a
            href="#arena"
            className="inline-flex min-h-[52px] min-w-[200px] items-center justify-center rounded-full bg-fel-cyan px-10 text-base font-black uppercase tracking-wide text-black shadow-[0_0_32px_rgba(92,225,230,0.45)] transition hover:bg-fel-cyan/90 hover:shadow-[0_0_48px_rgba(92,225,230,0.55)]"
          >
            Explore Arena
          </a>
          <a
            href="#download"
            className="inline-flex min-h-[52px] min-w-[200px] items-center justify-center rounded-full border-2 border-fel-cyan/50 bg-transparent px-10 text-base font-bold uppercase tracking-wide text-fel-cyan transition hover:border-fel-cyan hover:bg-fel-cyan/10"
          >
            Download Now
          </a>
        </div>

        {/* Stats strip */}
        <div className="mt-16 grid w-full max-w-3xl grid-cols-2 gap-4 sm:grid-cols-4">
          {[
            { value: "17", label: "Game Modes" },
            { value: "60Hz", label: "Frame Target" },
            { value: "9,356", label: "AI Assets" },
            { value: "∞", label: "Pixel Streaming" },
          ].map((s) => (
            <div key={s.label} className="rounded-xl border border-white/10 bg-white/[0.03] p-4 backdrop-blur-sm">
              <div className="text-2xl font-black text-fel-cyan">{s.value}</div>
              <div className="mt-1 text-[0.65rem] font-bold uppercase tracking-wider text-white/50">{s.label}</div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
