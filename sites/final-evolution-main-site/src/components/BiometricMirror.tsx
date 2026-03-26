/**
 * SFMA-style biometric mirror: stylized skeleton with joint mobility overlays.
 * Locked → neon red · Mobile → neon cyan (clinical education visualization).
 */

export type SFMAJointId =
  | "cervical"
  | "t_spine"
  | "l_spine"
  | "shoulder_l"
  | "shoulder_r"
  | "elbow_l"
  | "elbow_r"
  | "wrist_l"
  | "wrist_r"
  | "hip_l"
  | "hip_r"
  | "knee_l"
  | "knee_r"
  | "ankle_l"
  | "ankle_r";

export type JointMobility = "locked" | "mobile";

export type BiometricMirrorProps = {
  /** Per-joint state; omitted joints render as neutral forensic wire. */
  joints?: Partial<Record<SFMAJointId, JointMobility>>;
  /**
   * When `snapshot.sfma_multi_segmental_rotation_passed === false`, enable red congestion treatment
   * (visual overlay — not a diagnosis).
   */
  redCongestion?: boolean;
  className?: string;
};

const BONE = "rgba(255,255,255,0.14)";
const NEUTRAL_JOINT = "rgba(255,255,255,0.22)";

function jointFill(state: JointMobility | undefined): string {
  if (state === "locked") return "#ff3355";
  if (state === "mobile") return "#5ce1e6";
  return NEUTRAL_JOINT;
}

/** Joint positions (frontal plane, arbitrary lab units). */
const J: Record<SFMAJointId, { x: number; y: number }> = {
  cervical: { x: 100, y: 52 },
  t_spine: { x: 100, y: 108 },
  l_spine: { x: 100, y: 158 },
  shoulder_l: { x: 72, y: 78 },
  shoulder_r: { x: 128, y: 78 },
  elbow_l: { x: 58, y: 128 },
  elbow_r: { x: 142, y: 128 },
  wrist_l: { x: 48, y: 178 },
  wrist_r: { x: 152, y: 178 },
  hip_l: { x: 86, y: 202 },
  hip_r: { x: 114, y: 202 },
  knee_l: { x: 82, y: 268 },
  knee_r: { x: 118, y: 268 },
  ankle_l: { x: 78, y: 338 },
  ankle_r: { x: 122, y: 338 },
};

export function BiometricMirror({ joints = {}, redCongestion = false, className = "" }: BiometricMirrorProps) {
  const ids = Object.keys(J) as SFMAJointId[];

  return (
    <div
      className={`relative overflow-hidden rounded-2xl border border-white/10 bg-black/50 backdrop-blur-md ${className}`}
    >
      {redCongestion ? (
        <>
          <div
            className="pointer-events-none absolute inset-0 z-10 mix-blend-screen"
            style={{
              background:
                "radial-gradient(ellipse 80% 70% at 50% 45%, rgba(255,40,60,0.45) 0%, transparent 65%), linear-gradient(180deg, rgba(120,0,20,0.35), transparent)",
              animation: "felCongestionPulse 2.2s ease-in-out infinite",
            }}
            aria-hidden
          />
          <p className="absolute left-3 top-3 z-20 max-w-[11rem] rounded border border-fel-red/60 bg-black/70 px-2 py-1 text-[0.55rem] font-bold uppercase leading-tight tracking-wide text-fel-red shadow-[0_0_12px_rgba(255,51,85,0.5)]">
            Red congestion · MSF rotation screen
          </p>
        </>
      ) : null}
      <div
        className="pointer-events-none absolute inset-0 opacity-[0.07]"
        style={{
          backgroundImage:
            "repeating-linear-gradient(0deg, transparent, transparent 2px, rgba(92,225,230,0.4) 2px, rgba(92,225,230,0.4) 3px)",
        }}
        aria-hidden
      />
      <div className="relative px-4 pb-5 pt-4">
        <p className="text-[0.55rem] font-bold uppercase tracking-[0.35em] text-fel-cyan/90">
          Biometric mirror
        </p>
        <p className="mt-1 text-[0.65rem] text-white/45">SFMA overlay · forensic wireframe</p>

        <style>{`@keyframes felCongestionPulse { 0%,100% { opacity: 0.85; } 50% { opacity: 1; } }`}</style>
        <svg
          viewBox="0 0 200 380"
          className={`mx-auto mt-3 h-[min(420px,55vh)] w-full max-w-[280px] ${redCongestion ? "opacity-95 saturate-150" : ""}`}
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
          aria-label="Stylized skeleton with SFMA joint overlays"
        >
          <defs>
            <filter id="felJointGlow" x="-50%" y="-50%" width="200%" height="200%">
              <feGaussianBlur stdDeviation="1.8" result="b" />
              <feMerge>
                <feMergeNode in="b" />
                <feMergeNode in="SourceGraphic" />
              </feMerge>
            </filter>
            {redCongestion ? (
              <filter id="felRedCongestionShader" x="-20%" y="-20%" width="140%" height="140%">
                <feColorMatrix
                  in="SourceGraphic"
                  type="matrix"
                  values="1.15 0 0 0 0.08  0 0.35 0 0 0  0 0 0.35 0 0  0 0 0 0.92 0"
                />
              </filter>
            ) : null}
          </defs>
          <g filter={redCongestion ? "url(#felRedCongestionShader)" : undefined}>

          {/* Pelvis / rib cage — translucent “motion” volumes */}
          <ellipse
            cx="100"
            cy="118"
            rx="28"
            ry="44"
            stroke={BONE}
            strokeWidth="1"
            fill="rgba(92,225,230,0.04)"
          />
          <ellipse
            cx="100"
            cy="208"
            rx="36"
            ry="22"
            stroke={BONE}
            strokeWidth="1"
            fill="rgba(255,255,255,0.02)"
          />

          {/* Skull */}
          <ellipse cx="100" cy="38" rx="22" ry="26" stroke={BONE} strokeWidth="1.2" fill="rgba(0,0,0,0.35)" />

          {/* Bones */}
          <path
            d="M100 64 L100 88 M100 88 L72 78 M100 88 L128 78 M72 78 L58 128 L48 178 M128 78 L142 128 L152 178 M100 118 L100 158 M100 158 L86 202 M100 158 L114 202 M86 202 L82 268 L78 338 M114 202 L118 268 L122 338"
            stroke={BONE}
            strokeWidth="1.4"
            strokeLinecap="round"
            strokeLinejoin="round"
          />

          {/* Joints */}
          {ids.map((id) => {
            const p = J[id];
            const state = joints[id];
            const fill = jointFill(state);
            const r = state ? 7 : 5;
            return (
              <g key={id} filter={state ? "url(#felJointGlow)" : undefined}>
                <circle cx={p.x} cy={p.y} r={r + 2} fill={fill} opacity={state ? 0.25 : 0.12} />
                <circle cx={p.x} cy={p.y} r={r} fill={fill} opacity={state ? 0.95 : 0.5} />
              </g>
            );
          })}
          </g>
        </svg>

        <div className="mt-2 flex flex-wrap justify-center gap-4 text-[0.6rem] uppercase tracking-wider text-white/40">
          <span>
            <span className="inline-block h-2 w-2 rounded-full bg-fel-red shadow-[0_0_8px_#ff3355]" /> Locked
          </span>
          <span>
            <span className="inline-block h-2 w-2 rounded-full bg-fel-cyan shadow-[0_0_8px_#5ce1e6]" /> Mobile
          </span>
        </div>
      </div>
    </div>
  );
}
