/** Sovereign Alpha tiers — must match `paypal-verify` amount → shard mapping ($49 / $99 / $499). */
export type SovereignAlphaTier = "alpha_49" | "alpha_99" | "alpha_499";

/**
 * Canonical `paypal-verify` Edge Function (shard crediting).
 * Production: same Supabase project as `VITE_SUPABASE_URL` (live: *.supabase.co).
 * Override with `VITE_PAYPAL_VERIFY_URL` only for staging.
 */
export const PAYPAL_VERIFY_URL_DEFAULT =
  "https://rlqkschgvlrva-wsdzjxq.supabase.co/functions/v1/paypal-verify";

/** Must match `paypal-verify` Edge mapping (Evolution Shards). */
export const TIER_SHARD_DELTA: Record<SovereignAlphaTier, number> = {
  alpha_49: 500,
  alpha_99: 1200,
  alpha_499: 5000,
};

/** Blueprint credits (DB: `cortex_credits`) — Pro tier only; must match Edge mapping. */
export const TIER_BLUEPRINT_CREDIT_DELTA: Record<SovereignAlphaTier, number> = {
  alpha_49: 0,
  alpha_99: 500,
  alpha_499: 0,
};
