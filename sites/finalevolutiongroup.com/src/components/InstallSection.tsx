export default function InstallSection() {
  return (
    <section id="install" className="border-t border-white/5 py-24 sm:py-32">
      <div className="mx-auto max-w-7xl px-4 sm:px-6">
        <div className="mx-auto max-w-3xl text-center">
          <p className="mb-3 text-[0.65rem] font-bold uppercase tracking-[0.35em] text-fel-cyan">
            Sovereign Install
          </p>
          <h2 className="text-3xl font-black leading-tight tracking-tight sm:text-4xl">
            Bypass the App Store. <span className="text-fel-cyan">Enter the Lab.</span>
          </h2>
          <p className="mt-4 text-white/60">
            Install the Final Evolution PWA from your browser. Same Sovereign economy
            as native — shards, wallet, and Cloud Cortex sync across every platform.
          </p>
        </div>

        <div className="mt-12 grid gap-6 sm:grid-cols-3">
          {[
            {
              step: "1",
              title: "Open in Safari",
              desc: "Navigate to finalevolutiongroup.com/play/ in Safari on your iPhone or iPad.",
            },
            {
              step: "2",
              title: "Share → Add to Home Screen",
              desc: "Tap the Share button, scroll down, and select 'Add to Home Screen'. Confirm the name.",
            },
            {
              step: "3",
              title: "Launch the Lab",
              desc: "Open from your home screen icon. Full-screen, standalone, sovereign — GBA4iOS-style.",
            },
          ].map((s) => (
            <div key={s.step} className="rounded-2xl border border-white/10 bg-white/[0.02] p-6 text-center">
              <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-fel-cyan/10 text-lg font-black text-fel-cyan">
                {s.step}
              </div>
              <h3 className="mt-4 text-sm font-bold uppercase tracking-wider text-white">{s.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-white/55">{s.desc}</p>
            </div>
          ))}
        </div>

        <div className="mt-12 flex flex-wrap items-center justify-center gap-4">
          <a
            href="/play/"
            className="inline-flex min-h-[52px] min-w-[200px] items-center justify-center rounded-full bg-fel-cyan px-10 text-base font-black uppercase tracking-wide text-black shadow-[0_0_32px_rgba(92,225,230,0.45)] transition hover:bg-fel-cyan/90"
          >
            Open the Lab
          </a>
          <a
            href="/wallet/"
            className="inline-flex min-h-[52px] min-w-[200px] items-center justify-center rounded-full border-2 border-white/20 px-10 text-base font-bold uppercase tracking-wide text-white/70 transition hover:border-fel-cyan/50 hover:text-fel-cyan"
          >
            Sign in to Wallet
          </a>
        </div>
      </div>
    </section>
  );
}
