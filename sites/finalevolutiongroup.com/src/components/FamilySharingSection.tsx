export default function FamilySharingSection() {
  return (
    <section id="family" className="relative border-t border-white/5 py-24 sm:py-32 overflow-hidden">
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_50%_60%,rgba(251,191,36,0.06),transparent_60%)]" />

      <div className="relative z-10 mx-auto max-w-7xl px-4 sm:px-6">
        <div className="mx-auto max-w-3xl text-center">
          <p className="mb-3 text-[0.65rem] font-bold uppercase tracking-[0.35em] text-amber-400">
            Family Sharing
          </p>
          <h2 className="text-3xl font-black leading-tight tracking-tight sm:text-4xl">
            Train Together. <span className="text-amber-400">Evolve Together.</span>
          </h2>
          <p className="mt-4 text-white/60">
            Share your subscription with family members. Everyone gets their own profile,
            progress tracking, and personalized workouts.
          </p>
        </div>

        <div className="mt-14 grid lg:grid-cols-3 gap-8">
          {/* Features */}
          <div className="lg:col-span-2 space-y-6">
            <div className="grid sm:grid-cols-2 gap-4">
              {[
                {
                  title: 'Individual Profiles',
                  desc: 'Each family member gets their own save data, progress tracking, and customization.',
                  icon: '👤',
                },
                {
                  title: 'Family Leaderboard',
                  desc: 'Friendly competition with weekly challenges and family-wide achievements.',
                  icon: '🏆',
                },
                {
                  title: 'Parental Controls',
                  desc: 'Content filtering, play time limits, and purchase approval for kids.',
                  icon: '🛡️',
                },
                {
                  title: 'Easy Invitations',
                  desc: 'Generate a unique code or send email/SMS invites. 7-day expiry.',
                  icon: '✉️',
                },
                {
                  title: 'Shared Workouts',
                  desc: 'Family workout sessions and co-op game modes for exercising together.',
                  icon: '🏋️',
                },
                {
                  title: 'Family Tournaments',
                  desc: 'Private family tournaments across all 17 game modes.',
                  icon: '🎮',
                },
              ].map(({ title, desc, icon }) => (
                <div key={title} className="rounded-xl border border-white/5 bg-white/[0.02] p-5">
                  <span className="text-2xl">{icon}</span>
                  <h4 className="mt-2 text-sm font-bold text-white">{title}</h4>
                  <p className="mt-1 text-xs text-white/50">{desc}</p>
                </div>
              ))}
            </div>
          </div>

          {/* Pricing Summary */}
          <div className="rounded-3xl border border-amber-400/20 bg-white/[0.02] p-8">
            <h3 className="text-lg font-bold text-white mb-6 text-center">Family Plans</h3>
            <div className="space-y-6">
              <div className="text-center p-4 rounded-xl border border-white/5">
                <p className="text-xs text-white/50 uppercase tracking-wider">Individual</p>
                <p className="text-2xl font-black text-white">$6<span className="text-sm text-white/50">/week</span></p>
                <p className="text-[0.6rem] text-white/40">1 user</p>
              </div>
              <div className="text-center p-4 rounded-xl border border-white/5">
                <p className="text-xs text-white/50 uppercase tracking-wider">Family 2</p>
                <p className="text-2xl font-black text-white">$10<span className="text-sm text-white/50">/week</span></p>
                <p className="text-[0.6rem] text-green-400">Save $2/week vs 2× Individual</p>
              </div>
              <div className="text-center p-4 rounded-xl border border-amber-400/30 bg-amber-400/5">
                <div className="text-[0.5rem] font-bold text-amber-400 uppercase tracking-wider mb-1">🏆 Best Value</div>
                <p className="text-xs text-white/50 uppercase tracking-wider">Family 5+</p>
                <p className="text-2xl font-black text-white">$19.99<span className="text-sm text-white/50">/week</span></p>
                <p className="text-[0.6rem] text-green-400">Save $10+/week vs 5× Individual</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
