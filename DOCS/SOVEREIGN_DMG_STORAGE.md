# Sovereign DMG hosting (Supabase Storage)

Use this to **serve the Mac lab `.dmg`** from your infrastructure instead of only Netlify (large binary).

## Steps

1. **Supabase Dashboard** → **Storage** → **New bucket** → e.g. `fel-distribution`.
2. **Public** (if you want a stable URL) OR **private** + **signed URLs** (recommended for analytics).
3. Upload `FinalEvolutionLabUnreal-Sovereign.dmg` (from `build/sovereign-desktop/` after `scripts/package_sovereign_desktop.sh`).
4. Copy the **public URL** or generate a **long-lived signed URL**; set in:
   - `web/play/index.html` — “Download for Mac” button `href`
   - Wix site — same link if you mirror the CTA there.

## CORS

Storage downloads are **GET**; browsers don’t need CORS for simple navigation to the DMG. If you fetch from JS, configure CORS on the bucket per Supabase docs.

## Notes

- **Notarize** before wide distribution (`FEL_NOTARIZE=1` in `package_sovereign_desktop.sh` when credentials are set).
- Never commit **service_role** keys; Storage policies should allow **public read** only for the object path you intend to ship.
