/**
 * Wix Velo — HTTP Functions (Dev Mode → HTTP Functions).
 * File name / export names follow Wix: https://dev.wix.com/docs/develop-websites/articles/coding-with-velo/code-http-functions
 *
 * Deploy: publish site with Dev Mode. URL shape:
 *   https://<your-site>/_functions/felRelayWixOrder
 *   https://<your-site>/_functions/felWixOrderPaidFromAutomation
 *
 * Order Paid / JOIN NOW flow:
 *   1) Wix Automations → "Order paid" → HTTP POST to felWixOrderPaidFromAutomation (or build JSON and POST to felRelayWixOrder).
 *   2) **JOIN NOW** (members area): store `supabase_user_id` + `athlete_id` in member custom fields or Automation payload —
 *      Velo forwards them so Edge `wix-order-completed` can call `fel_upsert_athlete_profile_link_for_service` + credit RPC.
 *   3) Body must resolve supabase_user_id + wix_order_id + shard_delta (see creditsForWixCents; mirror in felShardCatalog.js).
 *   4) Supabase Edge `wix-order-completed` — header **X-FEL-Wix-Secret** (must match Wix secret + Supabase `WIX_WEBHOOK_SHARED_SECRET`).
 *
 * Secrets (Wix Dashboard → Secrets):
 *   FEL_SUPABASE_ORDER_URL  — https://xxx.supabase.co/functions/v1/wix-order-completed
 *   FEL_WIX_WEBHOOK_SHARED_SECRET — same value as Supabase WIX_WEBHOOK_SHARED_SECRET
 */

import { ok, badRequest, serverError } from "wix-http-functions";
import { fetch } from "wix-fetch";
import { getSecret } from "wix-secrets-backend";

/** USD cents → shard/cortex (tune to Wix product prices). See also felShardCatalog.js copy. */
function creditsForWixCents(totalCents) {
  const map = {
    1999: { shard_delta: 500, cortex_delta: 120, product_sku: "wix_vva_blueprint" },
    4999: { shard_delta: 750, cortex_delta: 40, product_sku: "wix_cortex_shard_pack" },
    9999: { shard_delta: 2500, cortex_delta: 200, product_sku: "wix_sovereign_pro" },
  };
  const row = map[totalCents];
  if (!row) return { shard_delta: 0, cortex_delta: 0, product_sku: "wix_custom" };
  return { ...row };
}

async function relayToSupabase(body) {
  const url = await getSecret("FEL_SUPABASE_ORDER_URL");
  const secret = await getSecret("FEL_WIX_WEBHOOK_SHARED_SECRET");
  if (!url || !secret) {
    throw new Error("Missing Wix secrets: FEL_SUPABASE_ORDER_URL / FEL_WIX_WEBHOOK_SHARED_SECRET");
  }
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-FEL-Wix-Secret": secret,
    },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  if (!res.ok) {
    throw new Error(text || `Upstream ${res.status}`);
  }
  return text;
}

/**
 * POST https://yoursite.com/_functions/felRelayWixOrder
 * Body example (from Automation or your mapper):
 * {
 *   "wix_order_id": "order-guid",
 *   "supabase_user_id": "uuid-from-member-field",
 *   "athlete_id": "optional-local-athlete-id",
 *   "shard_delta": 750,
 *   "cortex_delta": 40,
 *   "product_sku": "wix_sovereign_shard_pack"
 * }
 */
export async function post_felRelayWixOrder(request) {
  try {
    const body = await request.body.json();
    const text = await relayToSupabase(body);
    return ok({ body: text, headers: { "Content-Type": "application/json" } });
  } catch (e) {
    return badRequest({ body: String(e && e.message ? e.message : e) });
  }
}

/**
 * Wix Automation — Order paid (simplified payload). Map fields to match your Automation’s JSON.
 * Expected body (example — adjust keys to match Wix Automation “Send webhook” payload):
 * {
 *   "orderId": "wix-order-guid",
 *   "supabase_user_id": "uuid",
 *   "athlete_id": "optional-app-athlete-id",
 *   "totalAmountCents": 1999
 * }
 */
export async function post_felWixOrderPaidFromAutomation(request) {
  try {
    const raw = await request.body.json();
    const orderId = raw.orderId || raw.id || raw.order_id;
    const supabaseUserId =
      raw.supabase_user_id ||
      raw.userId ||
      (raw.metadata && raw.metadata.supabase_user_id) ||
      (raw.customFields && raw.customFields.supabase_user_id);
    const athleteId =
      raw.athlete_id ||
      raw.athleteId ||
      (raw.metadata && raw.metadata.athlete_id) ||
      (raw.customFields && raw.customFields.athlete_id) ||
      "";
    const cents = parseInt(String(raw.totalAmountCents ?? raw.total?.amount ?? 0), 10) || 0;
    const mapped = creditsForWixCents(cents);

    if (!orderId || !supabaseUserId) {
      return badRequest({ body: "Missing orderId or supabase_user_id" });
    }

    const payload = {
      wix_order_id: String(orderId),
      supabase_user_id: String(supabaseUserId).trim(),
      athlete_id: athleteId ? String(athleteId).trim() : "",
      shard_delta: mapped.shard_delta,
      cortex_delta: mapped.cortex_delta,
      product_sku: mapped.product_sku,
    };

    const text = await relayToSupabase(payload);
    return ok({ body: text, headers: { "Content-Type": "application/json" } });
  } catch (e) {
    return serverError({ body: String(e && e.message ? e.message : e) });
  }
}
