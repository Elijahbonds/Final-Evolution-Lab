# Final Evolution — Alpha Tester Onboarding (Sovereign Launch 1.0.0)

**Audience:** First-wave testers (e.g. DA COMPOUND cohort)  
**Product:** Final Evolution Lab — Sovereign economy + Vertical Velocity Academy  
**Bonds Standard:** Cursor (core logic) + AI Studio (UI copy / Gemini) + Wix (economy) — this doc is the single handover artifact for testers and ops.

---

## Before you start

- Use a **real email** you control — it must match **FinalEvolutionGroup.com** checkout if you buy Shards, Blueprint access, or other Sovereign products.
- **Clinical movement education, not medical diagnosis.** The **iOS app opens with a mandatory Medical Disclaimer**; you must accept before any Lab features unlock.
- **Web stack:** Marketing and PWA are typically deployed on **Netlify** (`web/` publish root). **`/play/`** sends **COOP/COEP** headers for WebGPU — large game binaries are **not** on Netlify; Mac **DMG** / Windows **zip** live in **Supabase Storage** (`sovereign-assets`). See `scripts/upload_to_supabase_storage.sh`.

---

## Part A — Install the Lab (GBA-style “Add to Home Screen”)

These steps mirror classic emulator shells: the site opens like an app from your home screen.

### iPhone or iPad (Safari — iOS 17 / 18+)

1. **Open the gateway in Safari**  
   Go to: `https://finalevolutiongroup.com/play/` (or the exact `/play/` URL your team publishes).  
   Use **Safari**, not Chrome or in-app browsers (Instagram/TikTok), for the most reliable install sheet.

2. **Open the Share menu**  
   Tap the **Share** button (square with arrow up).

3. **Add to Home Screen**  
   Scroll the share sheet and tap **Add to Home Screen**.  
   Edit the name if you like (e.g. “FEL Lab”), then tap **Add**.  
   Launch the Lab from the new icon from now on — it opens in standalone mode like a native app.

**Note:** Apple does not allow a website to auto-install itself. If “Add to Home Screen” is missing, confirm you’re in **Safari**, the page loaded over **HTTPS**, and you’re not in Private Browsing with restrictions.

### Android (optional)

In **Chrome**: open the same `/play/` URL → menu (⋮) → **Install app** or **Add to Home screen** when offered.

---

## Part B — Sovereign Wallet (Shards + Cloud Cortex)

The **Sovereign wallet** links your **in-app athlete profile** to your **Supabase account** so purchases on the website can credit **Shards** and **Cloud Cortex** credits in real time.

### Website economy (Wix → Supabase)

- **JOIN NOW / member fields:** Your account should store **`supabase_user_id`** (Auth UUID) and optional **`athlete_id`** (local app profile id) so Wix Automations can POST them to Velo `felWixOrderPaidFromAutomation` → Supabase Edge **`wix-order-completed`** (header **`X-FEL-Wix-Secret`**).  
- **Do not** rely on Netlify to host multi‑GB installers — use **Supabase Storage** public (or signed) URLs for DMG/zip.

### In the iOS app

1. Open **Settings** (gear icon on the main tabs).
2. At the top, find **Economy & Academy unlocks** → **Sovereign wallet**.
3. Enter the **same email and password** you use for **FinalEvolutionGroup.com** (Supabase Auth).
4. Tap **Sign in — link checkout & live wallet**.

**What you should see when it works**

- A short confirmation such as **Wallet live — shards update after purchase.**
- A line like **Linked: xxxxxxxx…** (first characters of your Supabase user id).
- **Evolution Shards** on the tab bar / Lab updates after your team’s Stripe or Wix flow credits **`user_balances`** (no manual refresh required when Realtime is connected).

**Cloud Cortex (Gemini)**

- After sign-in, **Cloud Cortex credits** (when your backend exposes them) align with the same Sovereign account. In the **Lab**, use the **Cloud Cortex** card and tap **Refresh** for a Neuro-Mechanic prescription when your build includes a configured API key.

**Sign out**

- Use **Sign out** in the same section if you need to switch accounts.

---

## Part C — SFMA-informed clinical QA (first session)

Use this on **day one** to confirm the “forensic” loop: screen → mapping → economy. This is **product QA**, not a substitute for licensed SFMA administration.

### C.1 — SFMA multi-segmental screens (education / mapping)

The app may reference **seven basic movement patterns** (multi-segmental flexion, extension, rotation; single-leg stance components as designed in your build). For testers:

| Screen | Forensic intent (in-app) |
|--------|---------------------------|
| Multi-segmental **flexion** | Overall mobility — sagittal chain |
| Multi-segmental **extension** | Hip/spine extension strategy |
| Multi-segmental **rotation** | **Spiral Line** / rotation-chain context — drives **congestion** visuals when flagged |

**Pass (product):** You can complete the flow without crash; flags update **Lab** copy and, in Unreal, **Spiral / FFL** materials respond (red congestion when rotation is “fail” per design).

### C.2 — First System Scan

1. Accept the **Medical Disclaimer** (mandatory first launch).
2. Complete onboarding if prompted.
3. Run **System Scan** from the flow your build shows (first launch or **Lab** → set up / rescan).
4. Confirm you receive a **movement grade**, **PRQ**, and **vertical / flight** stats as designed.
5. **Pass criteria:** Scan completes without crash; results appear on the **Lab** dashboard.

### C.3 — Spiral Line + Push 1, 2 (Unreal Lab)

1. Enter the **Unreal** clinical / lab map your team designates.
2. Trigger **Push 1, 2** rhythmic cueing (Vertical Velocity Academy timing).
3. **Pass criteria:** Translucent **Spiral Line** and **Front Functional Line** meshes **pulse** with the beat; on **SFMA rotation FAIL**, **red congestion** shader is visible on the mapped plane.  
4. **iOS:** Taptic **Push 1, 2** haptics fire when the Unreal rhythm loop runs (embedded build) — matches **Bonds Standard** calibration.

### C.4 — Sovereign economy smoke test

1. Stay **signed in** to Sovereign Wallet (Part B).
2. With your team’s approval, run a **test purchase** on **FinalEvolutionGroup.com** that credits Shards.
3. **Pass criteria:** Shard total updates in-app without force-quit (Realtime + wallet sync). If you’re offline, balance should reconcile after reconnect.

---

## Support

- **Install / PWA:** HTTPS host, correct `/play/` path, Safari for iOS; Netlify **`/play/*`** COOP/COEP must be present for WebGPU clients.  
- **Wallet:** Same email as checkout; check spam and password reset if sign-in fails.  
- **DMG:** Download URL from **Supabase Storage** (not Netlify).  
- **Clinical:** This guide describes product behavior for testers, not individualized medical advice.

---

## Appendix — One-page pre-flight checklist (printable)

Print this section or copy into a notes app. **Date: ________** **Athlete initials: ________**

| Step | Check |
|------|-------|
| ☐ | Accepted **Medical Disclaimer** on first launch |
| ☐ | Opened `https://finalevolutiongroup.com/play/` in **Safari** |
| ☐ | **Add to Home Screen** — Lab icon on home screen |
| ☐ | **Settings → Sovereign wallet** — signed in (same email as website) |
| ☐ | See **Linked: …** under wallet (Supabase link OK) |
| ☐ | **System Scan** completed — PRQ / grade visible on **Lab** |
| ☐ | (Unreal build) **Spiral Line** visible; **Push 1,2** pulse felt or seen |
| ☐ | (Optional) Test purchase — **Shards** updated without force-quit |

---

*Document version: 1.2 — Final Evolution Sovereign Launch (Bonds Standard handover)*
