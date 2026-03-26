-- Extend credit_shards: optional cortex (Blueprint) credits for Pro-tier PayPal SKUs.
DROP FUNCTION IF EXISTS public.credit_shards(uuid, bigint, text, jsonb);

CREATE OR REPLACE FUNCTION public.credit_shards(
  p_user_id uuid,
  p_shard_delta bigint,
  p_idempotency_key text,
  p_metadata jsonb DEFAULT '{}'::jsonb,
  p_cortex_delta bigint DEFAULT 0
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_shard_delta IS NULL OR p_shard_delta < 0 THEN
    RAISE EXCEPTION 'invalid p_shard_delta';
  END IF;
  IF p_cortex_delta IS NULL OR p_cortex_delta < 0 THEN
    RAISE EXCEPTION 'invalid p_cortex_delta';
  END IF;
  IF p_shard_delta = 0 AND p_cortex_delta = 0 THEN
    RAISE EXCEPTION 'invalid deltas';
  END IF;
  IF p_idempotency_key IS NULL OR trim(p_idempotency_key) = '' THEN
    RAISE EXCEPTION 'invalid p_idempotency_key';
  END IF;

  PERFORM public.fel_apply_stripe_shard_credit(
    p_user_id,
    p_shard_delta,
    p_cortex_delta,
    trim(p_idempotency_key),
    'paypal_sovereign_alpha',
    p_metadata
  );
END;
$$;

REVOKE ALL ON FUNCTION public.credit_shards(uuid, bigint, text, jsonb, bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.credit_shards(uuid, bigint, text, jsonb, bigint) TO service_role;

COMMENT ON FUNCTION public.credit_shards IS
  'PayPal-verified Evolution Shards + optional Blueprint (cortex) credits; idempotent via sovereign_market_transactions.stripe_session_id.';
