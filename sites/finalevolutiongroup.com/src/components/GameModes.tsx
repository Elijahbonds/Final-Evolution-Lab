const modes = [
  { name: "Basketball H2H", icon: "🏀", desc: "Street ball head-to-head. PRQ scales jump height and timing." },
  { name: "Dunk Contest", icon: "🏆", desc: "THPS-style meter. Chain dunks for style multiplier." },
  { name: "Basketball 3v3", icon: "🏀", desc: "3-point shootout. Dual ball spawn for arcade flow." },
  { name: "Karate", icon: "🥋", desc: "Neural Tempest duel or Endless Agent Waves. Storm meters." },
  { name: "Baseball", icon: "⚾", desc: "Wii Sports batting. PRQ widens pitch recognition window." },
  { name: "Football", icon: "🏈", desc: "Kick return vs ghost. Sudden-death breakaway sprints." },
  { name: "Soccer", icon: "⚽", desc: "Possession + shot cycle. PRQ stabilizes curve on driven shots." },
  { name: "Golf", icon: "⛳", desc: "9-hole round. Downswing plane stability from PRQ." },
  { name: "Tennis", icon: "🎾", desc: "Switch Sports serve/rally. Ace cone widens with PRQ." },
  { name: "Volleyball", icon: "🏐", desc: "Set-spike timing margin scales with PRQ. Best-of-3." },
  { name: "Gymnastics", icon: "🤸", desc: "Stamina-drain floor routine. Execution + difficulty scoring." },
  { name: "Brain Brawl", icon: "🧠", desc: "Neuro Academy quiz duel. Lockout shrinks with high PRQ." },
];

export default function GameModes() {
  return (
    <section id="arena" className="relative py-24 sm:py-32">
      <div className="mx-auto max-w-7xl px-4 sm:px-6">
        <p className="mb-3 text-[0.65rem] font-bold uppercase tracking-[0.35em] text-fel-cyan">Arena</p>
        <h2 className="max-w-3xl text-3xl font-black leading-tight tracking-tight sm:text-4xl">
          12 Fully Playable <span className="text-fel-cyan">Game Modes</span>
        </h2>
        <p className="mt-4 max-w-2xl text-white/60">
          Every mode runs through one unified game mode class with data-driven arena rules.
          PRQ (Performance Readiness Quotient) influences every mechanic — jump height, timing windows,
          shot stability, stamina drain. All modes stream to your browser via Pixel Streaming.
        </p>

        <div className="mt-12 grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {modes.map((m) => (
            <div
              key={m.name}
              className="group rounded-2xl border border-white/10 bg-white/[0.03] p-5 backdrop-blur-sm transition hover:border-fel-cyan/30 hover:bg-white/[0.05]"
            >
              <div className="mb-3 text-2xl">{m.icon}</div>
              <h3 className="text-sm font-black uppercase tracking-wide text-white group-hover:text-fel-cyan">
                {m.name}
              </h3>
              <p className="mt-2 text-[0.8rem] leading-relaxed text-white/55">{m.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
