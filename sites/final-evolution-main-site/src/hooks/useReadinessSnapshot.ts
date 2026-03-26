import { useEffect, useState } from "react";
import type { SFMAJointId, JointMobility } from "../components/BiometricMirror";

export type ReadinessPayload = {
  joints?: Partial<Record<SFMAJointId, JointMobility>>;
  /** When false, UI shows Red Congestion (multi-segmental rotation screen). */
  sfma_multi_segmental_rotation_passed?: boolean;
};

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

/**
 * Latest `readiness_snapshots` row for the signed-in user (Supabase).
 */
export function useReadinessSnapshot(): {
  payload: ReadinessPayload;
  loading: boolean;
  error: string | null;
} {
  const [payload, setPayload] = useState<ReadinessPayload>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    (async () => {
      const url = import.meta.env.VITE_SUPABASE_URL;
      const key = import.meta.env.VITE_SUPABASE_ANON_KEY;
      if (!url || !key) {
        setLoading(false);
        return;
      }
      const { createClient } = await import("@supabase/supabase-js");
      const supabase = createClient(url, key);
      const { data: sessionData } = await supabase.auth.getSession();
      const uid = sessionData.session?.user?.id;
      if (!uid) {
        setLoading(false);
        return;
      }

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
      setPayload(parsePayload(data));
      setLoading(false);
    })();

    return () => {
      cancelled = true;
    };
  }, []);

  return { payload, loading, error };
}
