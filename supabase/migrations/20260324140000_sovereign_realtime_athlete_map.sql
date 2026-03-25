-- Total Ignition — Realtime wallet updates + athlete_id → auth user resolution for Stripe webhooks.

-- ---------------------------------------------------------------------------
-- Link app profile `athlete_id` (text) to Supabase auth.users — populated by the app on sign-in / profile sync.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.athlete_profile_link (
  athlete_id text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS athlete_profile_link_user_id_idx ON public.athlete_profile_link (user_id);

ALTER TABLE public.athlete_profile_link ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "athlete_link_select_own" ON public.athlete_profile_link;
CREATE POLICY "athlete_link_select_own"
  ON public.athlete_profile_link
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Inserts/updates from the client should use a SECURITY DEFINER RPC or Edge Function; for now service_role bypasses RLS.
COMMENT ON TABLE public.athlete_profile_link IS 'Maps FEL athlete_id to auth.users.id for Stripe metadata.upsert from app.';

-- ---------------------------------------------------------------------------
-- Realtime: wallet row changes broadcast to subscribed clients (instant 3D dashboard refresh).
-- ---------------------------------------------------------------------------
DO $pub$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'user_balances'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.user_balances;
  END IF;
END
$pub$;
