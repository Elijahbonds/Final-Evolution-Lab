/**
 * Map Wix Store line totals (USD cents) → Sovereign credits for felRelayWixOrder → wix-order-completed.
 * Tune to match your Wix product prices. Supabase RPC name: fel_apply_stripe_shard_credit (via Edge Function).
 *
 * @example
 *   const { shard_delta, cortex_delta, product_sku } = creditsForWixCents(1999);
 */

export const FEL_WIX_CENTS_TO_CREDITS = {
  1999: { shard_delta: 500, cortex_delta: 120, product_sku: "wix_vva_blueprint" },
  4999: { shard_delta: 750, cortex_delta: 40, product_sku: "wix_cortex_shard_pack" },
  9999: { shard_delta: 2500, cortex_delta: 200, product_sku: "wix_sovereign_pro" },
};

export function creditsForWixCents(totalCents) {
  const row = FEL_WIX_CENTS_TO_CREDITS[totalCents];
  if (!row) {
    return { shard_delta: 0, cortex_delta: 0, product_sku: "wix_custom" };
  }
  return { ...row };
}
