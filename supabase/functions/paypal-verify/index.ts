// Supabase Edge Function — PayPal Orders API verify → public.credit_shards
//
// Client POST (after actions.order.capture): { orderID, athlete_id? }
// Authorization: Bearer <supabase access_token>
//
// Secrets: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY,
//          PAYPAL_CLIENT_ID, PAYPAL_SECRET, PAYPAL_ENV (sandbox|live)
//
// Amount → Sovereign economy: $499 → 5000 shards; $99 → 1200 shards + 500 Blueprint (cortex); $49 → 500 shards

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function paypalBase(): string {
  const env = Deno.env.get("PAYPAL_ENV") ?? "sandbox";
  return env === "live"
    ? "https://api-m.paypal.com"
    : "https://api-m.sandbox.paypal.com";
}

async function paypalAccessToken(): Promise<string> {
  const id = Deno.env.get("PAYPAL_CLIENT_ID") ?? "";
  const secret = Deno.env.get("PAYPAL_SECRET") ?? "";
  if (!id || !secret) throw new Error("missing_paypal_credentials");

  const auth = btoa(`${id}:${secret}`);
  const res = await fetch(`${paypalBase()}/v1/oauth2/token`, {
    method: "POST",
    headers: {
      Authorization: `Basic ${auth}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });
  const json = await res.json();
  if (!res.ok) throw new Error(json.error_description ?? json.error ?? "paypal_oauth_failed");
  return json.access_token as string;
}

async function getPayPalOrder(orderId: string, token: string): Promise<Record<string, unknown>> {
  const res = await fetch(`${paypalBase()}/v2/checkout/orders/${orderId}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const json = await res.json();
  if (!res.ok) throw new Error((json as { message?: string }).message ?? "paypal_get_order_failed");
  return json as Record<string, unknown>;
}

/** Map captured USD total → Sovereign economy credit (shards + optional Blueprint / cortex). */
type SovereignCredit = { shards: number; cortex: number };

/** PayPal JSON sometimes uses string amounts; rare clients send numbers. */
function parseMoneyValue(raw: unknown): number | null {
  if (typeof raw === "number" && Number.isFinite(raw)) return raw;
  if (typeof raw === "string") {
    const n = parseFloat(raw.replace(/,/g, "").trim());
    return Number.isFinite(n) ? n : null;
  }
  return null;
}

/**
 * Integer-cent tier match (avoids 49.0000001 float drift). ±1 cent forgiveness after rounding.
 * Must stay aligned with `sites/final-evolution-main-site/src/constants/paypal.ts` TIER_SHARD_DELTA / TIER_BLUEPRINT_CREDIT_DELTA.
 */
function sovereignCreditForAmountUsd(total: number): SovereignCredit | null {
  if (!Number.isFinite(total) || total <= 0) return null;
  const cents = Math.round(total * 100);

  const tiers: Array<{ cents: number; shards: number; cortex: number }> = [
    { cents: 49900, shards: 5000, cortex: 0 },
    { cents: 9900, shards: 1200, cortex: 500 },
    { cents: 4900, shards: 500, cortex: 0 },
  ];

  for (const t of tiers) {
    if (cents === t.cents) return { shards: t.shards, cortex: t.cortex };
  }
  for (const t of tiers) {
    if (Math.abs(cents - t.cents) <= 1) return { shards: t.shards, cortex: t.cortex };
  }
  return null;
}

/** Prefer capture line items; fall back to purchase unit total when COMPLETED but captures are absent. */
function extractCapturedAmountUsd(order: Record<string, unknown>): number | null {
  const units = order.purchase_units as unknown[] | undefined;
  const u0 = units?.[0] as Record<string, unknown> | undefined;
  if (!u0) return null;

  const payments = u0.payments as Record<string, unknown> | undefined;
  const captures = payments?.captures as unknown[] | undefined;
  if (captures && captures.length > 0) {
    let sum = 0;
    for (const c of captures) {
      const cap = c as Record<string, unknown>;
      const amount = cap.amount as Record<string, unknown> | undefined;
      const code = amount?.currency_code;
      if (typeof code === "string" && code !== "USD") continue;
      const v = parseMoneyValue(amount?.value);
      if (v == null) continue;
      sum += v;
    }
    if (sum > 0) return Math.round(sum * 100) / 100;
  }

  const uAmount = u0.amount as Record<string, unknown> | undefined;
  const unitCode = uAmount?.currency_code;
  if (typeof unitCode === "string" && unitCode !== "USD") return null;
  const unitTotal = parseMoneyValue(uAmount?.value);
  if (unitTotal != null && unitTotal > 0) return Math.round(unitTotal * 100) / 100;

  return null;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "method_not_allowed" }), {
      status: 405,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !anonKey || !serviceKey) {
    return new Response(JSON.stringify({ error: "server_misconfigured" }), {
      status: 500,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!jwt) {
    return new Response(JSON.stringify({ error: "missing_authorization" }), {
      status: 401,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  const userClient = createClient(supabaseUrl, anonKey);
  const { data: userData, error: userErr } = await userClient.auth.getUser(jwt);
  if (userErr || !userData.user) {
    return new Response(JSON.stringify({ error: "invalid_session" }), {
      status: 401,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  let body: { orderID?: string; athlete_id?: string };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "invalid_json" }), {
      status: 400,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  const orderID = String(body.orderID ?? "").trim();
  const athleteId = body.athlete_id ? String(body.athlete_id).trim() : "";

  if (!orderID) {
    return new Response(JSON.stringify({ error: "missing_orderID" }), {
      status: 400,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  const userId = userData.user.id;

  let order: Record<string, unknown>;
  try {
    const access = await paypalAccessToken();
    order = await getPayPalOrder(orderID, access);
  } catch (e) {
    console.error("paypal", e);
    return new Response(JSON.stringify({ error: "paypal_verification_failed" }), {
      status: 502,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  const status = String(order.status ?? "");
  if (status !== "COMPLETED") {
    return new Response(JSON.stringify({ error: "order_not_completed", status }), {
      status: 400,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  const amountUsd = extractCapturedAmountUsd(order);
  if (amountUsd == null) {
    return new Response(JSON.stringify({ error: "missing_capture_amount" }), {
      status: 400,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  const credit = sovereignCreditForAmountUsd(amountUsd);
  if (credit == null) {
    return new Response(
      JSON.stringify({
        error: "unsupported_amount",
        amount_usd: amountUsd,
        allowed: [49, 99, 499],
      }),
      { status: 400, headers: { ...cors, "Content-Type": "application/json" } },
    );
  }

  const supabase = createClient(supabaseUrl, serviceKey);
  const idempotencyKey = `paypal_${orderID}`;

  if (athleteId) {
    const { error: linkErr } = await supabase.rpc("fel_upsert_athlete_profile_link_for_service", {
      p_athlete_id: athleteId,
      p_user_id: userId,
      p_stripe_customer_id: null,
    });
    if (linkErr) console.error("fel_upsert_athlete_profile_link_for_service", linkErr);
  }

  const metadata = {
    source: "paypal",
    paypal_order_id: orderID,
    athlete_id: athleteId || null,
    amount_usd: amountUsd,
  };

  const { error: rpcErr } = await supabase.rpc("credit_shards", {
    p_user_id: userId,
    p_shard_delta: credit.shards,
    p_idempotency_key: idempotencyKey,
    p_metadata: metadata,
    p_cortex_delta: credit.cortex,
  });

  if (rpcErr) {
    console.error("credit_shards", rpcErr);
    return new Response(JSON.stringify({ error: rpcErr.message }), {
      status: 500,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  return new Response(
    JSON.stringify({
      ok: true,
      orderID,
      shard_delta: credit.shards,
      blueprint_credits_delta: credit.cortex,
      athlete_id: athleteId || null,
    }),
    { status: 200, headers: { ...cors, "Content-Type": "application/json" } },
  );
});
