import { useEffect, useState } from "react";
import type { RealtimeChannel, SupabaseClient } from "@supabase/supabase-js";
import type { SFMAJointId, JointMobility } from "../components/BiometricMirror";

export type ReadinessPayload = {
  joints?: Partial<Record<SFMAJointId, JointMobility>>;
  /** When false, UI shows Red Congestion (multi-segmental rotation screen). */
  sfma_multi_segmental_rotation_passed?: boolean;
};

/** Mirrors Unreal `FELReadinessIO` / `readiness_snapshot.json` clinical keys. */
export type IdentityHandshakePayload = {
  prqScore?: number;
  stoodCreatorCardId?: string;
  stoodCreatorCardTraitLine?: string;
  stoodCardTier?: string;
};

function parseNumber(v: unknown): number | undefined {
  if (typeof v === "number" && Number.isFinite(v)) return v;
  if (typeof v === "string" && v.trim() !== "") {
    const n = Number(v);
    if (Number.isFinite(n)) return n;
  }
  return undefined;
}

function parseString(v: unknown): string | undefined {
  if (typeof v === "string" && v.trim() !== "") return v;
  return undefined;
}

function parsePayload(row: { snapshot: unknown } | null): ReadinessPayload {
  if (!row || typeof row.snapshot !== "object" || row.snapshot === null) return {};
  const s = row.snapshot as Record<string, unknown>;
  const out: ReadinessPayload = {};
  const rot =
    s.sfma_multi_segmental_rotation_passed ?? s.sfmaMultiSegmentalRotationPassed;
  if (typeof rot === "boolean") {
    out.sfma_multi_segmental_rotation_passed = rot;
  }
  if (s.joints && typeof s.joints === "object" && s.joints !== null) {
    out.joints = s.joints as Partial<Record<SFMAJointId, JointMobility>>;
  }
  return out;
}

function parseIdentity(row: { snapshot: unknown } | null): IdentityHandshakePayload {
  if (!row || typeof row.snapshot !== "object" || row.snapshot === null) return {};
  const s = row.snapshot as Record<string, unknown>;
  const prq =
    parseNumber(s.prqScore) ??
    parseNumber(s.prq_score) ??
    parseNumber(s.PRQScore);
  return {
    prqScore: prq,
    stoodCreatorCardId:
      parseString(s.stoodCreatorCardId) ?? parseString(s.stood_creator_card_id),
    stoodCreatorCardTraitLine:
      parseString(s.stoodCreatorCardTraitLine) ?? parseString(s.stood_creator_card_trait_line),
    stoodCardTier: parseString(s.stoodCardTier) ?? parseString(s.stood_card_tier),
  };
}

/**
 * Latest `readiness_snapshots` row for the signed-in user (Supabase).
 * Subscribes to realtime INSERT/UPDATE so System Scan → PRQ updates reflect immediately.
 */
export function useReadinessSnapshot(): {
  payload: ReadinessPayload;
  identity: IdentityHandshakePayload;
  loading: boolean;
  error: string | null;
  signedIn: boolean;
} {
  const [payload, setPayload] = useState<ReadinessPayload>({});
  const [identity, setIdentity] = useState<IdentityHandshakePayload>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [signedIn, setSignedIn] = useState(false);

  useEffect(() => {
    let cancelled = false;
    const rt = { supabase: null as SupabaseClient | null, channel: null as RealtimeChannel | null };

    (async () => {
      const url = import.meta.env.VITE_SUPABASE_URL;
      const key = import.meta.env.VITE_SUPABASE_ANON_KEY;
      if (!url || !key) {
        setLoading(false);
        return;
      }
      const { createClient } = await import("@supabase/supabase-js");
      const supabase = createClient(url, key);
      rt.supabase = supabase;
      const { data: sessionData } = await supabase.auth.getSession();
      const uid = sessionData.session?.user?.id;
      if (!uid) {
        setSignedIn(false);
        setLoading(false);
        return;
      }
      setSignedIn(true);

      const applyRow = (row: { snapshot: unknown } | null) => {
        setPayload(parsePayload(row));
        setIdentity(parseIdentity(row));
      };

      const { data, error: qErr } = await supabase
        .from("readiness_snapshots")
        .select("snapshot")
        .eq("user_id", uid)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      if (cancelled) return;
      if (qErr) {
        setError(qErr.message);
        setLoading(false);
        return;
      }
      applyRow(data);
      setLoading(false);

      rt.channel = supabase
        .channel(`readiness_snapshots:${uid}`)
        .on(
          "postgres_changes",
          {
            event: "*",
            schema: "public",
            table: "readiness_snapshots",
            filter: `user_id=eq.${uid}`,
          },
          async () => {
            const { data: fresh } = await supabase
              .from("readiness_snapshots")
              .select("snapshot")
              .eq("user_id", uid)
              .order("created_at", { ascending: false })
              .limit(1)
              .maybeSingle();
            if (!cancelled) applyRow(fresh);
          }
        )
        .subscribe();
    })();

    return () => {
      cancelled = true;
      if (rt.supabase && rt.channel) {
        void rt.supabase.removeChannel(rt.channel);
      }
    };
  }, []);

  return { payload, identity, loading, error, signedIn };
}
