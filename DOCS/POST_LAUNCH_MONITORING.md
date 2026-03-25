# Post-Launch Monitoring — Alpha 1 Gold Master

## 1. Telemetry audit

### Supabase (Wix relay → wallet)

The repo does **not** log `felRelayWixOrder` inside Supabase; that name is the **Velo HTTP function** on Wix. Monitor:

1. **Edge Functions** (`wix-order-completed`): Supabase Dashboard → **Edge Functions** → **Logs** — filter `wix-order-completed`, status `200`, errors `missing_user` / `zero_credits`.
2. **SQL** — recent Wix-sourced credits:

```sql
select stripe_session_id, shard_delta, cortex_delta, product_sku, created_at
from public.sovereign_market_transactions
where metadata->>'source' = 'wix'
order by created_at desc
limit 50;
```

3. **Shard delta vs SKU** — Velo must send **`shard_delta`** / **`cortex_delta`** that match your **Wix product catalog** (maintain a mapping table in Velo or Automation JSON). Compare Dashboard **Order** line items to **DB** `shard_delta` for the same `wix_order_id`.

### Stripe webhook (`stripe-webhook-handler`)

Dashboard → **Logs** — filter `checkout.session.completed`, `fel_apply_stripe_shard_credit` errors.

### `GameModeRouter` / `BasketballLab.tsx`

**Not present in this repo.** iOS navigation is **`ContentView` → `TabView` → `AppTab`** (`games`, `lab`, `arena`, …). There is no `GameModeRouter` or `BasketballLab.tsx`.

**If you see undefined hangs Lab ↔ Shop:** today **Shop** is **static** `web/shop/` (Safari), not an in-app tab. In-app **shard** UI is under **Games** / **Settings** / wallet flows. If you add an in-app store later, use **`NavigationStack` + explicit `NavigationPath`** and avoid optional `sheet` without `id`.

---

## 2. Clinical HUD polish (implemented in Unreal)

| Request | Repo location |
|--------|----------------|
| Spiral overlay vs rim visibility | `UFELBiometricOverlays` — **`SpiralVisualIntensityScale`** (default **0.82**) scales spiral emissive pulse. Tune in Blueprint or C++ defaults. |
| Push 1, 2 haptics subtle on mobile | `UFELInputManager::PlayPushTwelveClinicalHaptic` — **iOS/Android** branches boost **snap** intensity (~**1.14×**) and slightly longer duration. |

There is **no** `BasketballLab.tsx` in this repository; web Pixel Streaming shells should mirror the same Unreal parameters if you bridge them.

---

## 3. VVA + Cloud Cortex

- **`academyModuleIndex`** in `PRQManager.buildCloudCortexPrompt` now includes **Module 2: The Ankle Piston** as a **forensic alias** (ankle dorsiflexion / elastic recoil) alongside existing mod IDs.
- **`Config/ACADEMY_CURRICULUM_V1.json`** (v **1.0.4**) adds **`cloud_cortex.ankle_piston_prescription`** for tooling that ingests JSON.
- **`web/config/vva-game-modes.ts`** — TypeScript registry + **next five modules** (`mod13`–`mod17`) placeholders for Alpha 2.

---

## 16.6 ms “Bonds Standard”

Keep **display refresh** and **Unreal frame budget** profiling separate from **Cloud Cortex** latency (Gemini network). Use **Instruments** / **Unreal `stat unit`** on device for regressions after each polish pass.
