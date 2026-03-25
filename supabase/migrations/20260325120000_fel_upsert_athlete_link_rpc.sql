-- Client-callable RPC: map local athlete_id to auth.uid() for Stripe webhook resolution.
-- Invoked from the iOS app after Supabase sign-in (Bearer = user JWT).

CREATE OR REPLACE FUNCTION public.fel_upsert_athlete_profile_link(p_athlete_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF p_athlete_id IS NULL OR trim(p_athlete_id) = '' THEN
    RAISE EXCEPTION 'invalid athlete_id';
  END IF;

  INSERT INTO public.athlete_profile_link (athlete_id, user_id, updated_at)
  VALUES (trim(p_athlete_id), auth.uid(), now())
  ON CONFLICT (athlete_id) DO UPDATE SET
    user_id = EXCLUDED.user_id,
    updated_at = now();
END;
$$;

REVOKE ALL ON FUNCTION public.fel_upsert_athlete_profile_link(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fel_upsert_athlete_profile_link(text) TO authenticated;
