-- Clinical readiness mirror — JSON snapshot for BiometricMirror / Lab HUD (FEL 1.0.0).
-- iOS / Unreal writers upsert rows; web reads latest per user.

CREATE TABLE IF NOT EXISTS public.readiness_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  athlete_id text,
  snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS readiness_snapshots_user_created_idx
  ON public.readiness_snapshots (user_id, created_at DESC);

ALTER TABLE public.readiness_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "readiness_snapshots_select_own" ON public.readiness_snapshots;
CREATE POLICY "readiness_snapshots_select_own"
  ON public.readiness_snapshots
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

COMMENT ON TABLE public.readiness_snapshots IS
  'Latest SFMA/FMS-style payload: joints map, sfma_multi_segmental_rotation_passed, etc.';
