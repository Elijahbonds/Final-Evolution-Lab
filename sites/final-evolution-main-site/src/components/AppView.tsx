import { BiometricMirror, type SFMAJointId } from "./BiometricMirror";
import { LiveVeloStats } from "./LiveVeloStats";

/** Demo SFMA map: asymmetric pattern for forensic readability. */
const DEMO_JOINTS: Partial<Record<SFMAJointId, "locked" | "mobile">> = {
  cervical: "mobile",
  t_spine: "locked",
  l_spine: "mobile",
  shoulder_l: "locked",
  shoulder_r: "mobile",
  knee_l: "locked",
  knee_r: "mobile",
  ankle_l: "mobile",
  ankle_r: "locked",
};

/**
 * Game / fitness lab canvas: DualSense ↔ 16.6 ms frame budget ↔ Bonds Bounce Blueprint,
 * with biometric mirror + live velo HUD (Muscle-and-Motion × cyberpunk forensic UI).
 */
export function AppView({ className = "" }: { className?: string }) {
  return (
    <section
      className={`relative border-t border-fel-cyan/20 bg-[#020203] px-6 py-16 sm:px-10 ${className}`}
      aria-labelledby="app-view-heading"
    >
      <div
        className="pointer-events-none absolute inset-0 opacity-[0.04]"
        style={{
          backgroundImage:
            "linear-gradient(rgba(92,225,230,0.15) 1px, transparent 1px), linear-gradient(90deg, rgba(92,225,230,0.12) 1px, transparent 1px)",
          backgroundSize: "24px 24px",
        }}
      />

      <div className="relative mx-auto max-w-6xl">
        <div className="flex flex-wrap items-end justify-between gap-4">
          <div>
            <p className="text-[0.6rem] font-bold uppercase tracking-[0.4em] text-fel-cyan">Game / fitness engine</p>
            <h2 id="app-view-heading" className="mt-2 text-2xl font-black tracking-tight text-white sm:text-3xl">
              Bonds Bounce Blueprint · live bind
            </h2>
            <p className="mt-2 max-w-2xl text-sm text-white/50">
              One frame budget (~16.67 ms @ 60 Hz): controller samples → penultimate cue → lab logic. Not a medical
              device — performance telemetry for education.
            </p>
          </div>
          <div className="font-mono text-[0.65rem] uppercase tracking-widest text-white/35">
            Latency target <span className="text-fel-cyan">16.6ms</span>
          </div>
        </div>

        {/* Latency spine: DualSense → frame → blueprint */}
        <div className="mt-10 rounded-2xl border border-white/10 bg-black/60 p-6 backdrop-blur-xl sm:p-8">
          <div className="flex flex-col items-stretch gap-6 lg:flex-row lg:items-center lg:justify-between">
            <ControllerNode />
            <LatencyBridge />
            <BlueprintNode />
          </div>
        </div>

        <div className="mt-10 grid gap-8 lg:grid-cols-2 lg:gap-10">
          <BiometricMirror joints={DEMO_JOINTS} />
          <div className="flex flex-col justify-center">
            <p className="text-[0.6rem] font-bold uppercase tracking-[0.35em] text-fel-cyan">Performance HUD</p>
            <p className="mt-2 text-sm text-white/55">
              Reactive stiffness, neural drive, and penultimate stretch — SVG traces update on a slow loop for the
              landing page shell (wire to WebSocket / lab stream in production).
            </p>
            <div className="mt-6">
              <LiveVeloStats />
            </div>
          </div>
        </div>

        <VVAModuleMap />
      </div>
    </section>
  );
}

