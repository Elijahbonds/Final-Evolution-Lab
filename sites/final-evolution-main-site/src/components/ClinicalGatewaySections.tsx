/**
 * Clinical product delivery — sovereign performance facility narrative (PRQ, System Scan, 12-Module Academy).
 */
import type { ReactNode } from "react";

function SectionShell({
  id,
  eyebrow,
  title,
  children,
}: {
  id: string;
  eyebrow: string;
  title: string;
  children: ReactNode;
}) {
  return (
    <section
      id={id}
      className="scroll-mt-24 border-t border-white/10 bg-fel-black px-6 py-20 sm:px-12"
    >
      <div className="mx-auto max-w-6xl">
        <p className="text-[0.65rem] font-bold uppercase tracking-[0.35em] text-fel-cyan">{eyebrow}</p>
        <h2 className="mt-3 text-3xl font-black tracking-tight text-white sm:text-4xl">{title}</h2>
        <div className="mt-10">{children}</div>
      </div>
    </section>
  );
}

export function SectionPRQ() {
  return (
    <SectionShell id="prq" eyebrow="Athlete readiness" title="Performance Readiness Quotient (PRQ)">
      <div className="grid gap-10 lg:grid-cols-2 lg:gap-16 lg:items-center">
        <div className="space-y-4 text-sm leading-relaxed text-white/70">
          <p>
            The <strong className="text-white/90">Performance Readiness Quotient (PRQ)</strong> is a single,
            normalized score from <strong className="text-fel-cyan">0–100</strong> that summarizes how prepared you
            are to express power, timing, and resilience on game day.
          </p>
          <p>
            It unifies your <strong className="text-white/85">System Scan</strong> signal,{" "}
            <strong className="text-white/85">12-Module Academy</strong> progression, and live training load into one
            number athletes and staff can read at a glance — performance insight and education, not a medical diagnosis.
          </p>
        </div>
        <div className="rounded-2xl border border-fel-cyan/30 bg-gradient-to-br from-fel-cyan/10 to-black/80 p-8 shadow-[0_0_40px_rgba(92,225,230,0.12)]">
          <p className="text-[0.6rem] font-bold uppercase tracking-[0.3em] text-fel-cyan/80">Score band</p>
          <div className="mt-6 flex items-end justify-between gap-4">
            <span className="font-mono text-6xl font-black tabular-nums text-fel-cyan">84</span>
            <span className="pb-2 text-right text-xs text-white/45">
              Illustrative reading — your live PRQ is computed in the Mac experience.
            </span>
          </div>
          <div className="mt-8 h-2 w-full overflow-hidden rounded-full bg-white/10">
            <div className="h-full w-[84%] rounded-full bg-gradient-to-r from-fel-cyan to-fel-amber" />
          </div>
        </div>
      </div>
    </SectionShell>
  );
}

export function SectionSystemScan() {
  const steps = [
    {
      title: "Full-body analysis",
      body: "Structured screening that maps mobility, stability, and coordination across regions that drive jump performance.",
    },
    {
      title: "Vertical estimate",
      body: "A lab-grade estimate of vertical potential from your current movement signature — used to set targets, not to label talent.",
    },
    {
      title: "Flight & hang",
      body: "Timing of flight phases informs elasticity, braking, and how you transition from approach to takeoff.",
    },
    {
      title: "Kinetic movement grading",
      body: "Quality of force delivery and sequencing — how cleanly you load, store, and release energy in the jump cycle.",
    },
  ] as const;

  return (
    <SectionShell id="system-scan" eyebrow="System Scan" title="Assessment that meets athletes where they are">
      <p className="max-w-3xl text-sm leading-relaxed text-white/65">
        The scan is a repeatable intake: analysis first, then clear metrics your coach can interpret alongside you.
        Outcomes stay in the realm of <strong className="text-white/85">human performance software</strong> — not
        clinical care.
      </p>
      <ol className="mt-12 grid gap-6 sm:grid-cols-2">
        {steps.map((s, i) => (
          <li
            key={s.title}
            className="rounded-2xl border border-white/10 bg-white/[0.03] p-6 backdrop-blur-sm"
          >
            <span className="font-mono text-xs text-fel-cyan/80">{String(i + 1).padStart(2, "0")}</span>
            <h3 className="mt-2 text-lg font-bold text-white">{s.title}</h3>
            <p className="mt-3 text-sm leading-relaxed text-white/55">{s.body}</p>
          </li>
        ))}
      </ol>
    </SectionShell>
  );
}

