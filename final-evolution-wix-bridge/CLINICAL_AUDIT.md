# Clinical audit — Wix Velo vs “16.6 ms” (Final Evolution)

## Definitions

| Term | Meaning |
|------|--------|
| **16.6 ms** | ≈ **one frame at 60 Hz** (16.67 ms). Valid for **in-app HUD**, **Unreal** tick, **ProMotion** targets — **not** a promise for Wix → Supabase HTTP latency. |
| **Sovereign Bridge** | Velo `http-functions.js` → Supabase Edge `wix-order-completed` → RPC `fel_apply_stripe_shard_credit` → **`user_balances`** → client **Realtime**. |

## Audit checklist (code)

- [ ] **Single outbound `fetch`** per order in `relayToSupabase` — no chained calls inside the hot path.
- [ ] **Secrets** read once per request via `getSecret` (no hardcoded tokens in repo).
- [ ] **Payload** is minimal JSON: `wix_order_id`, `supabase_user_id`, `shard_delta`, `cortex_delta`, `product_sku`, optional `athlete_id`.
- [ ] **Header** `X-FEL-Wix-Secret` matches Supabase `WIX_WEBHOOK_SHARED_SECRET` (case-insensitive on Edge; Velo sends canonical form).
- [ ] **Automation** timeout: keep handler fast; no long loops, no `await` on unrelated Wix APIs in the same function unless required.
- [ ] **Idempotency:** Edge uses `wix_<orderId>` as synthetic session id — duplicate posts with same order id should not double-credit (verify RPC behavior in migrations).

## Audit checklist (product / UX)

- [ ] **Wallet UI** subscribes to **Supabase Realtime** on `user_balances` — perceived update typically **< 1 s** after Edge success, not 16.6 ms.
- [ ] **Marketing copy** on Wix: if “16.6 ms” appears, qualify as **frame budget** / **60 Hz** — avoid implying checkout-to-wallet wire time.

## Measured expectations (rough)

- Velo → Supabase Edge: **tens to hundreds of ms** RTT (region-dependent).
- Edge → Postgres RPC: usually **&lt; 100 ms** when warm.
- Realtime → app: **sub-second** notification.

## Pass / fail

| Result | Action |
|--------|--------|
| **Pass** | Relay is thin; secrets external; Realtime wired on clients. |
| **Fail** | Extra network hops, logging huge bodies, or claiming 16.6 ms for HTTP checkout. |
