# M25 — STRIPE PAYMENTS · Real Money → Shards

Copy this document into Abacus together with every file in `files/`.
Founder: do the steps in `01-STRIPE-SETUP-GUIDE.md` FIRST (15 minutes) — the code
needs the keys from that guide.

---

## PROMPT FOR ABACUS

Implement real-money payments with Stripe using the files in this package.

**Architecture (do not change):**
- **One product type: SHARD PACKS.** Real money buys shards; everything in-app
  (workout plans, class passes, seminars, 1-on-1s, premium card slots) is priced
  in shards and purchased through the existing server wallet. This keeps Stripe
  simple (4 SKUs), keeps taxes/refunds to one product category, and means no
  gameplay item ever touches a card directly.
- **Stripe Checkout (hosted page)** — not custom card forms. Zero PCI scope,
  Apple Pay + Google Pay + cards automatic, mobile-perfect. The app redirects to
  Stripe and back; no card data ever touches our servers.
- **Webhook is the ONLY place shards are credited.** `checkout.session.completed`
  → verify signature → idempotency check → `EconomyService.creditShards()` →
  ledger entry. Client success page just polls the wallet. This satisfies the
  standing compliance blocker (server-authoritative wallet; client renders a
  cached read only).

## FILES
| File | Purpose |
|---|---|
| `01-STRIPE-SETUP-GUIDE.md` | Founder checklist: account, keys, webhook, go-live |
| `files/shared/shardPacks.ts` | The 4 shard-pack SKUs (single source of truth) |
| `files/server/stripeApi.ts` | Create checkout session + webhook handler (idempotent crediting) |
| `files/client/ShardStoreScreen.tsx` | Store UI → Stripe redirect → success/cancel handling |

## ENV VARS (server-side ONLY — never in client bundles)
```
STRIPE_SECRET_KEY=sk_live_...        (sk_test_... until go-live)
STRIPE_WEBHOOK_SECRET=whsec_...
APP_BASE_URL=https://finalevolution.abacusai.app   (update on custom domain)
```

## WIRING
1. `npm i stripe` (server only). No client Stripe SDK needed for hosted Checkout.
2. Mount routes: `POST /api/store/checkout` → `createCheckout()`;
   `POST /api/stripe/webhook` → `handleWebhook()` — **this route must receive the
   RAW request body** (disable JSON body-parsing on it; signature verification
   fails otherwise — the #1 Stripe integration bug).
3. Client: mount `ShardStoreScreen` at `/shop/shards` (the deep-link the house
   ads and "GET SHARDS" buttons already point at). Success URL `/shop/shards?paid=1`,
   cancel `/shop/shards?canceled=1` (handled in the component).
4. Wallet: bind `EconomyService.creditShards(userId, amount, ledgerRef)` — must be
   idempotent per `ledgerRef` (the Stripe event id). The included handler passes
   `evt_...` ids; duplicate webhook deliveries must credit ONCE.
5. Register the webhook endpoint in the Stripe dashboard (guide §4) for events:
   `checkout.session.completed`, `charge.refunded`.
6. Refund path: `charge.refunded` → debit the shards back if unspent; if spent,
   flag the account for manual review (do not auto-negative the wallet).

## COMPLIANCE / POLICY (blocking)
- Web app = Stripe is fine (no Apple/Google 30% — one reason the web-first bet
  pays off). If a native app-store build ships later, IAP rules apply THERE.
- Enable **Stripe Tax** (guide §5) so sales tax/VAT is calculated automatically.
- Terms + Refund policy pages must state: shards are a prepaid virtual currency,
  refundable only while unspent, no cash-out. Link both on the store screen
  (component includes the links).
- Minors: purchases require the account age-gate; under-18 shows "ask a
  parent/guardian" copy (included).
- Season Pass Pro lane and all shard goods remain cosmetic/services — no
  pay-to-win (standing rule).

## ACCEPTANCE
1. Test mode: buy each pack with card `4242 4242 4242 4242` → redirected back →
   shards credited exactly once (ledger shows the Stripe event id) → balance
   updates in the top bar.
2. Replay the same webhook event (Stripe dashboard "resend") → NO double credit.
3. Signature-invalid webhook → 400, nothing credited.
4. Refund in dashboard → unspent shards debited; spent → account flagged.
5. Apple Pay button appears on iPhone Safari checkout (automatic with Checkout).
6. Live-mode smoke test with a real card for the smallest pack, then refund it.
