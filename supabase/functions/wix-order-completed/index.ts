// Supabase Edge Function — Wix Store order → fel_apply_stripe_shard_credit (idempotent by synthetic session id).
//
// Wix does not send Stripe-signed webhooks. Use this endpoint from Wix Velo (or Automations) with a shared secret.
//
// Secrets:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
//   WIX_WEBHOOK_SHARED_SECRET — must match header X-FEL-Wix-Secret from your Velo relay
//
// Body (JSON):
//   wix_order_id (required), supabase_user_id (required UUID), athlete_id (optional),
//   shard_delta, cortex_delta (optional), product_sku (optional)

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

function unauthorized(): Response {
  return new Response("Unauthorized", { status: 401 });
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const shared = Deno.env.get("WIX_WEBHOOK_SHARED_SECRET") ?? "";
  const header = req.headers.get("x-fel-wix-secret") ?? "";
  if (!shared || header !== shared) {
    return unauthorized();
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "invalid_json" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const orderId = String(body.wix_order_id ?? body.orderId ?? "").trim();
  const userId = String(body.supabase_user_id ?? body.user_id ?? "").trim();
  const athleteId = body.athlete_id ? String(body.athlete_id).trim() : "";
  const shardDelta = parseInt(String(body.shard_delta ?? "0"), 10) || 0;
  const cortexDelta = parseInt(String(body.cortex_delta ?? "0"), 10) || 0;
  const productSku = body.product_sku ? String(body.product_sku) : "wix_sovereign_shard";

  if (!orderId || !userId) {
    return new Response(
      JSON.stringify({ error: "missing wix_order_id or supabase_user_id" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const uuidRe = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (!uuidRe.test(userId)) {
    return new Response(JSON.stringify({ error: "invalid supabase_user_id" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (shardDelta === 0 && cortexDelta === 0) {
    return new Response(JSON.stringify({ error: "zero_credits" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, serviceKey);

  if (athleteId) {
    const { error: linkErr } = await supabase.rpc("fel_upsert_athlete_profile_link_for_service", {
      p_athlete_id: athleteId,
      p_user_id: userId,
      p_stripe_customer_id: null,
    });
    if (linkErr) console.error("fel_upsert_athlete_profile_link_for_service", linkErr);
  }

  const sessionId = `wix_${orderId}`;

  const { error } = await supabase.rpc("fel_apply_stripe_shard_credit", {
    p_user_id: userId,
    p_shard_delta: shardDelta,
    p_cortex_delta: cortexDelta,
    p_stripe_session_id: sessionId,
    p_product_sku: productSku,
    p_metadata: {
      source: "wix",
      wix_order_id: orderId,
      athlete_id: athleteId || null,
    },
  });

  if (error) {
    console.error("fel_apply_stripe_shard_credit", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ ok: true, wix_order_id: orderId, userId, shardDelta, cortexDelta }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
