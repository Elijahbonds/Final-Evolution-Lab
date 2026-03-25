/**
 * Optional: Wix Stores — order-paid hook (API varies by Wix version).
 * Prefer Wix Automations → Webhook POST → post_felRelayWixOrder for reliability.
 *
 * If your site supports backend events, wire the handler to build JSON:
 *   { wix_order_id, supabase_user_id, athlete_id?, shard_delta, cortex_delta, product_sku }
 * and POST to the same URL as http-functions.js (or import shared relay).
 *
 * @example (pseudocode — verify against current Wix Stores / ecom docs)
 * import { ok } from 'wix-http-functions';
 * export async function handleOrderPaid(event) {
 *   await relayToSupabase(mapOrderToFelPayload(event));
 *   return ok();
 * }
 */