/** Maps Vertical Velocity Academy curriculum nodes → Bonds Bounce Blueprint graph (visual contract). */
function VVAModuleMap() {
  const rows = [
    {
      vva: "VVA · Penultimate rhythm",
      blueprint: "Bonds Bounce — penultimate stride segment",
    },
    {
      vva: "VVA · Spiral line / fascial plane",
      blueprint: "Blueprint — stiffness routing & cue windows",
    },
    {
      vva: "VVA · Reactive stiffness lab",
      blueprint: "Blueprint — kN/m targets + drive caps",
    },
    {
      vva: "VVA · Neural drive meter",
      blueprint: "Blueprint — % drive vs. penultimate window (16.6 ms tick)",
    },
  ] as const;

  return (
    <div className="mt-12 rounded-2xl border border-white/10 bg-black/50 p-6 backdrop-blur-md sm:p-8">
      <p className="text-[0.6rem] font-bold uppercase tracking-[0.35em] text-fel-cyan">
        Vertical Velocity Academy ↔ Blueprint
      </p>
      <p className="mt-2 text-sm text-white/50">
        Site visualization: each VVA module is wired to the same training graph shown above — DualSense
        samples frame-align with the 16.6 ms penultimate standard before the Lab runtime.
      </p>
      <ul className="mt-6 divide-y divide-white/10">
        {rows.map((r) => (
          <li key={r.vva} className="grid gap-2 py-4 sm:grid-cols-2 sm:gap-8">
            <span className="font-mono text-[0.7rem] uppercase tracking-wide text-fel-cyan/90">{r.vva}</span>
            <span className="text-sm text-white/70">{r.blueprint}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}

function ControllerNode() {
  return (
    <div className="flex flex-1 flex-col items-center text-center">
      <div className="relative h-28 w-40 rounded-lg border border-fel-cyan/40 bg-gradient-to-b from-white/8 to-transparent shadow-[0_0_32px_rgba(92,225,230,0.15)]">
        <div className="absolute left-3 top-1/2 h-10 w-10 -translate-y-1/2 rounded-full border border-white/20 bg-black/50" />
        <div className="absolute right-3 top-1/2 h-10 w-10 -translate-y-1/2 rounded-full border border-white/20 bg-black/50" />
        <div className="absolute bottom-3 left-1/2 h-3 w-16 -translate-x-1/2 rounded-sm bg-fel-cyan/30" />
        <span className="absolute left-2 top-2 text-[0.5rem] font-mono uppercase tracking-widest text-fel-cyan/80">
          DualSense
        </span>
      </div>
      <p className="mt-3 text-[0.65rem] font-semibold uppercase tracking-[0.2em] text-white/60">Input · IMU + triggers</p>
    </div>
  );
}

function LatencyBridge() {
  return (
    <div className="flex flex-[1.2] flex-col items-center justify-center px-2">
      <div className="relative w-full max-w-md">
        <svg viewBox="0 0 400 64" className="w-full" aria-hidden>
          <defs>
            <linearGradient id="felFiber" x1="0%" y1="0%" x2="100%" y2="0%">
              <stop offset="0%" stopColor="#5ce1e6" stopOpacity="0.2" />
              <stop offset="50%" stopColor="#5ce1e6" stopOpacity="0.95" />
              <stop offset="100%" stopColor="#fcee0a" stopOpacity="0.35" />
            </linearGradient>
          </defs>
          <line x1="8" y1="32" x2="392" y2="32" stroke="url(#felFiber)" strokeWidth="3" strokeLinecap="round" />
          {[80, 200, 320].map((x) => (
            <circle key={x} cx={x} cy="32" r="4" fill="#5ce1e6" opacity="0.9" />
          ))}
        </svg>
        <div className="absolute inset-0 flex items-center justify-center">
          <span className="rounded border border-fel-cyan/60 bg-black/90 px-4 py-2 font-mono text-lg font-black tabular-nums text-fel-cyan shadow-[0_0_24px_rgba(92,225,230,0.35)]">
            16.6&nbsp;ms
          </span>
        </div>
      </div>
      <p className="mt-2 text-center text-[0.6rem] uppercase tracking-[0.35em] text-white/40">
        Frame-aligned transport · lab clock
      </p>
    </div>
  );
}

function BlueprintNode() {
  return (
    <div className="flex flex-1 flex-col items-center text-center">
      <div className="w-full max-w-xs rounded-xl border border-fel-amber/35 bg-gradient-to-br from-fel-amber/10 to-transparent px-5 py-6 shadow-[0_0_28px_rgba(252,238,10,0.12)]">
        <p className="font-mono text-[0.55rem] uppercase tracking-[0.3em] text-fel-amber/90">Training graph</p>
        <p className="mt-3 text-lg font-black uppercase leading-tight text-white">
          Bonds Bounce
          <br />
          <span className="text-fel-cyan">Blueprint</span>
        </p>
        <p className="mt-3 text-[0.65rem] leading-relaxed text-white/45">
          Penultimate stride · reactive stiffness targets · neural drive caps
        </p>
      </div>
      <p className="mt-3 text-[0.65rem] font-semibold uppercase tracking-[0.2em] text-white/60">Lab logic · deterministic</p>
    </div>
  );
}