const ACADEMY_12 = [
  "CNS Freeway — central timing and readiness for explosive movement",
  "SFMA / FMS — screening layers that connect restriction to strategy",
  "Slings & spiral line — how load travels through the body’s elastic chains",
  "Correctives — re-patterning that clears the path for power",
  "Penultimate rhythm — the last step before takeoff",
  "Reactive stiffness — spring-like quality tuned to surface and sport",
  "Neural drive optimization — intent and effort in the right window",
  "Eccentric control — deceleration quality before acceleration",
  "Elastic recoil — hop progressions and tissue timing",
  "Ground reaction & vectors — direction of force, not just magnitude",
  "Return-to-play progression — objective thresholds before competition",
  "Flight protocol — continuous hops and elasticity depth",
] as const;

export function SectionAcademy() {
  return (
    <SectionShell
      id="academy"
      eyebrow="12-Module Academy"
      title="Vertical Velocity — full performance syllabus"
    >
      <p className="max-w-3xl text-sm leading-relaxed text-white/65">
        The Vertical Velocity curriculum walks from <strong className="text-white/85">CNS Freeway</strong> and{" "}
        <strong className="text-white/85">SFMA / FMS</strong> foundations through{" "}
        <strong className="text-white/85">slings</strong>, <strong className="text-white/85">correctives</strong>, and
        advanced elasticity — so every session has a clear arc inside the Sovereign Lab runtime.
      </p>
      <ul className="mt-10 grid gap-3 sm:grid-cols-2">
        {ACADEMY_12.map((line) => (
          <li
            key={line}
            className="flex gap-3 rounded-xl border border-white/10 bg-black/40 px-4 py-3 text-sm text-white/75"
          >
            <span className="mt-0.5 h-1.5 w-1.5 shrink-0 rounded-full bg-fel-cyan" aria-hidden />
            {line}
          </li>
        ))}
      </ul>
    </SectionShell>
  );
}

const ARENA_SIMS = [
  {
    name: "Basketball",
    badge: "Readiness-linked simulation",
    body: "Court rhythm, approach timing, and vertical expression scale with your PRQ band and recent System Scan emphasis — built for repeatable reps and staff review.",
  },
  {
    name: "Karate",
    badge: "Active research module",
    body: "Strike tempo, stance transitions, and cognitive load profiles are being tuned to the same PRQ and Academy signals you already train. Full sport loop ships in a later sovereign release.",
  },
  {
    name: "Soccer",
    badge: "Coming soon to the Sovereign ecosystem",
    body: "Pitch-wide movement context and return-to-play pacing will inherit your PRQ trajectory and scan priorities when this corridor opens — one wallet, one readiness spine.",
  },
] as const;

export function SectionArena() {
  return (
    <SectionShell id="arena" eyebrow="The Arena" title="Performance-linked simulations">
      <p className="max-w-3xl text-sm leading-relaxed text-white/65">
        Arena corridors are <strong className="text-white/85">readiness-linked simulations</strong>: your live{" "}
        <strong className="text-white/85">PRQ</strong>, <strong className="text-white/85">System Scan</strong> history,
        and <strong className="text-white/85">12-Module Academy</strong> emphasis inform pacing, feedback density, and
        progression — not generic arcade modes.
      </p>
      <div className="mt-10 grid gap-6 md:grid-cols-3">
        {ARENA_SIMS.map((m) => (
          <div
            key={m.name}
            className="rounded-2xl border border-fel-cyan/25 bg-gradient-to-b from-fel-cyan/5 to-black/60 p-6"
          >
            <p className="text-[0.55rem] font-bold uppercase tracking-[0.28em] text-fel-cyan/90">{m.badge}</p>
            <h3 className="mt-2 text-lg font-black text-white">{m.name}</h3>
            <p className="mt-3 text-sm leading-relaxed text-white/55">{m.body}</p>
          </div>
        ))}
      </div>
    </SectionShell>
  );
}
