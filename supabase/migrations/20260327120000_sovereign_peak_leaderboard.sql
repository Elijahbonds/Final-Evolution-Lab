-- Sovereign Economy & Peak Leaderboard 1.0.0
-- NOTE: public.user_balances already exists (20260324120000_sovereign_bank.sql) with cortex_credits,
-- unlocked_gear_json, and fel_apply_stripe_shard_credit — do NOT recreate here.

BEGIN;

-- Peak leaderboard — matches Source/FELSovereignLeaderboardSync.swift (REST upsert on athlete_id).
-- athlete_id: local app profile id (text). user_id: Supabase Auth — required for RLS.
CREATE TABLE IF NOT EXISTS public.sovereign_peak_leaderboard (
  athlete_id text PRIMARY KEY,
  display_name text NOT NULL,
  all_time_peak_z double precision NOT NULL CHECK (all_time_peak_z > 0),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS sovereign_peak_leaderboard_peak_idx
  ON public.sovereign_peak_leaderboard (all_time_peak_z DESC);

CREATE INDEX IF NOT EXISTS sovereign_peak_leaderboard_user_idx
  ON public.sovereign_peak_leaderboard (user_id);

ALTER TABLE public.sovereign_peak_leaderboard ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public leaderboard viewing" ON public.sovereign_peak_leaderboard;
CREATE POLICY "Public leaderboard viewing"
  ON public.sovereign_peak_leaderboard
  FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Athletes upsert own peak row" ON public.sovereign_peak_leaderboard;
CREATE POLICY "Athletes upsert own peak row"
  ON public.sovereign_peak_leaderboard
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Athletes update own peak row" ON public.sovereign_peak_leaderboard;
CREATE POLICY "Athletes update own peak row"
  ON public.sovereign_peak_leaderboard
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

COMMENT ON TABLE public.sovereign_peak_leaderboard IS 'Vertical Velocity / Peak Z — public read; writes require user_id = auth.uid() for REST upsert from iOS.';

COMMIT;
