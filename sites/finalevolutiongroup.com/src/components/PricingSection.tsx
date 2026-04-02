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
            Start Free. <span className="text-fel-cyan">Plans for Everyone.</span>
          </h2>
          <p className="mt-4 text-white/60">
            72-hour free trial with full access. No credit card required to start.
          </p>
        </div>

        {/* Pricing Cards */}
        <div className="mt-12 grid gap-6 md:grid-cols-3 max-w-5xl mx-auto">
          {/* Individual Plan */}
          <div className="rounded-3xl border border-white/10 bg-white/[0.02] p-8 text-center">
            <div className="inline-flex items-center rounded-full bg-white/5 px-3 py-1 text-[0.6rem] font-bold text-white/60 mb-4 uppercase tracking-wider">
              Individual
            </div>
            <div className="flex items-baseline justify-center gap-1">
              <span className="text-5xl font-black text-white">$6</span>
              <span className="text-lg text-white/50">/week</span>
            </div>
            <p className="mt-1 text-xs text-white/40">1 user</p>

            <div className="mt-6 space-y-2.5 text-left">
              {[
                '17 game modes across 8 sports',
                '23 animated exercise demos',
                'Body scanning with OpenCap',
                'Form correction AI',
                'Earn Evolution Shards',
                'Pixel Streaming — any device',
              ].map((f) => (
                <div key={f} className="flex items-start gap-2.5">
                  <span className="mt-0.5 text-fel-cyan text-xs">✓</span>
                  <span className="text-xs text-white/60">{f}</span>
                </div>
              ))}
            </div>

            <a
              href="https://play.finalevolutiongroup.com"
              className="mt-6 inline-flex min-h-[48px] w-full items-center justify-center rounded-full border border-fel-cyan/40 px-6 text-sm font-bold uppercase tracking-wide text-fel-cyan transition hover:bg-fel-cyan/10"
            >
              START FREE TRIAL
            </a>
          </div>

          {/* Family 2 Plan */}
          <div className="rounded-3xl border border-white/10 bg-white/[0.02] p-8 text-center relative">
            <div className="inline-flex items-center rounded-full bg-white/5 px-3 py-1 text-[0.6rem] font-bold text-white/60 mb-4 uppercase tracking-wider">
              Family 2 &nbsp;
              <span className="text-green-400">SAVE $2/WK</span>
            </div>
            <div className="flex items-baseline justify-center gap-1">
              <span className="text-5xl font-black text-white">$10</span>
              <span className="text-lg text-white/50">/week</span>
            </div>
            <p className="mt-1 text-xs text-white/40">2 users &middot; $5/person</p>

            <div className="mt-6 space-y-2.5 text-left">
              {[
                'Everything in Individual',
                '2 individual profiles',
                'Family leaderboard',
                'Shared progress tracking',
                'Co-op game modes',
                'Family challenges',
              ].map((f) => (
                <div key={f} className="flex items-start gap-2.5">
                  <span className="mt-0.5 text-fel-cyan text-xs">✓</span>
                  <span className="text-xs text-white/60">{f}</span>
                </div>
              ))}
            </div>

            <a
              href="https://play.finalevolutiongroup.com"
              className="mt-6 inline-flex min-h-[48px] w-full items-center justify-center rounded-full border border-fel-cyan/40 px-6 text-sm font-bold uppercase tracking-wide text-fel-cyan transition hover:bg-fel-cyan/10"
            >
              START FREE TRIAL
            </a>
          </div>

          {/* Family 5+ Plan */}
          <div className="rounded-3xl border-2 border-fel-cyan/40 bg-white/[0.03] p-8 text-center shadow-[0_0_60px_rgba(92,225,230,0.1)] relative">
            <div className="absolute -top-3 left-1/2 -translate-x-1/2">
              <span className="inline-flex items-center rounded-full bg-fel-cyan px-4 py-1 text-[0.6rem] font-bold text-black uppercase tracking-wider">
                🏆 BEST VALUE
              </span>
            </div>

            <div className="inline-flex items-center rounded-full bg-fel-cyan/10 px-3 py-1 text-[0.6rem] font-bold text-fel-cyan mb-4 mt-2 uppercase tracking-wider">
              Family 5+ &nbsp;
              <span className="text-green-400">SAVE $10+/WK</span>
            </div>
            <div className="flex items-baseline justify-center gap-1">
              <span className="text-5xl font-black text-white">$19.99</span>
              <span className="text-lg text-white/50">/week</span>
            </div>
            <p className="mt-1 text-xs text-white/40">5+ users &middot; $4/person</p>

            <div className="mt-6 space-y-2.5 text-left">
              {[
                'Everything in Family 2',
                '5+ individual profiles',
                'Parental controls',
                'Family tournaments',
                'Shared workout sessions',
                'Priority support',
              ].map((f) => (
                <div key={f} className="flex items-start gap-2.5">
                  <span className="mt-0.5 text-fel-cyan text-xs">✓</span>
                  <span className="text-xs text-white/60">{f}</span>
                </div>
              ))}
            </div>

            <a
              href="https://play.finalevolutiongroup.com"
              className="mt-6 inline-flex min-h-[48px] w-full items-center justify-center rounded-full bg-fel-cyan px-6 text-sm font-bold uppercase tracking-wide text-black shadow-[0_0_30px_rgba(92,225,230,0.4)] transition hover:shadow-[0_0_50px_rgba(92,225,230,0.6)]"
            >
              START FREE TRIAL
            </a>
          </div>
        </div>

        {/* All plans include */}
        <div className="mt-12 mx-auto max-w-3xl text-center">
          <p className="text-xs font-bold uppercase tracking-wider text-white/40 mb-4">
            All plans include
          </p>
          <div className="flex flex-wrap justify-center gap-x-6 gap-y-2">
            {[
              '17 Game Modes',
              '23 Exercises',
              'Body Scanning',
              'Facial Animation',
              'Earn Shards',
              'Shard Store',
              'Injury Prevention',
              'AI Form Correction',
            ].map((f) => (
              <span key={f} className="text-xs text-white/50">
                ✓ {f}
              </span>
            ))}
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
                a: 'You get 72 hours (3 days) of full access to every feature — all 17 game modes, 23 exercises, body scanning, shard economy, and creator content. No credit card needed to start.',
              },
              {
                q: 'What happens after the trial?',
                a: "After 72 hours, you'll be prompted to subscribe. Choose Individual, Family 2, or Family 5+ depending on your needs.",
              },
              {
                q: 'How does family sharing work?',
                a: 'The family owner invites members via a unique code. Each member gets their own profile, progress tracking, and save data. Kids get parental controls.',
              },
              {
                q: 'What are Evolution Shards?',
                a: 'Shards are our in-game currency earned by playing games, completing workouts, and hitting achievements. Spend them in the Shard Store on cosmetics, environments, and more. No pay-to-win.',
              },
              {
                q: 'How does body scanning work?',
                a: 'Record 2 videos of yourself (front and side view) and our OpenCap AI creates a 3D biomechanical model. Get personalized workout recommendations, form corrections, and injury prevention insights.',
              },
              {
                q: 'Can I cancel anytime?',
                a: 'Yes! Cancel your subscription at any time from your account settings. No hidden fees, no cancellation penalties.',
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
