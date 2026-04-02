export default function PricingSection() {
  return (
    <section id="pricing" className="relative border-t border-white/5 py-24 sm:py-32 overflow-hidden">
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_50%_30%,rgba(92,225,230,0.08),transparent_60%)]" />

      <div className="relative z-10 mx-auto max-w-7xl px-4 sm:px-6">
        <div className="mx-auto max-w-3xl text-center">
          <p className="mb-3 text-[0.65rem] font-bold uppercase tracking-[0.35em] text-fel-cyan">
            Simple Pricing
          </p>
          <h2 className="text-3xl font-black leading-tight tracking-tight sm:text-4xl">
            Start Free. <span className="text-fel-cyan">Evolve for $6/week.</span>
          </h2>
          <p className="mt-4 text-white/60">
            72-hour free trial with full access. No credit card required to start.
          </p>
        </div>

        {/* Pricing Card */}
        <div className="mt-12 mx-auto max-w-lg">
          <div className="rounded-3xl border-2 border-fel-cyan/40 bg-white/[0.03] p-10 text-center shadow-[0_0_60px_rgba(92,225,230,0.1)]">
            {/* Trial Badge */}
            <div className="inline-flex items-center rounded-full bg-fel-cyan/10 px-4 py-1.5 text-xs font-bold text-fel-cyan mb-6">
              🎮 72-HOUR FREE TRIAL
            </div>

            <div className="flex items-baseline justify-center gap-1">
              <span className="text-6xl font-black text-white">$6</span>
              <span className="text-xl text-white/50">/week</span>
            </div>

            <p className="mt-2 text-sm text-white/40">Cancel anytime — no commitment</p>

            <div className="mt-8 space-y-3 text-left">
              {[
                '17 game modes across 8 sports',
                '23 animated exercise demonstrations',
                '5 pre-built workout programs',
                'Custom workout builder',
                'Creator challenges & content',
                'Progress tracking & personal records',
                'Form validation & AI coaching',
                'Pixel Streaming — play on any device',
                'New content added weekly',
              ].map((feature) => (
                <div key={feature} className="flex items-start gap-3">
                  <span className="mt-0.5 text-fel-cyan">✓</span>
                  <span className="text-sm text-white/70">{feature}</span>
                </div>
              ))}
            </div>

            <a
              href="https://play.finalevolutiongroup.com"
              className="mt-8 inline-flex min-h-[56px] w-full items-center justify-center rounded-full bg-fel-cyan px-8 text-base font-black uppercase tracking-wide text-black shadow-[0_0_30px_rgba(92,225,230,0.4)] transition hover:shadow-[0_0_50px_rgba(92,225,230,0.6)]"
            >
              START FREE TRIAL
            </a>
            <p className="mt-3 text-xs text-white/30">No credit card required for trial</p>
          </div>
        </div>

        {/* FAQ */}
        <div className="mt-20 mx-auto max-w-2xl">
          <h3 className="text-center text-sm font-bold uppercase tracking-wider text-white/60 mb-8">
            Frequently Asked Questions
          </h3>
          <div className="space-y-6">
            {[
              {
                q: 'How does the free trial work?',
                a: 'You get 72 hours (3 days) of full access to every feature — all 17 game modes, 23 exercises, 5 workout programs, and creator content. No credit card needed to start.',
              },
              {
                q: 'What happens after the trial?',
                a: 'After 72 hours, you\'ll be prompted to subscribe for $6/week. If you don\'t subscribe, you\'ll lose access to game modes and workouts until you do.',
              },
              {
                q: 'Can I cancel anytime?',
                a: 'Yes! Cancel your subscription at any time from your account settings. No hidden fees, no cancellation penalties.',
              },
              {
                q: 'What payment methods do you accept?',
                a: 'We accept all major credit/debit cards through Stripe. Apple Pay and Google Pay are also supported on iOS and Android.',
              },
              {
                q: 'Do I need special hardware?',
                a: 'No! Final Evolution Lab uses Pixel Streaming — our UE5 game runs on cloud GPUs and streams to your browser. All you need is a modern browser and decent internet.',
              },
            ].map(({ q, a }) => (
              <div key={q} className="rounded-xl border border-white/5 bg-white/[0.02] p-5">
                <h4 className="text-sm font-bold text-white">{q}</h4>
                <p className="mt-2 text-xs text-white/50 leading-relaxed">{a}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
