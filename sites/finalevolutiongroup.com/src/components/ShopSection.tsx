const tiers = [
  {
    name: "Vertical Velocity Blueprint",
    price: "$19.99",
    shards: "200 Evolution Shards",
    features: [
      "12-module Academy access",
      "3D exercise demonstrations",
      "Movement education content",
      "Community leaderboard",
    ],
  },
  {
    name: "Cortex Shard Pack",
    price: "$49.99",
    shards: "600 Evolution Shards + 100 Blueprint Credits",
    popular: true,
    features: [
      "Everything in Blueprint",
      "Cloud Cortex AI coaching",
      "Creator Card marketplace",
      "Priority matchmaking",
      "PRQ-linked arena bonuses",
    ],
  },
  {
    name: "Sovereign Pro",
    price: "$99.99",
    shards: "1500 Evolution Shards + 500 Blueprint Credits",
    features: [
      "Everything in Cortex Pack",
      "Mac Sovereign Lab build (.dmg)",
      "Gold Master early access",
      "Direct coaching integration",
      "Exclusive Creator Cards",
      "Lifetime Academy updates",
    ],
  },
];

export default function ShopSection() {
  return (
    <section id="shop" className="border-t border-white/5 py-24 sm:py-32">
      <div className="mx-auto max-w-7xl px-4 sm:px-6">
        <p className="mb-3 text-center text-[0.65rem] font-bold uppercase tracking-[0.35em] text-fel-cyan">
          Sovereign Economy
        </p>
        <h2 className="text-center text-3xl font-black leading-tight tracking-tight sm:text-4xl">
          Evolution <span className="text-fel-cyan">Shards</span>
        </h2>
        <p className="mx-auto mt-4 max-w-2xl text-center text-white/60">
          Stripe Checkout credits shards to your Supabase wallet in real time via webhook.
          Same economy across PWA, native app, and Pixel Streaming.
        </p>

        <div className="mt-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {tiers.map((t) => (
            <div
              key={t.name}
              className={`relative rounded-2xl border p-6 transition ${
                t.popular
                  ? "border-fel-cyan/40 bg-fel-cyan/[0.04] shadow-[0_0_40px_rgba(92,225,230,0.08)]"
                  : "border-white/10 bg-white/[0.02]"
              }`}
            >
              {t.popular && (
                <div className="absolute -top-3 left-1/2 -translate-x-1/2 rounded-full bg-fel-cyan px-4 py-0.5 text-[0.6rem] font-black uppercase tracking-wider text-black">
                  Most Popular
                </div>
              )}
              <h3 className="text-lg font-black text-white">{t.name}</h3>
              <div className="mt-2 text-3xl font-black text-fel-cyan">{t.price}</div>
              <p className="mt-1 text-xs text-white/50">{t.shards}</p>
              <ul className="mt-5 space-y-2">
                {t.features.map((f) => (
                  <li key={f} className="flex items-start gap-2 text-sm text-white/70">
                    <span className="mt-1 text-fel-cyan">✓</span>
                    {f}
                  </li>
                ))}
              </ul>
              <button
                type="button"
                className={`mt-6 w-full rounded-full py-3 text-sm font-bold uppercase tracking-wider transition ${
                  t.popular
                    ? "bg-fel-cyan text-black hover:bg-fel-cyan/90"
                    : "border border-fel-cyan/40 text-fel-cyan hover:bg-fel-cyan/10"
                }`}
              >
                Get Started
              </button>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
