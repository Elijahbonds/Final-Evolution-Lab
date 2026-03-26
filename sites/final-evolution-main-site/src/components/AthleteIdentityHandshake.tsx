import type { IdentityHandshakePayload } from "../hooks/useReadinessSnapshot";

type Props = {
  identity: IdentityHandshakePayload;
  loading: boolean;
  signedIn: boolean;
};

/**
 * Phase 1 — Identity Handshake: live PRQ + Creator Card fields from the same
 * `readiness_snapshots.snapshot` JSON Unreal ingests (prqScore, stoodCreatorCardId, etc.).
 */
export function AthleteIdentityHandshake({ identity, loading, signedIn }: Props) {
  if (!signedIn) {
    return (
      <div className="mt-4 rounded-xl border border-white/10 bg-black/50 px-4 py-3 text-left">
        <p className="text-[0.6rem] font-bold uppercase tracking-[0.28em] text-fel-cyan">Athlete identity</p>
        <p className="mt-1 text-xs text-white/45">
          Sign in to link System Scan data — your PRQ and Creator Card sync from Supabase into this dashboard
          and the Sovereign Lab runtime.
        </p>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="mt-4 rounded-xl border border-white/10 bg-black/50 px-4 py-3 text-xs text-white/40">
        Loading athlete profile from scan…
      </div>
    );
  }

  const prq =
    typeof identity.prqScore === "number" && Number.isFinite(identity.prqScore)
      ? Math.round(Math.min(100, Math.max(0, identity.prqScore)))
      : null;

  const tierRaw = identity.stoodCardTier?.trim();
  const tier =
    tierRaw && tierRaw.toLowerCase() !== "standard" ? `tier ${tierRaw}` : null;

  const cardLine =
    [identity.stoodCreatorCardTraitLine?.trim(), identity.stoodCreatorCardId?.trim(), tier]
      .filter(Boolean)
      .join(" · ") || null;

  return (
    <div
      className="mt-4 rounded-xl border border-fel-cyan/25 bg-gradient-to-r from-fel-cyan/[0.06] to-black/60 px-4 py-3 text-left shadow-[0_0_20px_rgba(92,225,230,0.08)]"
      role="region"
      aria-label="Performance readiness and creator card"
    >
        <p className="text-[0.6rem] font-bold uppercase tracking-[0.28em] text-fel-cyan">Athlete readiness · Creator Card</p>
      <div className="mt-2 flex flex-col gap-1 sm:flex-row sm:flex-wrap sm:items-baseline sm:gap-x-6">
        <p className="font-mono text-sm text-white">
          <span className="text-white/50">PRQ</span>
          <span className="sr-only">Performance Readiness Quotient</span>{" "}
          <span className="text-xl font-black tabular-nums text-fel-cyan">{prq ?? "—"}</span>
        </p>
        {cardLine ? (
          <p className="max-w-xl text-xs leading-snug text-white/70">
            <span className="font-semibold text-white/85">Creator Card</span> — {cardLine}
          </p>
        ) : (
          <p className="text-xs text-white/45">Creator Card — awaiting stood card from your profile / scan export.</p>
        )}
      </div>
    </div>
  );
}
