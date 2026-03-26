/**
 * Copy to fel-public-config.js in the same folder (web/) and fill in values.
 * The anon key is safe in the browser (RLS protects tables). Never put the service_role key here.
 */
window.FEL_SUPABASE_URL = "https://YOUR_PROJECT.supabase.co";
window.FEL_SUPABASE_ANON_KEY = "YOUR_SUPABASE_ANON_KEY";

/** Stripe Payment Links (Dashboard → Payment Links) — test or live URLs. */
window.FEL_STRIPE_PAYMENT_LINK_VVA = "https://buy.stripe.com/test_REPLACE_VVA";
window.FEL_STRIPE_PAYMENT_LINK_SHARDS = "https://buy.stripe.com/test_REPLACE_SHARDS";
window.FEL_STRIPE_PAYMENT_LINK_PRO = "https://buy.stripe.com/test_REPLACE_PRO";

/** Optional: full URL to Unity WebGL, Unreal Pixel Streaming player page, or WASM shell (same-origin or CORS-enabled). */
window.FEL_RUNTIME_URL = "";

/** Optional: Mac Gold Master .dmg public URL (match sites/.../constants/downloads.ts + sovereign-assets upload). */
window.FEL_PUBLIC_DMG_URL =
  "https://YOUR_PROJECT.supabase.co/storage/v1/object/public/sovereign-assets/mac/SovereignLab_1.0_Gold.dmg";
