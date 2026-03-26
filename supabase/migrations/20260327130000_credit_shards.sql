-- PayPal Sovereign Alpha — shard-only credit path for Edge Function `paypal-verify`.
-- Wraps existing fel_apply_stripe_shard_credit (idempotent via p_idempotency_key → stripe_session_id column).

CREATE OR REPLACE FUNCTION public.credit_shards(
  p_user_id uuid,
  p_shard_delta bigint,
  p_idempotency_key text,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_shard_delta IS NULL OR p_shard_delta <= 0 THEN
    RAISE EXCEPTION 'invalid p_shard_delta';
  END IF;
  IF p_idempotency_key IS NULL OR trim(p_idempotency_key) = '' THEN
    RAISE EXCEPTION 'invalid p_idempotency_key';
  END IF;

  PERFORM public.fel_apply_stripe_shard_credit(
    p_user_id,
    p_shard_delta,
    0,
    trim(p_idempotency_key),
    'paypal_sovereign_alpha',
    p_metadata
  );
END;
$$;

REVOKE ALL ON FUNCTION public.credit_shards(uuid, bigint, text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.credit_shards(uuid, bigint, text, jsonb) TO service_role;

COMMENT ON FUNCTION public.credit_shards IS 'PayPal-verified shard credit; idempotent key stored in sovereign_market_transactions.stripe_session_id.';
