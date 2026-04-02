export default function VideoShowcase() {
  const venues = [
    { name: "Venice Beach Courts", desc: "Iconic outdoor basketball courts", emoji: "🏀" },
    { name: "Venice Ball Shop", desc: "Street basketball culture hub", emoji: "🏪" },
    { name: "Muscle Beach Gym", desc: "Legendary outdoor fitness", emoji: "💪" },
    { name: "Muscle Beach Stage", desc: "Performance & training stage", emoji: "🎭" },
    { name: "Tennis Courts", desc: "Venice Beach tennis facilities", emoji: "🎾" },
    { name: "Venice Blacktop", desc: "Raw street basketball", emoji: "⚫" },
    { name: "Hoopbus", desc: "Mobile basketball experience", emoji: "🚌" },
  ];

  return (
    <section id="venues" className="border-t border-white/5 py-24 sm:py-32">
      <div className="mx-auto max-w-7xl px-4 sm:px-6">
        <div className="mx-auto max-w-3xl text-center">
          <p className="mb-3 text-[0.65rem] font-bold uppercase tracking-[0.35em] text-fel-cyan">
            Real-World Venues
          </p>
          <h2 className="text-3xl font-black leading-tight tracking-tight sm:text-4xl">
            Captured From <span className="text-fel-cyan">Venice Beach.</span>
          </h2>
          <p className="mt-4 text-white/60">
            Every environment is inspired by real locations. Magic reveal videos showcase
            the transformation from reality to AI-generated game worlds.
          </p>
        </div>

        <div className="mt-12 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {venues.map((v) => (
            <div
              key={v.name}
              className="group rounded-xl border border-white/5 bg-white/[0.02] p-5 transition hover:border-fel-cyan/20 hover:bg-white/[0.04]"
            >
              <span className="text-2xl">{v.emoji}</span>
              <h3 className="mt-2 text-sm font-bold text-white">{v.name}</h3>
              <p className="mt-1 text-xs text-white/40">{v.desc}</p>
            </div>
          ))}
        </div>

        <div className="mt-10 text-center">
          <p className="text-xs text-white/30">
            7 magic reveal videos • 12 AI-generated environments • Powered by Luma AI, Meshy & OpenArt
          </p>
        </div>
      </div>
    </section>
  );
}
