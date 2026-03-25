-- Sovereign production — Edge Function can resolve auth users by email and upsert athlete ↔ Stripe links.

ALTER TABLE public.athlete_profile_link
  ADD COLUMN IF NOT EXISTS stripe_customer_id text;

CREATE INDEX IF NOT EXISTS athlete_profile_link_stripe_customer_idx
  ON public.athlete_profile_link (stripe_customer_id)
  WHERE stripe_customer_id IS NOT NULL;

-- Resolve Supabase auth user UUID from email (Checkout customer_email). Service role only.
CREATE OR REPLACE FUNCTION public.fel_resolve_user_id_by_email(p_email text)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id
  FROM auth.users
  WHERE lower(trim(email)) = lower(trim(p_email))
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.fel_resolve_user_id_by_email(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fel_resolve_user_id_by_email(text) TO service_role;

-- Server-side link: athlete_id + auth user + optional Stripe Customer id (cus_...).
CREATE OR REPLACE FUNCTION public.fel_upsert_athlete_profile_link_for_service(
  p_athlete_id text,
  p_user_id uuid,
  p_stripe_customer_id text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_athlete_id IS NULL OR trim(p_athlete_id) = '' THEN
    RAISE EXCEPTION 'invalid athlete_id';
  END IF;
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'invalid user_id';
  END IF;

  INSERT INTO public.athlete_profile_link (athlete_id, user_id, stripe_customer_id, updated_at)
  VALUES (trim(p_athlete_id), p_user_id, NULLIF(trim(p_stripe_customer_id), ''), now())
  ON CONFLICT (athlete_id) DO UPDATE SET
    user_id = EXCLUDED.user_id,
    stripe_customer_id = COALESCE(EXCLUDED.stripe_customer_id, public.athlete_profile_link.stripe_customer_id),
    updated_at = now();
END;
$$;

REVOKE ALL ON FUNCTION public.fel_upsert_athlete_profile_link_for_service(text, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fel_upsert_athlete_profile_link_for_service(text, uuid, text) TO service_role;

COMMENT ON COLUMN public.athlete_profile_link.stripe_customer_id IS 'Stripe Customer id (cus_...) linked on first successful Checkout; optional.';
