import { useMemo } from "react";
import { BiometricMirror, type SFMAJointId } from "./BiometricMirror";
import { LabGameplayAudio } from "./LabGameplayAudio";
import { LiveVeloStats } from "./LiveVeloStats";
import { VVA_Player } from "./VVA_Player";
import { useReadinessSnapshot } from "../hooks/useReadinessSnapshot";
import { AthleteIdentityHandshake } from "./AthleteIdentityHandshake";

/** Demo SFMA map when no `readiness_snapshots` row (signed-out or empty). */
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

/** Athlete readiness dashboard — live clinical sync, kinetic heatmap, and system calibration graph. */
export function AppView({ className = "" }: { className?: string }) {
  const { payload, identity, loading, error, signedIn } = useReadinessSnapshot();

  const mergedJoints = useMemo(() => {
    return { ...DEMO_JOINTS, ...(payload.joints ?? {}) };
  }, [payload.joints]);

  const redCongestion = payload.sfma_multi_segmental_rotation_passed === false;

  return (
    <section
      id="fel-lab"
      className={`relative scroll-mt-24 border-t border-fel-cyan/20 bg-[#020203] px-6 py-16 sm:px-10 ${className}`}
      aria-labelledby="app-view-heading"
    >
      <LabGameplayAudio />
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
            <p className="text-[0.6rem] font-bold uppercase tracking-[0.4em] text-fel-cyan">Athlete readiness</p>
            <h2 id="app-view-heading" className="mt-2 text-2xl font-black tracking-tight text-white sm:text-3xl">
              PRQ · stiffness · neural drive
            </h2>
            <p className="mt-2 max-w-2xl text-sm text-white/50">
              A live read on how you organize force and timing — tied to your Performance Readiness Quotient (PRQ) and
              System Scan intake. Movement education, not a medical device.
            </p>
            {error ? (
              <p className="mt-2 text-xs text-amber-400/90">Could not load clinical movement snapshot. {error}</p>
            ) : loading ? (
              <p className="mt-2 text-xs text-white/35">Loading athlete readiness snapshot…</p>
            ) : null}
          </div>
          <div className="font-mono text-[0.65rem] uppercase tracking-widest text-white/35">
            Live <span className="text-fel-cyan">clinical sync</span>
          </div>
        </div>

        <AthleteIdentityHandshake identity={identity} loading={loading} signedIn={signedIn} />

        {/* Signal capture → athlete readiness → system calibration */}
        <div className="mt-10 rounded-2xl border border-white/10 bg-black/60 p-6 backdrop-blur-xl sm:p-8">
          <div className="flex flex-col items-stretch gap-6 lg:flex-row lg:items-center lg:justify-between">
            <ControllerNode />
            <LatencyBridge />
            <SystemCalibrationNode />
          </div>
        </div>

        <div className="mt-10 grid gap-8 lg:grid-cols-2 lg:gap-10">
          <BiometricMirror joints={mergedJoints} redCongestion={redCongestion} />
          <div className="flex flex-col justify-center">
            <p className="text-[0.6rem] font-bold uppercase tracking-[0.35em] text-fel-cyan">Athlete readiness</p>
            <p className="mt-2 text-sm text-white/55">
              Stiffness, drive, and timing telemetry update in real time — patterns first, not vanity metrics.
            </p>
            <div className="mt-6">
              <LiveVeloStats />
            </div>
          </div>
        </div>

        <div className="mt-12">
          <VVA_Player />
        </div>

        <div className="mt-14 rounded-2xl border border-fel-cyan/35 bg-gradient-to-br from-fel-cyan/[0.08] to-black/80 p-8 text-center shadow-[0_0_36px_rgba(92,225,230,0.12)] sm:p-10">
          <p className="text-[0.65rem] font-bold uppercase tracking-[0.3em] text-fel-cyan">Sovereign access</p>
          <p className="mx-auto mt-3 max-w-xl text-sm leading-relaxed text-white/60">
            Complete secure checkout to unlock the Sovereign Lab Mac installer. Your PRQ and Academy entitlements stay in
            sync with the Sovereign economy.
          </p>
          <a
            href="#sovereign-access"
            className="mt-8 inline-flex min-h-[52px] min-w-[240px] items-center justify-center rounded-full border border-fel-cyan/60 bg-fel-cyan/10 px-10 text-sm font-black uppercase tracking-[0.14em] text-fel-cyan transition hover:border-fel-cyan hover:bg-fel-cyan/20"
          >
            Sovereign checkout
          </a>
        </div>
      </div>
    </section>
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
          Signal capture
        </span>
      </div>
      <p className="mt-3 text-[0.65rem] font-semibold uppercase tracking-[0.2em] text-white/60">Input channel</p>
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
            PRQ
          </span>
        </div>
      </div>
      <p className="mt-2 text-center text-[0.6rem] uppercase tracking-[0.35em] text-white/40">
        Athlete readiness · timing · output
      </p>
    </div>
  );
}

function SystemCalibrationNode() {
  return (
    <div className="flex flex-1 flex-col items-center text-center">
      <div className="w-full max-w-xs rounded-xl border border-fel-amber/35 bg-gradient-to-br from-fel-amber/10 to-transparent px-5 py-6 shadow-[0_0_28px_rgba(252,238,10,0.12)]">
        <p className="font-mono text-[0.55rem] uppercase tracking-[0.3em] text-fel-amber/90">System calibration</p>
        <p className="mt-3 text-lg font-black uppercase leading-tight text-white">
          Protocol
          <br />
          <span className="text-fel-cyan">phases</span>
        </p>
        <p className="mt-3 text-[0.65rem] leading-relaxed text-white/45">
          Approach · load · takeoff — repeatable phases mapped to your readiness band
        </p>
      </div>
      <p className="mt-3 text-[0.65rem] font-semibold uppercase tracking-[0.2em] text-white/60">System calibration</p>
    </div>
  );
}
