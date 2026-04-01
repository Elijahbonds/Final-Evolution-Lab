const modules = [
  { key: "mod1", title: "Bio-Electric Freeway", exercise: "Triple Threat Stance" },
  { key: "mod2", title: "Vertical Velocity Takeoff", exercise: "Dunk Approach Mechanics" },
  { key: "mod3", title: "Lateral Shuffle Engine", exercise: "Defensive Slide Pattern" },
  { key: "mod4", title: "Neural Tempest", exercise: "Spiral Strike Sequence" },
  { key: "mod5", title: "Rotational Power Chain", exercise: "Bat Swing Kinetic Chain" },
  { key: "mod6", title: "Isometric NMS Reset", exercise: "Split Stance Wall Push" },
  { key: "mod7", title: "Curve Stabilization", exercise: "Driven Shot Mechanics" },
  { key: "mod8", title: "Downswing Plane", exercise: "Hip Hinge Sequence" },
  { key: "mod9", title: "Serve Kinetic Chain", exercise: "Ace Cone Pattern" },
  { key: "mod10", title: "Spike Approach", exercise: "Penultimate Step Timing" },
  { key: "mod11", title: "Floor Routine Entry", exercise: "Tumbling Run Sequence" },
  { key: "mod12", title: "Cloud Cortex", exercise: "Neuro Academy Integration" },
];

export default function AcademySection() {
  return (
    <section id="academy" className="border-t border-white/5 py-24 sm:py-32">
      <div className="mx-auto max-w-7xl px-4 sm:px-6">
        <p className="mb-3 text-[0.65rem] font-bold uppercase tracking-[0.35em] text-fel-cyan">
          Vertical Velocity Academy
        </p>
        <h2 className="max-w-3xl text-3xl font-black leading-tight tracking-tight sm:text-4xl">
          12 Modules. <span className="text-fel-cyan">3D Animated Exercises.</span>
        </h2>
        <p className="mt-4 max-w-2xl text-white/60 leading-relaxed">
          Each module maps to an arena game mode with a DeepMotion motion-captured exercise demonstration.
          The Digital Twin ghost performs Perfect Form at PRQ-adjusted play rate — slow at low readiness,
          elite tempo at high PRQ.
        </p>

        <div className="mt-12 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {modules.map((m, i) => (
            <div
              key={m.key}
              className="flex items-start gap-4 rounded-xl border border-white/10 bg-white/[0.02] p-4 transition hover:border-fel-cyan/20"
            >
              <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-fel-cyan/10 text-sm font-black text-fel-cyan">
                {i + 1}
              </div>
              <div>
                <h3 className="text-sm font-bold text-white">{m.title}</h3>
                <p className="mt-1 text-[0.75rem] text-white/50">Exercise: {m.exercise}</p>
                <p className="mt-0.5 text-[0.65rem] font-mono text-fel-cyan/60">{m.key}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
