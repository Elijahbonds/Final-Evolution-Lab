/**
 * Production Mac installer — public object on Supabase `sovereign-assets`.
 * After each Shipping DMG upload, keep this filename in sync with `Scripts/package_gold_master_mac_shipping.sh` (DMG_NAME).
 */
export const GOLD_MASTER_DMG_FILENAME = "SovereignLab_1.0_Gold.dmg";

const SUPABASE_PUBLIC_BASE =
  "https://rlqkschgvlrva-wsdzjxq.supabase.co/storage/v1/object/public/sovereign-assets/mac";

/** Final production DMG URL (athlete download + Netlify redirect target). */
export const GOLD_MASTER_DMG_PRODUCTION_URL = `${SUPABASE_PUBLIC_BASE}/${GOLD_MASTER_DMG_FILENAME}`;

/** Clean on-domain path — Netlify / `_redirects` 302 → GOLD_MASTER_DMG_PRODUCTION_URL. */
export const GOLD_MASTER_DOWNLOAD_PATH = "/download/final-evolution";

/** Dev-only direct URL (Vite proxy uses same object path as production). */
export const GOLD_MASTER_DMG_URL = GOLD_MASTER_DMG_PRODUCTION_URL;
