# Final Evolution — Alpha Access (first 10 testers)

This guide matches the **Sovereign** stack: **Wix** (`finalevolutiongroup.com`), **PWA** at **`/play/`**, **Supabase** wallet + Realtime, and the **iOS / Mac** lab builds.

---

## a) Install the PWA from the Wix site

1. Open **`https://finalevolutiongroup.com/play/`** (or your Wix-connected domain that serves the static `web/` bundle from Netlify or your CDN).
2. **iPhone / iPad (Safari)**  
   - Tap **Share** → **Add to Home Screen**.  
   - Launch **FEL Lab** from the home screen icon — it opens in standalone mode (GBA4iOS-style “installed web app”).
3. **Android (Chrome)**  
   - Tap the menu → **Install app** / **Add to Home screen** when Chrome offers it.
4. **Why `/play/?source=pwa`**  
   The manifest’s `start_url` is **`/play/?source=pwa`** so you can distinguish PWA launches in analytics.

---

## b) Sign into the Sovereign Wallet in-app

1. Install **TestFlight** build **1.0.0 (6)** (or current Alpha).
2. Open **Settings** (or the Sovereign / wallet entry point in the Lab shell).
3. Sign in with the **same email** you use on the web wallet (**`/wallet/`**) and the **Supabase-backed** account.  
   - The app stores **`supabaseUserId`** and syncs **`user_balances`** (Evolution Shards + Cloud Cortex credits).
4. **Wix / Stripe / Supabase**  
   - Purchases that credit the wallet must resolve to your **`auth.users.id`** (UUID).  
   - For **Stripe Payment Links**, use **`client_reference_id`** with that UUID.  
   - For **Wix** orders, pass **`supabase_user_id`** (and optional **`athlete_id`**) into the **Velo relay** described in `wix/velo/README.md`.

---

## c) Link a DualSense controller for “Push 1, 2” haptics

1. **Console / Mac lab build**  
   - Pair **DualSense** over Bluetooth in **System Settings** → Bluetooth.  
   - Launch **Final Evolution Lab** (Mac `.dmg` or PS5 build).  
   - The **Vertical Velocity** rhythm uses calibrated **Push → 1, 2** haptics (see Unreal `UFELInputManager` on PS5).
2. **Browser / PWA**  
   - Chrome exposes the **Gamepad API**; advanced setups can use **WebHID** for DualSense-specific features.  
   - For Pixel Streaming or WASM, inputs route through your hosted runtime iframe (**`FEL_RUNTIME_URL`** in `fel-public-config.js`).
3. **TV / crew view**  
   - AirPlay or HDMI from Mac mini — full-screen the arena tab so timing cues are visible at room scale.

---

## Downloads

| Artifact | How to get it |
|----------|----------------|
| **Mac `.dmg`** | Run `scripts/package_sovereign_desktop.sh` with `FEL_MAC_APP` pointing at your cooked `.app`, upload to `finalevolutiongroup.com/downloads/`. |
| **iOS** | TestFlight invite (Sovereign Alpha group). |
| **Web** | Deploy repo `web/` per `web/DEPLOY.txt`. |

---

## Support

- **Shards not updating after purchase:** confirm Supabase **`wix-order-completed`** or **`stripe-webhook-handler`** logs and **`user_balances`** in the Table Editor.  
- **PWA icon:** replace `web/play/icons/icon-192.png` and `icon-512.png` with branded assets before wide distribution.
