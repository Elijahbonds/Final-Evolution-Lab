# What’s left for full deployment — [finalevolutiongroup.com](https://www.finalevolutiongroup.com/)

Your **marketing site** is on **Wix**. The **clinical gateway + PWA + wallet shell** in this repo (`web/`) is a **static** bundle meant for **HTTPS** hosting (e.g. **Netlify**) with `netlify.toml` and COOP/COEP on `/play/`. Those are **two surfaces** until you wire DNS and links.

---

## 1. Choose how traffic is split

| Goal | Typical setup |
|------|----------------|
| **Keep Wix as the only apex** (`https://www.finalevolutiongroup.com/`) | Add buttons on Wix that link **out** to your Lab host and DMG URL (below). |
| **Serve `web/` on a subdomain** | e.g. `lab.finalevolutiongroup.com` or `app.finalevolutiongroup.com` → **Netlify** (or similar) with this repo’s `web/` as publish root. |
| **Same-origin `/play/` on Wix** | Wix does not replace Netlify’s `_headers` automatically; for **WebGPU + COOP/COEP**, prefer the **subdomain** approach or Wix’s docs for custom headers if/when supported. |

---

## 2. Mac DMG download (direct file URL)

Large binaries should **not** live on Wix’s small static slot if you hit limits. **Recommended:**

1. Create Supabase bucket **`sovereign-assets`** (public read for the object, or signed URLs).
2. Upload the notarized DMG:
   ```bash
   export SUPABASE_URL="https://YOUR_PROJECT.supabase.co"
   export SUPABASE_SERVICE_ROLE_KEY="eyJ..."   # service_role — local only
   ./scripts/upload_to_supabase_storage.sh path/to/*-Sovereign.dmg
   ```
3. Copy the printed **public URL**, e.g.  
   `https://YOUR_PROJECT.supabase.co/storage/v1/object/public/sovereign-assets/builds/FinalEvolutionLabUnreal-Sovereign.dmg`
4. **Wix (homepage / OPEN LAB):** add a button **Link → Web address** → paste that URL (opens download).  
5. **Netlify `web/`:** set `web/fel-public-config.js` (from `fel-public-config.example.js`) with  
   `window.FEL_PUBLIC_DMG_URL = "<same public URL>";`  
   so `/play/` **Download for Mac** uses the same file.

---

## 3. PWA / gateway on the public site

- **Option A — Subdomain:** Deploy `web/` to Netlify at e.g. `lab.finalevolutiongroup.com`. On Wix, set **OPEN LAB** → `https://lab.finalevolutiongroup.com/play/` (or `/` for gateway).
- **Option B — Wix-only marketing:** Keep Wix as-is; link **OPEN LAB** to the Netlify URL you chose.

---

## 4. Supabase + Stripe + Wix economy

| Piece | Status |
|--------|--------|
| Edge `wix-order-completed` | Deploy + secrets (`WIX_WEBHOOK_SHARED_SECRET`). |
| Velo relay | `wix/velo/backend/http-functions.js` or `final-evolution-wix-bridge/`. |
| Wix Secrets | `FEL_SUPABASE_ORDER_URL`, `FEL_WIX_WEBHOOK_SHARED_SECRET`. |
| Web wallet | `web/fel-public-config.js` with anon key + URL (gitignored). |

---

## 5. iOS / TestFlight

- Xcode archive, upload to App Store Connect, **TestFlight** / App Store per `XCODE_CLEAN_AND_RUN.md` and your provisioning.

---

## 6. Quick “done” checklist

- [ ] DMG built + notarized (`scripts/package_sovereign_desktop.sh` with `FEL_MAC_APP`).
- [ ] DMG uploaded to **Supabase Storage**; public URL copied.
- [ ] **Wix** homepage (and any **OPEN LAB** buttons) point to that DMG URL **and/or** your Netlify `web/` URL.
- [ ] `web/fel-public-config.js` on Netlify with `FEL_PUBLIC_DMG_URL`, `FEL_SUPABASE_*`, Stripe links as needed.
- [ ] `netlify deploy --prod` (or CI) for the static `web/` site.
- [ ] DNS: subdomain CNAME to Netlify if using `lab.` / `app.`.

---

*Once Wix buttons use the Supabase DMG URL, users can download **directly** from [finalevolutiongroup.com](https://www.finalevolutiongroup.com/) via that link without hosting the file on Wix.*
