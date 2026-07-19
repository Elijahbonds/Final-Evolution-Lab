# STRIPE SETUP — Founder Checklist (~15 minutes)

Do these in order. Steps 1–4 unlock test mode (Abacus can build/verify against
it immediately); step 6 flips you live.

## 1. Create the account (5 min)
1. Go to https://dashboard.stripe.com/register → sign up with your business email.
2. Business type: **Individual** or **LLC** (whichever Final Evolution operates as —
   you can start as Individual and upgrade later).
3. Business details: what you sell = "Digital coaching & fitness app — virtual
   currency for in-app training plans, classes, and cosmetics." Website =
   finalevolution.abacusai.app (update when your domain moves).
4. Payout details: your bank account + routing. Payouts default to daily-rolling
   (2-day delay) — fine to leave.

## 2. Get your API keys (1 min)
Dashboard → Developers → **API keys**:
- **Publishable key** (`pk_test_...`) — not needed for hosted Checkout, ignore.
- **Secret key** (`sk_test_...`) → give to Abacus as env var `STRIPE_SECRET_KEY`.
  ⚠ Never paste the secret key into chat messages, client code, or the repo —
  environment variable only.

## 3. You do NOT need to create products in the dashboard
The code creates each checkout with inline price data from `shardPacks.ts` —
changing pack prices is a code/config change, not a dashboard task. (If you later
prefer dashboard-managed Products, that's an easy swap.)

## 4. Webhook (2 min — after Abacus deploys the endpoint)
Dashboard → Developers → **Webhooks** → Add endpoint:
- URL: `https://finalevolution.abacusai.app/api/stripe/webhook`
- Events: `checkout.session.completed` and `charge.refunded`
- After creating, copy the **Signing secret** (`whsec_...`) → give to Abacus as
  `STRIPE_WEBHOOK_SECRET`.

## 5. Turn on Stripe Tax (1 min — strongly recommended)
Dashboard → Settings → **Tax** → Enable. It auto-calculates US sales tax / VAT on
every checkout. Add your registrations when you cross thresholds (Stripe shows
you when).

## 6. Go live (when test acceptance passes)
1. Dashboard toggle **Test mode → Live**, complete any remaining verification
   (ID, business proof).
2. Copy the LIVE secret key (`sk_live_...`) and create a LIVE webhook endpoint
   (same URL, same events) → its own `whsec_...`.
3. Swap both env vars in Abacus, redeploy.
4. Buy the smallest pack yourself with a real card, confirm shards land, then
   refund it from the dashboard (also verifies the refund path).

## 7. Ongoing (know where these live)
- **Refunds:** Dashboard → Payments → pick payment → Refund. The webhook
  claws back unspent shards automatically.
- **Disputes/chargebacks:** Dashboard → Disputes. Respond with the ledger entry
  (event id, timestamp, shards delivered) — the code stores everything you need.
- **Payouts & fees:** Dashboard → Balance. Standard pricing ≈ 2.9% + 30¢ per
  card charge (Stripe's current published US rate — verify on your dashboard).
- **Receipts:** automatic — Stripe emails the customer on every charge
  (enabled by default; check Settings → Emails).

## Rules that protect you (already enforced in the code)
- Shards are credited ONLY by the verified webhook — a user closing the success
  page early, double-clicking, or replaying URLs cannot double-credit or fake a
  purchase.
- Refunded-but-spent wallets are flagged for review, never auto-negative.
- Card data never touches your servers (hosted Checkout) — minimal PCI scope
  (SAQ A).
