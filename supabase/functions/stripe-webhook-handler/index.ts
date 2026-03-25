// Supabase Edge Function — Stripe `checkout.session.completed` → fel_apply_stripe_shard_credit
//
// Secrets (production names — aliases supported):
//   STRIPE_WEBHOOK_SIGNING_SECRET | STRIPE_WEBHOOK_SECRET
//   STRIPE_API_KEY | STRIPE_SECRET_KEY
//   SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL
//
// Resolution order for Supabase user id:
//   1) metadata.supabase_user_id or metadata.user_id
//   2) athlete_profile_link for metadata.athlete_id
//   3) fel_resolve_user_id_by_email(customer email from Checkout)
//
// After resolution: if metadata.athlete_id and userId, fel_upsert_athlete_profile_link_for_service
// (links local athlete_id ↔ auth user and optional Stripe Customer id).
//
// Credits: metadata.shard_delta / cortex_delta OR Price metadata OR amount_total mapping for
// $19.99 / $49.99 / $99.99 (VVA Blueprint, Cortex Shard Pack, Sovereign Pro).

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";
import Stripe from "https://esm.sh/stripe@14.14.0?target=deno";

function stripeSecretKey(): string {
  return Deno.env.get("STRIPE_API_KEY") ?? Deno.env.get("STRIPE_SECRET_KEY") ?? "";
}

function webhookSigningSecret(): string {
  return Deno.env.get("STRIPE_WEBHOOK_SIGNING_SECRET") ?? Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? "";
}

const stripe = new Stripe(stripeSecretKey(), {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
});

/** Default credits when Checkout metadata omits shard_delta (tune for your economy). */
const SOVEREIGN_SKU_DEFAULTS: Record<string, { shard_delta: number; cortex_delta: number }> = {
  vva_blueprint: { shard_delta: 0, cortex_delta: 120 },
  cortex_shard_pack: { shard_delta: 750, cortex_delta: 40 },
  sovereign_pro: { shard_delta: 2500, cortex_delta: 200 },
};

function creditsFromAmountCents(amount: number | null): {
  product_sku: string;
  shard_delta: number;
  cortex_delta: number;
} | null {
  if (amount == null) return null;
  switch (amount) {
    case 1999:
      return { product_sku: "vva_blueprint", ...SOVEREIGN_SKU_DEFAULTS.vva_blueprint };
    case 4999:
      return { product_sku: "cortex_shard_pack", ...SOVEREIGN_SKU_DEFAULTS.cortex_shard_pack };
    case 9999:
      return { product_sku: "sovereign_pro", ...SOVEREIGN_SKU_DEFAULTS.sovereign_pro };
    default:
      return null;
  }
}

