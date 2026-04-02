export default function ShardEconomySection() {
  const storeCategories = [
    { name: 'Cosmetics', items: 'Jerseys, Shoes, Emotes', range: '500–5,000', icon: '👕' },
    { name: 'Environments', items: 'Courts, Weather, Time of Day', range: '1,000–3,000', icon: '🏟️' },
    { name: 'Gameplay', items: 'Skill Boosts, Modes', range: '500–1,500', icon: '🎮' },
    { name: 'Customization', items: 'Balls, HUD Themes, Sounds', range: '300–1,000', icon: '🎨' },
    { name: 'Progression', items: 'XP Boosts, Unlocks', range: '100–500', icon: '📈' },
  ];

  return (
    <section id="shards" className="relative border-t border-white/5 py-24 sm:py-32 overflow-hidden">
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_70%_50%,rgba(168,85,247,0.06),transparent_60%)]" />

      <div className="relative z-10 mx-auto max-w-7xl px-4 sm:px-6">
        <div className="mx-auto max-w-3xl text-center">
          <p className="mb-3 text-[0.65rem] font-bold uppercase tracking-[0.35em] text-purple-400">
            Shard Economy
          </p>
          <h2 className="text-3xl font-black leading-tight tracking-tight sm:text-4xl">
            Play. Earn. <span className="text-purple-400">Evolve.</span>
          </h2>
          <p className="mt-4 text-white/60">
            Earn Evolution Shards through gameplay, workouts, and challenges.
            Spend them in the Shard Store on cosmetics, environments, and more.
            No pay-to-win — everything is earnable for free.
          </p>
        </div>

        {/* Earning Methods */}
        <div className="mt-14 grid sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {[
            { label: 'Win a Game', shards: '50–100', icon: '🏀' },
            { label: 'Complete Workout', shards: '30–60', icon: '💪' },
            { label: 'Daily Challenge', shards: '50', icon: '📋' },
            { label: 'Weekly Challenge', shards: '200', icon: '🏆' },
            { label: 'Perfect Form', shards: '+20', icon: '✨' },
            { label: 'New PR', shards: '+40', icon: '🎯' },
            { label: 'Daily Login (Day 7)', shards: '100', icon: '📅' },
            { label: 'Achievement', shards: '100–1,000', icon: '🎖️' },
          ].map(({ label, shards, icon }) => (
            <div
              key={label}
              className="rounded-xl border border-white/5 bg-white/[0.02] p-4 flex items-center gap-3"
            >
              <span className="text-xl">{icon}</span>
              <div>
                <p className="text-xs font-bold text-white">{label}</p>
                <p className="text-[0.65rem] text-purple-400 font-bold">
                  💎 {shards} shards
                </p>
              </div>
            </div>
          ))}
        </div>

        {/* Shard Store */}
        <div className="mt-16">
          <h3 className="text-center text-lg font-bold text-white mb-8">Shard Store</h3>
          <div className="grid sm:grid-cols-2 lg:grid-cols-5 gap-4">
            {storeCategories.map(({ name, items, range, icon }) => (
              <div
                key={name}
                className="rounded-xl border border-white/10 bg-white/[0.02] p-5 text-center"
              >
                <span className="text-3xl">{icon}</span>
                <h4 className="mt-2 text-sm font-bold text-white">{name}</h4>
                <p className="mt-1 text-[0.6rem] text-white/50">{items}</p>
                <p className="mt-2 text-xs text-purple-400 font-bold">💎 {range}</p>
              </div>
            ))}
          </div>
        </div>

        {/* No Pay-to-Win */}
        <div className="mt-12 text-center">
          <div className="inline-flex items-center gap-2 rounded-full bg-green-500/10 px-4 py-2">
            <span className="text-green-400 text-sm font-bold">✓ No Pay-to-Win</span>
            <span className="text-xs text-white/40">— All items earnable through gameplay</span>
          </div>
        </div>
      </div>
    </section>
  );
}
