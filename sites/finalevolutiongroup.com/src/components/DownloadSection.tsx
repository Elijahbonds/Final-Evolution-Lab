export default function DownloadSection() {
  return (
    <section id="download" className="relative border-t border-white/5 py-24 sm:py-32 overflow-hidden">
      {/* Glow background */}
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_50%_50%,rgba(92,225,230,0.06),transparent_60%)]" />

      <div className="relative z-10 mx-auto max-w-7xl px-4 sm:px-6">
        <div className="mx-auto max-w-3xl text-center">
          <p className="mb-3 text-[0.65rem] font-bold uppercase tracking-[0.35em] text-fel-cyan">
            Download Now
          </p>
          <h2 className="text-3xl font-black leading-tight tracking-tight sm:text-4xl">
            Play Anywhere. <span className="text-fel-cyan">Train Everywhere.</span>
          </h2>
          <p className="mt-4 text-white/60">
            Access the Lab through your browser, install the iOS app, or stream directly
            from our Pixel Streaming servers — no downloads required.
          </p>
        </div>

        {/* Download Cards */}
        <div className="mt-12 grid gap-6 sm:grid-cols-3">
          {/* Web Player */}
          <div className="group rounded-2xl border border-fel-cyan/20 bg-white/[0.02] p-8 text-center transition hover:border-fel-cyan/50 hover:bg-white/[0.04]">
            <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-2xl bg-fel-cyan/10">
              <svg className="h-8 w-8 text-fel-cyan" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9" />
              </svg>
            </div>
            <h3 className="mt-4 text-lg font-bold text-white">Web Player</h3>
            <p className="mt-2 text-sm text-white/50">
              Play instantly in Chrome, Safari, or Edge. Zero install, full performance via Pixel Streaming.
            </p>
            <div className="mt-4 space-y-2">
              <p className="text-xs text-white/30">Requirements: Chrome 100+, 10Mbps+</p>
            </div>
            <a
              href="https://play.finalevolutiongroup.com"
              className="mt-6 inline-flex min-h-[48px] w-full items-center justify-center rounded-full bg-fel-cyan px-8 text-sm font-black uppercase tracking-wide text-black shadow-[0_0_24px_rgba(92,225,230,0.35)] transition hover:shadow-[0_0_40px_rgba(92,225,230,0.5)]"
            >
              ▶ Play Now
            </a>
          </div>

          {/* iOS App */}
          <div className="group rounded-2xl border border-white/10 bg-white/[0.02] p-8 text-center transition hover:border-fel-cyan/30 hover:bg-white/[0.04]">
            <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-2xl bg-white/5">
              <svg className="h-8 w-8 text-white/70" fill="currentColor" viewBox="0 0 24 24">
                <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
              </svg>
            </div>
            <h3 className="mt-4 text-lg font-bold text-white">iOS App</h3>
            <p className="mt-2 text-sm text-white/50">
              Native Swift app with HealthKit, camera integration, and offline training modes.
            </p>
            <div className="mt-4 space-y-2">
              <p className="text-xs text-white/30">Requires iOS 16.0+ | iPhone & iPad</p>
            </div>
            <a
              href="#"
              className="mt-6 inline-flex min-h-[48px] w-full items-center justify-center rounded-full border-2 border-white/20 px-8 text-sm font-bold uppercase tracking-wide text-white/70 transition hover:border-fel-cyan/50 hover:text-fel-cyan"
            >
              Coming to App Store
            </a>
          </div>

          {/* Pixel Streaming */}
          <div className="group rounded-2xl border border-white/10 bg-white/[0.02] p-8 text-center transition hover:border-fel-cyan/30 hover:bg-white/[0.04]">
            <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-2xl bg-white/5">
              <svg className="h-8 w-8 text-white/70" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
            </div>
            <h3 className="mt-4 text-lg font-bold text-white">Pixel Streaming</h3>
            <p className="mt-2 text-sm text-white/50">
              UE5 rendered on cloud GPUs, streamed via WebRTC. Console-quality on any device.
            </p>
            <div className="mt-4 space-y-2">
              <p className="text-xs text-white/30">8x V100 GPUs | 1080p @ 60fps</p>
            </div>
            <a
              href="https://stream.finalevolutiongroup.com"
              className="mt-6 inline-flex min-h-[48px] w-full items-center justify-center rounded-full border-2 border-white/20 px-8 text-sm font-bold uppercase tracking-wide text-white/70 transition hover:border-fel-cyan/50 hover:text-fel-cyan"
            >
              Stream Now
            </a>
          </div>
        </div>

        {/* System Requirements */}
        <div className="mt-16 rounded-2xl border border-white/5 bg-white/[0.02] p-8">
          <h3 className="text-center text-sm font-bold uppercase tracking-wider text-white/60 mb-6">
            System Requirements
          </h3>
          <div className="grid gap-6 sm:grid-cols-3">
            <div>
              <h4 className="text-xs font-bold uppercase tracking-wider text-fel-cyan">Web Player</h4>
              <ul className="mt-2 space-y-1 text-xs text-white/40">
                <li>• Chrome 100+, Safari 16+, Edge 100+</li>
                <li>• 10 Mbps internet connection</li>
                <li>• Any device with a modern browser</li>
              </ul>
            </div>
            <div>
              <h4 className="text-xs font-bold uppercase tracking-wider text-fel-cyan">iOS App</h4>
              <ul className="mt-2 space-y-1 text-xs text-white/40">
                <li>• iOS 16.0 or later</li>
                <li>• iPhone 12 or newer recommended</li>
                <li>• 500 MB storage</li>
              </ul>
            </div>
            <div>
              <h4 className="text-xs font-bold uppercase tracking-wider text-fel-cyan">Pixel Streaming</h4>
              <ul className="mt-2 space-y-1 text-xs text-white/40">
                <li>• WebRTC-compatible browser</li>
                <li>• 20 Mbps for best quality</li>
                <li>• Low-latency connection preferred</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