serve(async (req) => {
  const signature = req.headers.get("stripe-signature");
  const whSecret = webhookSigningSecret();
  const rawBody = await req.text();

  if (!signature || !whSecret) {
    return new Response("Missing stripe-signature or STRIPE_WEBHOOK_SIGNING_SECRET", { status: 400 });
  }

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(rawBody, signature, whSecret);
  } catch (e) {
    console.error("Webhook signature verification failed", e);
    return new Response("Invalid signature", { status: 400 });
  }

  if (event.type !== "checkout.session.completed") {
    return new Response(JSON.stringify({ received: true, ignored: event.type }), {
      headers: { "Content-Type": "application/json" },
    });
  }

  let session = event.data.object as Stripe.Checkout.Session;

  // Expand line items for product_sku on Price/Product metadata (optional second request).
  try {
    session = await stripe.checkout.sessions.retrieve(session.id, {
      expand: ["line_items.data.price.product"],
    });
  } catch (e) {
    console.warn("checkout.sessions.retrieve expand failed; using webhook payload only", e);
  }

  const meta = session.metadata ?? {};
  const supabaseUserId = meta.supabase_user_id ?? meta.user_id;
  const athleteId = meta.athlete_id ? String(meta.athlete_id).trim() : "";

  /** Stripe Payment Links: append `?client_reference_id=<auth_user_uuid>` so credits map without server-side Checkout. */
  const clientRefRaw = session.client_reference_id
    ? String(session.client_reference_id).trim()
    : "";
  const clientRefLooksLikeUuid =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(clientRefRaw);

  const customerEmail =
    session.customer_details?.email ?? session.customer_email ?? null;

  const cust = session.customer;
  const stripeCustomerId =
    typeof cust === "string"
      ? cust
      : cust && typeof cust === "object" && "id" in cust && !(cust as { deleted?: boolean }).deleted
      ? (cust as Stripe.Customer).id
      : null;

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, serviceKey);

  let userId: string | null = supabaseUserId ? String(supabaseUserId).trim() : null;

  if (!userId && clientRefLooksLikeUuid) {
    userId = clientRefRaw;
  }

  if (!userId && athleteId) {
    const { data, error: linkErr } = await supabase
      .from("athlete_profile_link")
      .select("user_id")
      .eq("athlete_id", athleteId)
      .maybeSingle();
    if (linkErr) console.error("athlete_profile_link lookup", linkErr);
    userId = data?.user_id ?? null;
  }

  if (!userId && customerEmail) {
    const { data: uid, error: emailErr } = await supabase.rpc("fel_resolve_user_id_by_email", {
      p_email: customerEmail,
    });
    if (emailErr) console.error("fel_resolve_user_id_by_email", emailErr);
    if (typeof uid === "string" && uid.length > 0) userId = uid;
  }

  if (!userId) {
    console.error(
      "Could not resolve user — need supabase_user_id, linked athlete_id, or registered customer_email",
      session.id,
    );
    return new Response(
      JSON.stringify({
        error: "missing_user_resolution",
        hint: "Set metadata.supabase_user_id, metadata.athlete_id (with app link), or use Checkout email matching a Supabase Auth user.",
      }),
      { status: 400 },
    );
  }

  if (athleteId) {
    const { error: upErr } = await supabase.rpc("fel_upsert_athlete_profile_link_for_service", {
      p_athlete_id: athleteId,
      p_user_id: userId,
      p_stripe_customer_id: stripeCustomerId,
    });
    if (upErr) console.error("fel_upsert_athlete_profile_link_for_service", upErr);
  }

  let shardDelta = parseInt(String(meta.shard_delta ?? meta.shards ?? "0"), 10) || 0;
  let cortexDelta = parseInt(String(meta.cortex_delta ?? meta.cortex_credits ?? "0"), 10) || 0;
  let productSku = meta.product_sku ? String(meta.product_sku) : null;

  if (shardDelta === 0 && cortexDelta === 0) {
    const lineItems = (session as unknown as { line_items?: { data?: Stripe.LineItem[] } }).line_items?.data;
    const li = lineItems?.[0];
    const price = li?.price;
    const pMeta = price?.metadata ?? {};
    const skuFromPrice = pMeta.product_sku ? String(pMeta.product_sku) : null;
    if (skuFromPrice && SOVEREIGN_SKU_DEFAULTS[skuFromPrice]) {
      productSku = productSku ?? skuFromPrice;
      shardDelta = SOVEREIGN_SKU_DEFAULTS[skuFromPrice].shard_delta;
      cortexDelta = SOVEREIGN_SKU_DEFAULTS[skuFromPrice].cortex_delta;
    }
  }

  if (shardDelta === 0 && cortexDelta === 0) {
    const fromAmount = creditsFromAmountCents(session.amount_total);
    if (fromAmount) {
      productSku = productSku ?? fromAmount.product_sku;
      shardDelta = fromAmount.shard_delta;
      cortexDelta = fromAmount.cortex_delta;
    }
  }

  if (shardDelta === 0 && cortexDelta === 0) {
    console.warn("checkout.session.completed — zero credits; set metadata or use $19.99 / $49.99 / $99.99 SKUs", session.id);
  }

  const { error } = await supabase.rpc("fel_apply_stripe_shard_credit", {
    p_user_id: userId,
    p_shard_delta: shardDelta,
    p_cortex_delta: cortexDelta,
    p_stripe_session_id: session.id,
    p_product_sku: productSku,
    p_metadata: {
      ...meta,
      athlete_id: athleteId || null,
      customer_email: customerEmail,
      stripe_customer: stripeCustomerId,
      payment_status: session.payment_status,
    },
  });

  if (error) {
    console.error("fel_apply_stripe_shard_credit", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  return new Response(
    JSON.stringify({ ok: true, userId, shardDelta, cortexDelta, productSku, athleteId: athleteId || null }),
    { headers: { "Content-Type": "application/json" } },
  );
});
