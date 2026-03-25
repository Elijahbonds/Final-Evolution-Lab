-- Final Evolution — Sovereign Bank (1.0.0)
-- user_balances: wallet; sovereign_market_transactions: Stripe audit trail.
-- RLS: authenticated users SELECT own row only; mutations via service role / SECURITY DEFINER RPC.

-- ---------------------------------------------------------------------------
-- Wallet
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_balances (
  user_id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  shard_balance bigint NOT NULL DEFAULT 0 CHECK (shard_balance >= 0),
  cortex_credits bigint NOT NULL DEFAULT 0 CHECK (cortex_credits >= 0),
  unlocked_gear_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS user_balances_updated_at_idx ON public.user_balances (updated_at DESC);

ALTER TABLE public.user_balances ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_balances_select_own" ON public.user_balances;
CREATE POLICY "user_balances_select_own"
  ON public.user_balances
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- No INSERT/UPDATE/DELETE for authenticated role — use service role or RPC below.

-- ---------------------------------------------------------------------------
-- Stripe / marketplace audit (read own rows)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sovereign_market_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  stripe_session_id text UNIQUE,
  stripe_payment_intent_id text,
  product_sku text,
  shard_delta bigint NOT NULL DEFAULT 0,
  cortex_delta bigint NOT NULL DEFAULT 0,
  currency text DEFAULT 'usd',
  amount_cents integer,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS sovereign_market_tx_user_created_idx
  ON public.sovereign_market_transactions (user_id, created_at DESC);

ALTER TABLE public.sovereign_market_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "sovereign_market_tx_select_own" ON public.sovereign_market_transactions;
CREATE POLICY "sovereign_market_tx_select_own"
  ON public.sovereign_market_transactions
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- SECURITY DEFINER: atomic increment from Edge Functions (Stripe webhook)
-- Only postgres / service role should EXECUTE in production (revoke from PUBLIC).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fel_apply_stripe_shard_credit(
  p_user_id uuid,
  p_shard_delta bigint,
  p_cortex_delta bigint DEFAULT 0,
  p_stripe_session_id text DEFAULT NULL,
  p_product_sku text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_stripe_session_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.sovereign_market_transactions t WHERE t.stripe_session_id = p_stripe_session_id
  ) THEN
    RETURN;
  END IF;

  IF p_shard_delta = 0 AND p_cortex_delta = 0 THEN
    RETURN;
  END IF;

  INSERT INTO public.user_balances (user_id, shard_balance, cortex_credits)
  VALUES (p_user_id, GREATEST(0, p_shard_delta), GREATEST(0, p_cortex_delta))
  ON CONFLICT (user_id) DO UPDATE SET
    shard_balance = public.user_balances.shard_balance + p_shard_delta,
    cortex_credits = public.user_balances.cortex_credits + p_cortex_delta,
    updated_at = now();

  INSERT INTO public.sovereign_market_transactions (
    user_id, stripe_session_id, product_sku, shard_delta, cortex_delta, metadata
  )
  VALUES (
    p_user_id,
    p_stripe_session_id,
    p_product_sku,
    p_shard_delta,
    p_cortex_delta,
    p_metadata
  );
END;
$$;

REVOKE ALL ON FUNCTION public.fel_apply_stripe_shard_credit(uuid, bigint, bigint, text, text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fel_apply_stripe_shard_credit(uuid, bigint, bigint, text, text, jsonb) TO service_role;

COMMENT ON TABLE public.user_balances IS 'Sovereign wallet — RLS: users SELECT own; updates via service_role RPC / Edge.';
COMMENT ON TABLE public.sovereign_market_transactions IS 'Stripe checkout audit — one row per credited session.';
